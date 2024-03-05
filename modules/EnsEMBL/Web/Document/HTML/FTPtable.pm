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

package EnsEMBL::Web::Document::HTML::FTPtable;

### This module outputs a table of links to the FTP site

use strict;
use warnings;

use base qw(EnsEMBL::Web::Document::HTML);


sub render {
  my ($self, $request ) = @_;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $search       = $hub->param('search') || '';
  my $rel          = $species_defs->SITE_RELEASE_VERSION;

  return qq{
    <div class="js_panel">
      <input type="hidden" class="panel_type" value="FTPTable" />
      <input type="hidden" id="ftp_table_search"  value="$search" />
      <table id="ftp_table"  class="no_col_toggle data_table ss autocenter" style="width: 100%" cellpadding="0" cellspacing="0">
        <thead>
          <tr class="ss_header">
            <th class="hide"></th>
            <th title="Species">Species</th>
            <th title="DNA (FASTA)">DNA (FASTA)</th>
            <th title="cDNA (FASTA)">cDNA (FASTA)</th>
            <th title="Protein sequence (FASTA)">Protein sequence (FASTA)</th>
            <th title="Annotated sequence (EMBL)">Annotated sequence (EMBL)</th>
            <th title="Whole databases">Whole databases</th>
            <th title="GTF">GTF</th>
            <th title="Variation (VEP)">Variation (VEP)</th>
            <th title="TSV">TSV</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td colspan="7" class="dataTables_empty">Loading...</td>
          </tr>
        </tbody>
      </table>
      <h2>Pantaxonomic compara multi-species</h2>
      <p>
        Pantaxonomic compara multi-species data on the genomes provided by Ensembl Genomes is available from the FTP site in the following formats.
      </p>
      <p>
        Ensembl Genomes:
        <a href="https://ftp.ensemblgenomes.ebi.ac.uk/pub/pan_ensembl/release-$rel/mysql/">MySQL</a> |
        <a href="https://ftp.ensemblgenomes.ebi.ac.uk/pub/pan_ensembl/release-$rel/tsv/">TSV</a> |
      </p>
    </div>
  };               
}


1;
