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

package EnsEMBL::Web::Factory::Location;

use strict;
use warnings;
no warnings "uninitialized";

use POSIX qw(floor ceil);

sub _location_from_SeqRegion {
  my ($self, $chr, $start, $end, $strand, $keep_slice) = @_;

  if (defined $start) {
    $start = floor($start);
    $end   = $start unless defined $end;
    $end   = floor($end);
    $end   = 1 if $end < 1;
    $strand ||= 1;
    $start = 1 if $start < 1; # Truncate slice to start of seq region

    foreach my $system0 (@{$self->__coord_systems}) {
	my $slice;
	eval { $slice = $self->_slice_adaptor->fetch_by_region($system0->name, $chr, 1, 2, $strand); };
        if ($slice) {
	    unless($slice->is_circular eq '1') {
                ($start, $end) = ($end, $start) if $start > $end;
            } 
            last;
        }
    }

    foreach my $system (@{$self->__coord_systems}) {
      my $slice;
      eval { $slice = $self->_slice_adaptor->fetch_by_region($system->name, $chr, $start, $end, $strand); };

      warn $@ and next if $@;

      if ($slice) {
        if ($start > $slice->seq_region_length || $end > $slice->seq_region_length) {
          $start = $slice->seq_region_length if $start > $slice->seq_region_length;
          $end   = $slice->seq_region_length if $end   > $slice->seq_region_length;
          
          $slice = $self->_slice_adaptor->fetch_by_region($system->name, $chr, $start, $end, $strand);
        }
        
        return $self->_create_from_slice($system->name, "$chr $start-$end ($strand)", $slice, undef, undef, $keep_slice);
      }
    }
    
    $self->problem('fatal', 'Locate error', $self->_help("Cannot locate region $chr: $start - $end on the current assembly."));
    
    return undef;
  } else {
    foreach my $system (@{$self->__coord_systems}) {
      my $TS;
      eval { $TS = $self->_slice_adaptor->fetch_by_region($system->name, $chr); };
      
      next if $@;
      
      return $self->_create_from_slice($system->name , $chr, $self->expand($TS), '', $chr, $keep_slice) if $TS;
    }
    
    my $action = $self->action;
    
    if ($chr) {
      $self->problem('fatal', 'Locate error', $self->_help("Cannot locate region $chr on the current assembly."));
    } elsif ($action && $action eq 'Genome' && $self->species_defs->ENSEMBL_CHROMOSOMES) {
      # Create a slice of the first chromosome to force this page to work
      my @chrs = @{$self->species_defs->ENSEMBL_CHROMOSOMES};
      my $TS = $self->_slice_adaptor->fetch_by_region('chromosome', $chrs[0]) if scalar @chrs;
      
      return $self->_create_from_slice('chromosome', $chrs[0], $self->expand($TS), '', $chrs[0], $keep_slice) if $TS;
    } else {
      # Might need factoring out if we use other methods to get a location (e.g. marker)
      $self->problem('fatal', 'Please enter a location', $self->_help('A location is required to build this page'));
    }
    
    return undef;
  }
}

sub createObjects {
  my $self  = shift;
  my $slice = shift;
  my ($location, $identifier, $ftype);
  
  my $db_adaptor = $self->database('core'); 
  
  return $self->problem('fatal', 'Database Error', 'Could not connect to the core database.') unless $db_adaptor;
    
  if ($slice) {
    $slice = $slice->invert if $slice->strand < 0;
    
    if (!$slice->is_toplevel) {
      my $toplevel_projection = $slice->project('toplevel');
      
      if (my $seg = shift @$toplevel_projection) {
        $slice = $seg->to_Slice;
      }
    }
    
    $location = $self->new_location($slice);
  } else {
    my ($seq_region, $start, $end, $strand);
    
    # Get seq_region, start, end, strand. These are obtained by either
    # 1) Parsing an r or l parameter
    # 2) Parsing a c/w or centrepoint/width parameter combination
    # 3) Reading the paramters listed in the else block below
    if ($identifier = $self->param('r') || $self->param('l')) {
      $identifier =~ s/\s|,//g;

## EG Bacteria - Don't use parse_location_to_values as it isn't compatible with circular regions.
#                We should be ok to use the method in E85 see ENSCORESW-1718
#                Until then reverting to the old regex validation.
      #using core API module to validate the location values, see core documentation for this method
      #($seq_region, $start, $end, $strand) = $self->_slice_adaptor->parse_location_to_values($identifier); 
      ($seq_region, $start, $end, $strand) = $identifier =~ /^([^:]+):(-?\w+\.?\w*)[-|..]?(-?\w+\.?\w*)?(?::(-?\d))?$/;
##
      
      $start = $self->evaluate_bp($start);
      $end   = $self->evaluate_bp($end) || $start;
      $slice = $self->get_slice($seq_region || $identifier, $start, $end); 
      
      if ($slice) {
        return if $self->param('a') && $self->_map_assembly($slice->seq_region_name, $slice->start, $slice->end, 1);                             # Mapping from one assembly to another
        return $self->_create_from_sub_align_slice($slice) if $self->param('align_start') && $self->param('align_end') && $self->param('align'); # Mapping from an AlignSlice to a real location
        
        $location = $self->new_location($slice);
      } else {
        $location = $self->_location_from_SeqRegion($seq_region || $identifier, $start, $end); 
      }
    } else {
      $seq_region = $self->param('region')    || $self->param('contig')     ||
                    $self->param('clone')     || $self->param('seqregion')  ||
                    $self->param('chr')       || $self->param('seq_region_name');
                    
      $start      = $self->param('chr_start') || $self->param('vc_start') || $self->param('start');
                    
      $end        = $self->param('chr_end')   || $self->param('vc_end') || $self->param('end');
      
      $strand     = $self->param('strand')    || $self->param('seq_region_strand') || 1;
      
      $start = $self->evaluate_bp($start) if defined $start;
      $end   = $self->evaluate_bp($end)   if defined $end;      
      
      if ($identifier = $self->param('c')) {
        my ($cp, $t_strand);
        my $w = $self->evaluate_bp($self->param('w'));
        
        ($seq_region, $cp, $t_strand) = $identifier =~ /^([-\w\.]+):(-?[.\w,]+)(:-?1)?$/;
        
        $cp = $self->evaluate_bp($cp);
        
        $start  = $cp - ($w - 1) / 2;
        $end    = $cp + ($w - 1) / 2;
        $strand = $t_strand eq ':-1' ? -1 : 1 if $t_strand;
      } elsif ($identifier = $self->param('centrepoint')) {
        my $cp = $self->evaluate_bp($identifier);
        my $w  = $self->evaluate_bp($self->param('width'));
        
        $start = $cp - ($w - 1) / 2;
        $end   = $cp + ($w - 1) / 2;
      }

      my $anchor1 = $self->param('anchor1'); 
      
      if ($seq_region && !$anchor1) {
        if ($self->param('band')) {
          my $slice;
          eval {
            $slice = $self->_slice_adaptor->fetch_by_chr_band($seq_region, $self->param('band'));
          };
          $location = $self->new_location($slice) if $slice;
        }
        else {
          $location = $self->_location_from_SeqRegion($seq_region, $start, $end, $strand); # We have a seq region, and possibly start, end and strand. From this we can directly get a location
        }
      } else {
        # Mapping of supported URL parameters to function calls which should get a Location for those parameters
        # Ordered by most likely parameter to appear in the URL
        #
        # NB: The parameters listed here are all non-standard.
        # Any "core" parameters in the URL will cause Location objects to be generated from their respective factories
        # The exception to this is the Marker parameter m, since markers can map to 0, 1 or many locations, the location is not generated in the Marker factory
        # For a list of core parameters, look in Model.pm
        my @params = (
          [ 'Gene',        [qw(gene                            )] ],
          [ 'Transcript',  [qw(transcript                      )] ],
          [ 'Variation',   [qw(snp                             )] ],
          [ 'Exon',        [qw(exon                            )] ],
          [ 'Peptide',     [qw(p peptide protein               )] ],
          [ 'MiscFeature', [qw(mapfrag miscfeature misc_feature)] ],
          [ 'Marker',      [qw(m marker                        )] ],
          [ 'Band',        [qw(band                            )] ],
        );
      
        my @anchorview;
        
        if ($anchor1) {
          my $anchor2 = $self->param('anchor2');
          my $type1   = $self->param('type1');
          my $type2   = $self->param('type2');
        
          push @anchorview, [ $type1, $anchor1 ] if $anchor1 && $type1;
          push @anchorview, [ $type2, $anchor2 ] if $anchor2 && $type2;
        }
        
        # Anchorview allows a URL to specify two features to find a location between.
        # For example: type1=gene;anchor1=BRCA2;type2=marker;anchor2=SHGC-53626
        # which will return the region from the start of the BRCA2 gene to the end of the SHGC-53626 marker.
        # The ordering of the parameters is unimportant, so type1=marker;anchor1=SHGC-53626;type2=gene;anchor2=BRCA2 would return the same location
        if (@anchorview) {
          foreach (@anchorview) {
            my $anchor_location;
            
            ($ftype, $identifier) = @$_;
            
            # Loop through the params mapping until we find the correct function to call.
            # While this may not be the most efficient approach, it is the easiest, since multiple parameters can use the same function
            foreach my $p (@params) {
              my $func = "_location_from_$p->[0]";
              
              # If the type is given as 'all', call every function until a location is found
              foreach (@{$p->[1]}, 'all') {
                if ($_ eq $ftype) {
                  $anchor_location = $self->$func($identifier, $seq_region);
                  last;
                }
              }
              
              last if $anchor_location;
            }
            
            $anchor_location ||= $self->_location_from_SeqRegion($seq_region, $identifier, $identifier); # Lastly, see if the anchor supplied is actually a region parameter
            
            if ($anchor_location) {
              $self->DataObjects($anchor_location);
              $self->clear_problems; # Each function will create a problem if it fails to return a location, so clear them here, now that we definitely have one
            }
          }
          
          $self->merge if $self->DataObjects; # merge the anchor locations to get the right overall location
        } else {
          # Here we are calculating the location based on a feature, for example if the URL query string is just gene=BRAC2
          
          # Loop through the params mapping until we find the correct function to call.
          # While this may not be the most efficient approach, it is the easiest, since multiple parameters can use the same function
          foreach my $p (@params) {
            my $func = "_location_from_$p->[0]";
            
            foreach (@{$p->[1]}) {
              if ($identifier = $self->param($_)) {
                $location = $self->$func($identifier);
                last;
              }
            }
            
            last if $location;
          }
          
          ## If we still haven't managed to find a location (e.g. an incoming link with a bogus URL), throw a warning rather than an ugly runtime error!
          $self->problem('no_location', 'Malformed URL', $self->_help('The URL used to reach this page may be incomplete or out-of-date.')) if $self->hub->type eq 'Location' && $self->hub->action ne 'Genome' && !$location;
        }
      }
    }
  }
  $self->DataObjects($location) if $location;
  return $location;
}

1;
