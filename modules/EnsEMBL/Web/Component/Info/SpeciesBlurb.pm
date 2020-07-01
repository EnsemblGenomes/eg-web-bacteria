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

# $Id: SpeciesBlurb.pm,v 1.8 2013-08-30 10:06:22 jh15 Exp $

package EnsEMBL::Web::Component::Info::SpeciesBlurb;

use strict;

use EnsEMBL::Web::Controller::SSI;

sub content {
  my $self              = shift;
  my $hub               = $self->hub;
  my $species_defs      = $hub->species_defs;
  my $species           = $hub->species;
  my $common_name       = $species_defs->SPECIES_DISPLAY_NAME;
  my $display_name      = $species_defs->SPECIES_SCIENTIFIC_NAME;
  my $ensembl_version   = $species_defs->ENSEMBL_VERSION;
  my $current_assembly  = $species_defs->ASSEMBLY_NAME;
  my $accession         = $species_defs->ASSEMBLY_ACCESSION;
  my $source            = $species_defs->ASSEMBLY_ACCESSION_SOURCE || 'NCBI';
  my $source_type       = $species_defs->ASSEMBLY_ACCESSION_TYPE;
  my %archive           = %{$species_defs->get_config($species, 'ENSEMBL_ARCHIVES') || {}};
  my %assemblies        = %{$species_defs->get_config($species, 'ASSEMBLIES')       || {}};
  my $previous          = $current_assembly;

  my $html = qq(
<div class="column-wrapper">  
  <div class="column-one">
    <div class="column-padding no-left-margin">
      <h1 style="margin-bottom:0">$common_name Assembly and Gene Annotation</p>
    </div>
  </div>
</div>
          );

  $html .= '
<div class="column-wrapper">  
  <div class="column-two">
    <div class="column-padding no-left-margin">';
## EG START
# We use the old pages named about_{species}.html - maybe we should replace them later
#### ASSEMBLY
# $html .= '<h2 id="assembly">Assembly</h2>';
# $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_assembly.html");

# $html .= '<h2 id="genebuild">Gene annotation</h2>';
# $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/${species}_annotation.html");
## ....EG....
  my $lc_species = lc($species);
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/species/about_${lc_species}.html");
## EG END

  $html .= '
    </div>
  </div>
  <div class="column-two">
    <div class="column-padding" class="annotation-stats">';
    
  ## ASSEMBLY STATS 
  my $file = '/ssi/species/stats_' . $self->hub->species . '.html';
  $html .= '<h2>Statistics</h2>';
  $html .= $self->species_stats;

  $html .= '
    </div>
  </div>
</div>';

  return $html;  
}

1;
