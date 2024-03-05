=head1 LICENSE

Copyright [2009-2024] EMBL-European Bioinformatics Institute

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
