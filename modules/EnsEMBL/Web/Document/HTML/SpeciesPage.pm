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

package EnsEMBL::Web::Document::HTML::SpeciesPage;

use strict;
use Data::Dumper;
use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Document::Table;

sub render {
  my ($self, $request ) = @_;
  my $hub          = EnsEMBL::Web::Hub->new;
  my $species_defs = $hub->species_defs;
  my $pan_compara  = $species_defs->get_config('MULTI', 'DATABASE_COMPARA_PAN_ENSEMBL');
  my $search       = $hub->param('search') || '';
  
  return qq{
    <div class="js_panel">
      <input type="hidden" class="panel_type" value="SpeciesIndexTable" />
      <input type="hidden" id="species_index_search"  value="$search" />
      <table id="species_index_table"  class="no_col_toggle data_table ss autocenter" style="width: 100%" cellpadding="0" cellspacing="0">
        <thead>
          <tr class="ss_header">
            <th class="hide"></th>
            <th title="Species">Species</th>
            <th title="Assembly">Assembly</th>
            <th title="Taxonomy ID">Taxonomy ID</th>
            <th title="Serotype">Serotype</th>
            <th title="Publications">Publications</th>
            <th title="Present in pan-taxonomic compara">Present in pan-taxonomic compara</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td colspan="7" class="dataTables_empty">Loading...</td>
          </tr>
        </tbody>
      </table>
    </div>
  };               
}

1;
