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

package EnsEMBL::Web::Configuration::Gene;

use strict;
use warnings;

sub modify_tree {
  my $self = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $object = $self->object;
  my $sequence = $self->get_node('Sequence');

  my $gene_families = $self->create_node('Gene_families', 'Gene families',
    [qw( 
      selector     EnsEMBL::Web::Component::Gene::GeneFamilySelector
      genefamilies EnsEMBL::Web::Component::Gene::GeneFamilies 
      )],
    { 'availability' => 'gene database:compara', 'concise' => 'Gene families' }
  );
  $self->create_node( 'Gene_families/SaveFilter', '',
    [], { 'availability' => 'gene database:compara', 'no_menu_entry' => 1,
    'command' => 'EnsEMBL::Web::Command::GeneFamily::SaveFilter'}
  );
  $self->create_node( 'Gene_families/Sequence', '',
    [qw( alignment EnsEMBL::Web::Component::Gene::GeneFamilySeq )],
    { 'availability' => 'gene database:compara', 'no_menu_entry' => 1 }
  );
  
  $sequence->after($gene_families);
  
  $self->delete_node('Splice');
  $self->delete_node('Operons');
  

  $self->delete_node('Variation');
  #$self->delete_node('History');
  $self->delete_node('Compara');
  $self->delete_node('Evidence');
  $self->delete_node('Regulation');
  $self->delete_node('Phenotype');

  my $xrefs = $self->get_node('Matches');
   
##----------------------------------------------------------------------
## Compara menu: alignments/orthologs/paralogs/trees
#  my $pancompara_menu = $self->create_submenu( 'PanCompara', 'Pan-taxonomic Compara' );
 
  my $pancompara_menu = $self->create_node( 'PanCompara', 'Pan-taxonomic Compara',
    [qw(button_panel EnsEMBL::Web::Component::Gene::PanCompara_Portal)],
      {'availability' => 'gene database:compara_pan_ensembl core'}
  );
 
## Compara tree

my $tree_node = $self->create_node(
    'PanComparaTree', "Gene Tree",
    [qw(
      tree_summary EnsEMBL::Web::Component::Gene::PanComparaTreeSummary
      image EnsEMBL::Web::Component::Gene::PanComparaTree
    )],
    { 'availability' => 'gene database:compara_pan_ensembl core has_gene_tree_pan' }
  );
  $pancompara_menu->append( $tree_node );


#  my $tree_node = $self->create_node(
#    'Compara_Tree/pan_compara', "Gene Tree (image)",
#   #[qw(image        EnsEMBL::Web::Component::Gene::ComparaTree
#    [qw(
#      tree_summary EnsEMBL::Web::Component::Gene::ComparaTreeSummary
#      image EnsEMBL::Web::Component::Gene::ComparaTree
#    )],
#    { 'availability' => 'gene database:compara_pan_ensembl core has_gene_tree_pan' }
#  );
#  $tree_node->append( $self->create_subnode(
#    'Compara_Tree/Text_pan_compara', "Gene Tree (text)",
#    [qw(treetext        EnsEMBL::Web::Component::Gene::ComparaTree/Text_pan_compara)],
#    { 'availability' => 'gene database:compara_pan_ensembl core has_gene_tree_pan' }
#  ));

#  $tree_node->append( $self->create_subnode(
#    'Compara_Tree/Align_pan_compara',       "Gene Tree (alignment)",
#    [qw(treealign      EnsEMBL::Web::Component::Gene::ComparaTree/align_pan_compara)],
#    { 'availability' => 'gene database:compara_pan_ensembl core has_gene_tree_pan' }
#  ));
#  $pancompara_menu->append( $tree_node );  

  my $ol_node = $self->create_node(
    'Compara_Ortholog/pan_compara',   "Orthologues",
    [qw(orthologues EnsEMBL::Web::Component::Gene::ComparaOrthologs)],
    { 'availability' => 'gene database:compara_pan_ensembl core has_orthologs_pan',
      'concise'      => 'Orthologues' }
  );
  $pancompara_menu->append($ol_node);
  $ol_node->append( $self->create_subnode(
    'Compara_Ortholog/Alignment_pan_compara', 'Orthologue Alignment',
    [qw(alignment EnsEMBL::Web::Component::Gene::HomologAlignment)],
    { 'availability'  => 'gene database:compara_pan_ensembl core',
      'no_menu_entry' => 1 }
  ));

  $ol_node->append($self->create_subnode('Compara_Ortholog/PepSequence', 'Orthologue Sequences',
    [qw( alignment EnsEMBL::Web::Component::Gene::HomologSeq )],
           { 'availability'  => 'gene database:compara core has_orthologs', 'no_menu_entry' => 1 }
           ));
  my $pl_node = $self->create_node(
    'Compara_Paralog/pan_compara',    "Paralogues",
    [qw(paralogues  EnsEMBL::Web::Component::Gene::ComparaParalogs)],
    { 'availability' => 'gene database:compara_pan_ensembl core has_paralogs_pan',
           'concise' => 'Paralogues' }
  );
 $pancompara_menu->append($pl_node);
  $pl_node->append( $self->create_subnode(
    'Compara_Paralog/Alignment_pan_compara', 'Paralog Alignment',
    [qw(alignment EnsEMBL::Web::Component::Gene::HomologAlignment)],
    { 'availability'  => 'gene database:compara core',
      'no_menu_entry' => 1 }
  ));
  my $fam_node = $self->create_node(
    'Family/pan_compara', 'Protein families',
    [qw(family EnsEMBL::Web::Component::Gene::Family)],
    { 'availability' => 'family_pan_ensembl' , 'concise' => 'Protein families' }
  );
  $pancompara_menu->append($fam_node);
  my $sd = ref($self->{'object'}) ? $self->{'object'}->species_defs : undef;
  my $name = $sd ? $sd->SPECIES_DISPLAY_NAME : '';
  $fam_node->append($self->create_subnode(
    'Family/Genes_pan_compara', uc($name).' genes in this family',
    [qw(genes    EnsEMBL::Web::Component::Gene::FamilyGenes)],
    { 'availability'  => 'family_pan_ensembl database:compara_pan_ensembl core', # database:compara core',
      'no_menu_entry' => 1 }
  ));
  $fam_node->append($self->create_subnode(
    'Family/Proteins_pan_compara', 'Proteins in this family',
    [qw(ensembl EnsEMBL::Web::Component::Gene::FamilyProteins/ensembl_pan_compara
        other   EnsEMBL::Web::Component::Gene::FamilyProteins/other_pan_compara)],
    { 'availability'  => 'family_pan_ensembl database:compara_pan_ensembl core',
      'no_menu_entry' => 1 }
  ));
  $fam_node->append($self->create_subnode(
    'Family/Alignments_pan_compara', 'Multiple alignments in this family',
    [qw(jalview EnsEMBL::Web::Component::Gene::FamilyAlignments)],
    { 'availability'  => 'family_pan_ensembl database:compara_pan_ensembl core',
      'no_menu_entry' => 1 }
  ));

### EG
  $self->get_node('Ontologies')->after($pancompara_menu);
  

}

1;
