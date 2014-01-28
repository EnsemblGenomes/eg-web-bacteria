=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor;
use strict;
use warnings;
use vars qw(@ISA);

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Cache; #CPAN LRU cache
use Bio::EnsEMBL::DnaDnaAlignFeature;

use Bio::EnsEMBL::Utils::Exception;
use POSIX qw(floor);
use Data::Dumper;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

my $CACHE_SIZE = 4;




=head2 interpolate_best_location

  Arg [1]    : Bio::EnsEMBL::Slice $slice
  Arg [2]    : string $species
               e.g. "Mus musculus"
  Arg [3]    : string $alignment_type
               e.g. "BLASTZ_NET"
  Arg [4]    : string $seq_region_name
               e.g. "6-COX"
  Example    :
  Description:
  Returntype : array with 3 elements
  Exceptions :
  Caller     :

=cut

sub interpolate_best_location {
  my ($self,$slice,$species,$alignment_type,$seq_region_name) = @_;
  
  $| =1 ;
  my $max_distance_for_clustering = 10000;
  my $dafs;

  if($slice->start > $slice->end)  {
     my $sl1 = Bio::EnsEMBL::Slice->new(-COORD_SYSTEM      =>  $slice->{'coord_system'},
				        -SEQ_REGION_NAME    => $slice->{'seq_region_name'},
				        -SEQ_REGION_LENGTH  => $slice->{'seq_region_length'},
				        -START              => $slice->{'start'},
				        -END                => $slice->{'seq_region_length'},
				        -STRAND             => $slice->{'strand'},
				        -ADAPTOR            => $slice->{'adaptor'});

     my $sl2 = Bio::EnsEMBL::Slice->new(-COORD_SYSTEM      =>  $slice->{'coord_system'},
				        -SEQ_REGION_NAME    => $slice->{'seq_region_name'},
				        -SEQ_REGION_LENGTH  => $slice->{'seq_region_length'},
                                        -START              => 1,
				        -END                => $slice->{'end'},
				        -STRAND             => $slice->{'strand'},
				        -ADAPTOR            => $slice->{'adaptor'});

     my @arr_defs; 
     my $defs_1 =  $self->fetch_all_by_Slice($sl1, $species, undef, $alignment_type);     
     my $defs_2 =  $self->fetch_all_by_Slice($sl2, $species, undef, $alignment_type);
     push @arr_defs, @{$defs_2}, @{$defs_1};
     $dafs = \@arr_defs;

  }  else {
     $dafs = $self->fetch_all_by_Slice($slice, $species, undef, $alignment_type);

  }

  my %name_strand_clusters;
  my $based_on_group_id = 1;
  foreach my $daf (@{$dafs}) {
    next if ($seq_region_name && $daf->hseqname ne $seq_region_name);
    if (defined $daf->group_id && $daf->group_id > 0 && $alignment_type ne "TRANSLATED_BLAT") {
      push @{$name_strand_clusters{$daf->group_id}}, $daf;
    } else {
      $based_on_group_id = 0 if ($based_on_group_id);
      push @{$name_strand_clusters{$daf->hseqname. "_" .$daf->hstrand}}, $daf;
    }
    #warn 'current daf: ' . $daf->hstart. ' - '. $daf->hend;

  }

  if ($based_on_group_id) {
    my @ordered_name_strands = sort {scalar @{$name_strand_clusters{$b}} <=> scalar @{$name_strand_clusters{$a}}} keys %name_strand_clusters;
  
    my @best_blocks = sort {$a->hstart <=> $b->hend} @{$name_strand_clusters{$ordered_name_strands[0]}||[]};
 
    #warn 'species: ' . $best_blocks[-1]->hspecies;
    #warn 'start:   '. $best_blocks[0]->hstart . '  end: '  .$best_blocks[-1]->hend;

    my $ln = $best_blocks[-1]->hslice->seq_region_length; 
    my $cr = $best_blocks[-1]->hslice->is_circular; 

    my $mid = ( ($slice->start > $slice->end) && ( ($best_blocks[-1]->hend - $best_blocks[0]->hstart) > ($ln - $best_blocks[-1]->hend + $best_blocks[0]->hstart) ) ) ?
                 $best_blocks[-1]->hend + int(($ln - $best_blocks[-1]->hend + $best_blocks[0]->hstart)/2) : 
   	         $best_blocks[0]->hstart + int(($best_blocks[-1]->hend - $best_blocks[0]->hstart)/2);

    $mid = ($mid > $ln) ?  $mid - $ln : $mid;

    my $width = $slice->length;
    my $starth = floor($mid - ($width-1)/2);
    my $endh   = floor($mid + ($width-1)/2);

    if($cr)  {
 	    $starth =  $starth < 0 ? $ln + $starth : $starth;
	    $endh   =  $endh   > $ln ? $endh - $ln : $endh;
    }  else {
	if($starth < 0) {
	    $starth = 1;
            $endh   = $width;
        } 
	if($endh > $ln) {
	    $endh   =  $ln;
            $starth = $ln - $width;
        }
    }
    
#   warn 'block: ' . Dumper($best_blocks[-1]); 
#   warn ' mid is : ' . $mid. ' this species len is : '. $ln. ' is circ '.$cr;

    return undef if( !@best_blocks );
    return ($best_blocks[0]->hseqname,
            $mid,
            #$best_blocks[0]->hstart
            #+ int(($best_blocks[-1]->hend - $best_blocks[0]->hstart)/2),
            $best_blocks[0]->hstrand * $slice->strand,
            $best_blocks[0]->hstart,
            $best_blocks[-1]->hend,
            $starth,
            $endh
            );

  } else {

    my @refined_clusters;
    foreach my $name_strand (keys %name_strand_clusters) {
      # an array of arrayrefs
      # name, strand, start, end, nb of blocks
      my @sub_clusters;
      foreach my $block (sort {$a->hstart <=> $b->hstart} @{$name_strand_clusters{$name_strand}||[]}) {
        unless (scalar @sub_clusters) {
          push @sub_clusters, [$block->hseqname,$block->hstrand, $block->hstart, $block->hend, 1];
          next;
        }
        my $block_clustered = 0;
        foreach my $arrayref (@sub_clusters) {
          my ($n,$st,$s,$e,$c) = @{$arrayref};
          if ($block->hstart<=$e &&
              $block->hend>=$s) {
            # then overlaps.
            $arrayref->[2] = $block->hstart if ($block->hstart < $s);
            $arrayref->[3] = $block->hend if ($block->hend > $e);
            $arrayref->[4]++;
            $block_clustered = 1;
          } elsif ($block->hstart <= $e + $max_distance_for_clustering &&
                   $block->hstart > $e) {
            # then is downstream
            $arrayref->[3] = $block->hend;
            $arrayref->[4]++;
            $block_clustered = 1;
          } elsif ($block->hend >= $s - $max_distance_for_clustering &&
                   $block->hend < $s) {
            # then is upstream
            $arrayref->[2] = $block->hstart;
            $arrayref->[4]++;
            $block_clustered = 1;
          }
        }
        unless ($block_clustered) {
          # do not overlap anything already seen, so adding as new seeding cluster
          push @sub_clusters, [$block->hseqname,$block->hstrand, $block->hstart, $block->hend, 1];
        }
      }
      push @refined_clusters, @sub_clusters;
    }

    # sort by the max number of blocks desc
    @refined_clusters = sort {$b->[-1] <=> $a->[-1]} @refined_clusters;

    return undef if(!@refined_clusters);

#   warn 'end: ' . $refined_clusters[0]->[3] . ' st: ' .$refined_clusters[0]->[2];
    return ($refined_clusters[0]->[0], #hseqname,
            $refined_clusters[0]->[2]
            + int(($refined_clusters[0]->[3] - $refined_clusters[0]->[2])/2),
            $refined_clusters[0]->[1] * $slice->strand,
            $refined_clusters[0]->[2],
            $refined_clusters[0]->[3]);

  }
}



1;


