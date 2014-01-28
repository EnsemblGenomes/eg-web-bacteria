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

package Bio::EnsEMBL::DBSQL::SequenceAdaptor;

# Bug fix: Translated sequence track in detailed view wasn't working
sub fetch_by_Slice_start_end_strand {
   my ( $self, $slice, $start, $end, $strand) = @_;

   if(!ref($slice) || !($slice->isa("Bio::EnsEMBL::Slice") or $slice->isa('Bio::EnsEMBL::LRGSlice')) ) {
     throw("Slice argument is required.");
   }

   $start = 1 if(!defined($start));

  if ($slice->is_circular) {
    
      if ($start > $end ) {
	  return $self->_fetch_by_Slice_start_end_strand_circular( $slice, $start, $end, $strand );
      }

      #if ($start < 0) {
	#  $start += $slice->seq_region_length;
      #}
      #if ($end < 0) {
	#  $end += $slice->seq_region_length;
      #}

      if ( !defined($end) ) {
      }

      #if($slice->start> $slice->end) {
	#  return $self->_fetch_by_Slice_start_end_strand_circular( $slice, $slice->start, $slice->end, $strand );
      #}

  } else {
       if ( !defined($end) ) {
	   $end = $slice->end() - $slice->start() + 1;
       }
  }

  if ( $start > $end ) {
      throw("Start must be less than or equal to end.");
  }

   $strand ||= 1;

   #get a new slice that spans the exact region to retrieve dna from
   my $right_expand  = $end - $slice->length(); #negative is fine
   my $left_expand   = 1 - $start; #negative is fine

   if($right_expand || $left_expand) {
     $slice = $slice->expand($left_expand, $right_expand);
   }

   #retrieve normalized 'non-symlinked' slices
   #this allows us to support haplotypes and PARs
   my $slice_adaptor = $slice->adaptor();
   my @symproj=@{$slice_adaptor->fetch_normalized_slice_projection($slice)};

   if(@symproj == 0) {
     throw('Could not retrieve normalized Slices. Database contains ' .
           'incorrect assembly_exception information.');
   }

   #call this method again with any slices that were 'symlinked' to by this
   #slice
   if(@symproj != 1 || $symproj[0]->[2] != $slice) {
     my $seq;
     foreach my $segment (@symproj) {
       my $symlink_slice = $segment->[2];
       #get sequence from each symlinked area
       $seq .= ${$self->fetch_by_Slice_start_end_strand($symlink_slice,
                                                        1,undef,1)};
     }
     if($strand == -1) {
       reverse_comp(\$seq);
     }
     return \$seq;
   }

   # we need to project this slice onto the sequence coordinate system
   # even if the slice is in the same coord system, we want to trim out
   # flanking gaps (if the slice is past the edges of the seqregion)
   my $csa = $self->db->get_CoordSystemAdaptor();
   my $seqlevel = $csa->fetch_sequence_level();

   my @projection=@{$slice->project($seqlevel->name(), $seqlevel->version())};

   my $seq = '';
   my $total = 0;
   my $tmp_seq;

   #fetch sequence from each of the sequence regions projected onto
   foreach my $segment (@projection) {
     my ($start, $end, $seq_slice) = @$segment;

     #check for gaps between segments and pad them with Ns
     my $gap = $start - $total - 1;
     if($gap) {
       $seq .= 'N' x $gap;
     }

     my $seq_region_id = $slice_adaptor->get_seq_region_id($seq_slice);

     my $seq_len = $seq_slice->length();
     if ($seq_slice->length() < 0)  {
	 $seq_len = $slice->seq_region_length - $seq_slice->start + $seq_slice->end ;
     }

     $tmp_seq = ${$self->_fetch_seq($seq_region_id,
                                    $seq_slice->start, $seq_len)};

     #reverse compliment on negatively oriented slices
     if($seq_slice->strand == -1) {
       reverse_comp(\$tmp_seq);
     }

     $seq .= $tmp_seq;

     $total = $end;
   }

   #check for any remaining gaps at the end
   my $gap = $slice->length - $total;
   if($gap) {
     $seq .= 'N' x $gap;
   }

   #if the sequence is too short it is because we came in with a seqlevel
   #slice that was partially off of the seq_region.  Pad the end with Ns
   #to make long enough
   if(length($seq) != $slice->length()) {
     $seq .= 'N' x ($slice->length() - length($seq));
   }

   if(defined($self->{_rna_edits_cache}) and defined($self->{_rna_edits_cache}->{$slice->get_seq_region_id})){
     $self->_rna_edit($slice,\$seq);
   }

   #if they asked for the negative slice strand revcomp the whole thing
   reverse_comp(\$seq) if($strand == -1);

   return \$seq;
}

1;
