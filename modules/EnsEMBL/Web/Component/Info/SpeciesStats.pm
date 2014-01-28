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
