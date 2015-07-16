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

package EnsEMBL::Web::Controller::Ajax;

use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::TaxonTree;
use Storable qw(lock_retrieve lock_nstore);
use JSON qw(from_json to_json);
use Data::Dumper;
use Compress::Zlib;

sub ajax_gene_family_dynatree_js {
  
  my ($self, $hub) = @_;
  my $gene_family_id = $hub->param('gene_family_id');
  my $r              = $hub->apache_handle;
  my $tree;
  
  # load cached gene family
  my $family  = EnsEMBL::Web::TmpFile::Text->new(prefix => 'genefamily', filename => "$gene_family_id.json");
  my $members = from_json($family->content);
  my $species;
  $species->{$_->{species}} = 1 for (@$members);
 
  my %plugin_dirs = @{$SiteDefs::ENSEMBL_PLUGINS};
       
  # load full tree and prune
  $tree = lock_retrieve($plugin_dirs{'EG::Bacteria'} . "/data/taxon_tree.packed") or die("failed to retrieve taxon tree ($@)");
  $tree->prune($species);
  $tree->collapse; 
  
  #print Dumper($species);
  
  # fetch selected species from session
  my @selected_species;
  if (my $data = $hub->session->get_data(type => 'genefamilyfilter', code => $hub->data_species . '_' . $gene_family_id )) {
    @selected_species = split /,/, uncompress( $data->{filter} );
  }
  
  # generate js with species selected and expanded
  $js = $tree->to_dynatree_js_variable('taxonTreeData', \@selected_species);
  
  $r->content_type('application/javascript');
  print $js;
}

sub ajax_species_list {
  my ($self, $hub) = @_;
  my $species_defs   = $hub->species_defs;
  my $pan_compara    = $species_defs->get_config('MULTI', 'DATABASE_COMPARA_PAN_ENSEMBL');
  my $r              = $hub->apache_handle;
  
  my $display_start  = $hub->param('iDisplayStart');
  my $display_length = $hub->param('iDisplayLength');
  my $sort_cols      = $hub->param('iSortingCols');
  my $search         = $hub->param('sSearch');
  my $is_sorted      = $hub->param('iSortCol_0');
  my $echo           = $hub->param('sEcho');
  my @data;
  
  # populate
  
  foreach my $species (sort $species_defs->valid_species) {
    my $alias          = $species_defs->get_config($species, 'SPECIES_ALIAS');
    my $tax_id         = $species_defs->get_config($species, 'TAXONOMY_ID');
    my $assembly_name  = $species_defs->get_config($species, 'ASSEMBLY_NAME');
    my $serotype       = $species_defs->get_config($species, 'SEROTYPE');
    my $publications   = $species_defs->get_config($species, 'PUBLICATIONS');
    my $display_name   = $species_defs->species_display_label($species);
    my $in_pan_compara = exists $pan_compara->{GENOME_DB}->{$species}; 
     
    push @data, [
      join (' ', ref $alias eq 'ARRAY' ? @$alias : ($alias)),
      qq{<a href="/$species/Info/Index/">$display_name</a>},
      qq{<a href="/$species/Info/Annotation/#assembly">$assembly_name</a>},
      qq{<a href="http://www.uniprot.org/taxonomy/$tax_id">$tax_id</a>},
      $serotype,
      join(' ', map { qq{<a href="http://europepmc.org/abstract/MED/$_">$_</a>} } @{ $publications || [] }),
      $in_pan_compara ? 'Y' : 'N', # hack to reverse sorting
    ];
  }
  
  my $total = @data;
  
  # filter (assume all cols are filterable)
    
  @data = grep { join(' ', @$_) =~ /\Q$search\E/i } @data if $search; 
  my $totalFiltered = @data;
  
  # sort 
  
  if ($is_sorted) {
    my $sort = sub {
      my ($a, $b) = @_;
      for my $i (0..$sort_cols) {
        my $col = $hub->param("iSortCol_$i");
        my $cmp = $hub->param("sSortDir_$i") eq 'asc' ? $a->[$col] cmp $b->[$col] : $b->[$col] cmp $a->[$col];
        return $cmp if $cmp;    
      }
      return 0;
    };
    @data = sort { $sort->($a, $b) } @data;
  }
  
  # limit
    
  if ( length($display_start) and $display_length ne '-1' ) {
    my $start = $display_start;
    my $end   = $start + $display_length;
       $end   = @data if $end > @data;
    @data = @data[$start..$end-1];
  }
  
  # return
  
  my $output = {
    sEcho => int($echo),
    iTotalRecords => $total,
    iTotalDisplayRecords => $totalFiltered,
    aaData => \@data,
  };
  
  my $json = to_json($output); 
  $r->content_type('application/json');
  print $json;
}


1;
