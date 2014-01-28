package EnsEMBL::Web::Component::Location;

use strict;
use warnings;
no warnings "uninitialized";


# TODO: Needs moving to viewconfig so we don't have to work it out each time
sub default_otherspecies {
  my $self = shift;
  my $sd = $self->object->species_defs;
  my %synteny = $sd->multi('DATABASE_COMPARA', 'SYNTENY');
  my @has_synteny = sort keys %synteny;
  my $sp;

  my $species = $self->object->species;
  if (my $spg = $sd->SPECIES_DATASET($species)) {
      foreach $sp (@has_synteny) {
	  my $ospg = $sd->SPECIES_DATASET($sp);
	  if ($ospg eq $spg)  {
	      if ($sp ne $species) {
		  return $sp;
	      }
	  }
      }
  }

  # Set default as primary species, if available
  unless ($ENV{'ENSEMBL_SPECIES'} eq $sd->ENSEMBL_PRIMARY_SPECIES) {
    foreach my $sp (@has_synteny) {
      return $sp if $sp eq $sd->ENSEMBL_PRIMARY_SPECIES;
    }
  }

  # Set default as secondary species, if primary not available
  unless ($ENV{'ENSEMBL_SPECIES'} eq $sd->ENSEMBL_SECONDARY_SPECIES) {
    foreach $sp (@has_synteny) {
      return $sp if $sp eq $sd->ENSEMBL_SECONDARY_SPECIES;
    }
  }

  # otherwise choose first in list
  return $has_synteny[0];
}

1;
