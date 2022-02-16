=head1 LICENSE

Copyright [2009-2022] EMBL-European Bioinformatics Institute

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
  my ($self, $chr, $start, $end, $strand) = @_;

  if (defined $start) {
    $start    = floor($start);
    $end      = $start unless defined $end;
    $end      = floor($end);
    $end      = 1 if $end < 1;
    $strand ||= 1;
    $start    = 1 if $start < 1; # Truncate slice to start of seq region

## EG    
    foreach my $system0 (@{$self->__coord_systems}) {
	    my $slice;
	    eval { $slice = $self->_slice_adaptor->fetch_by_region($system0->name, $chr, 1, 2, $strand); };
      if ($slice) {
	      if (!$slice->is_circular and $start > $end) {
          ($start, $end) = ($end, $start);
        } 
        last;
      }
    }
##
    
    foreach my $system (@{$self->__coord_systems}) {
      my $slice;
      
      eval {
        $slice = $self->_slice_adaptor->fetch_by_region($system->name, $chr, $start, $end, $strand);
      };

      warn $@ and next if $@;

      if ($slice) {
        if ($start > $slice->seq_region_length || $end > $slice->seq_region_length) {
          $start = $slice->seq_region_length if $start > $slice->seq_region_length;
          $end   = $slice->seq_region_length if $end   > $slice->seq_region_length;
          
          $slice = $self->_slice_adaptor->fetch_by_region($system->name, $chr, $start, $end, $strand);
        }
        
        return $self->_create_from_slice($system->name, "$chr $start-$end ($strand)", $slice);
      }
    }
    
    $self->problem('fatal', 'Locate error', $self->_help("Cannot locate region $chr: $start - $end on the current assembly."));
  } else {
    foreach my $system (@{$self->__coord_systems}) {
      my $slice;
      
      eval {
        $slice = $self->_slice_adaptor->fetch_by_region($system->name, $chr);
      };
      
      next if $@;
      
      return $self->_create_from_slice($system->name , $chr, $self->expand($slice), $chr) if $slice;
    }
    
    if ($chr) {
      $self->problem('fatal', 'Locate error', $self->_help("Cannot locate region $chr on the current assembly."));
    } elsif ($self->hub->action eq 'Genome' && $self->species_defs->ENSEMBL_CHROMOSOMES) {
      # Create a slice of the first chromosome to force this page to work
      my @chrs  = @{$self->species_defs->ENSEMBL_CHROMOSOMES};
      my $slice = $self->_slice_adaptor->fetch_by_region('chromosome', $chrs[0]) if scalar @chrs;
      
      return $self->_create_from_slice('chromosome', $chrs[0], $self->expand($slice), $chrs[0]) if $slice;
    } else {
      # Might need factoring out if we use other methods to get a location (e.g. marker)
      $self->problem('fatal', 'Please enter a location', $self->_help('A location is required to build this page'));
    }
  }
  
  return undef;
}

1;
