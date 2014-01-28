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

package EnsEMBL::Web::Component::Info::SpeciesStats;

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::Controller::SSI;
use base qw(EnsEMBL::Web::Component);


sub content {
  my $self = shift;

  my $sd = $self->hub->species_defs;

  my $file = '/ssi/species/stats_' . $sd->SYSTEM_NAME($self->hub->species) . '.html';
  return EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $file);
}

1;
