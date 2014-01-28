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

1;
