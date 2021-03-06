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

#$Id: Transcript.pm,v 1.15 2013-01-28 14:00:16 ek3 Exp $
package EnsEMBL::Web::Configuration::Transcript;

use strict;

sub modify_tree {
  my $self = shift;
  my $object = $self->object;
  
  return unless $object;
  
  my $hub = $self->hub;
  my $species_defs = $hub->species_defs;  
  my $gene   = $object->gene;
  my $gene_id     = $gene->stable_id;
  my $transcripts = $gene->get_all_Transcripts;

  my $tree        = $self->tree;
  my $hub         = $self->hub;
  my $protein     = $hub->param('p');
  my $transcript     = $hub->param('t');
  my @protein_arr = ();
  push @protein_arr, $protein if ($protein);

## ENA
  $self->delete_node('Sequence_cDNA');
  $self->delete_node('Sequence_Protein');
  $self->delete_node('History');
  $self->delete_node('Variation');
  $self->delete_node('SupportingEvidence');
## ENA

  my $arr = [];
  my $prot_menu = $self->get_node('Protein');
  my $domains = $prot_menu->get_node('Domains');

  
  $_->remove for @{$prot_menu->child_nodes};
  $domains->set('no_menu_entry',1);
  $prot_menu->append($domains);
    
  foreach (grep { $_->stable_id eq $transcript }  @$transcripts) {
    my $tr = $_->stable_id;

    if (($_->translation) && ($_->stable_id eq $transcript))  {
      my $pr = $_->translation->stable_id;
      $arr->[0]->{t}  = $tr;
      $arr->[0]->{p}  = $pr;
    }
    if($_->get_all_alternative_translations) {
      my $jj = 1;
      foreach my $atrans (@{$_->get_all_alternative_translations}) {
        $arr->[$jj]->{t}  = $tr;
      	$arr->[$jj]->{p}  = $atrans->stable_id;
      	$jj++;    
      }
    }

    foreach my $el (@$arr) {
      my $t = $el->{t};  
      my $p = $el->{p};

      my $url = $hub->url({
                  type   => 'Transcript',
                  action => 'ProteinSummary_'.$p,
                  t      => $t,
                  p      => $p
	        });

      my $tree_node = $self->create_node('ProteinID_'.$p, $p,
      [qw(
       image      EnsEMBL::Web::Component::Transcript::TranslationImage
       statistics EnsEMBL::Web::Component::Transcript::PepStats
       )],
          { 'availability' => 'either', 'concise' => 'Protein summary', 'url' =>  $url}
      );

      #$tree_node->append($self->create_subnode(
      $tree_node->append($self->create_subnode('ProteinSummary_'.$p, 'Protein summary',
      [qw(
       image      EnsEMBL::Web::Component::Transcript::TranslationImage
       statistics EnsEMBL::Web::Component::Transcript::PepStats
      )],
	  { 'availability' => 'either', 'concise' => 'Protein summary', 'url' =>  $url }
					  ));

      $url = $hub->url({
                  type   => 'Transcript',
                  action => 'Sequence_cDNA_'.$p,
                  t      => $t,
                  p      => $p
		  });

      $tree_node->append($self->create_subnode('Sequence_cDNA_'.$p, 'cDNA',
      [qw( sequence EnsEMBL::Web::Component::Transcript::TranscriptSeq )],
	  { 'availability' => 'either', 'concise' => 'cDNA sequence', 'url' =>  $url }
					  ));

      $url = $hub->url({
                  type   => 'Transcript',
                  action => 'Sequence_Protein_'.$p,
                  t      => $t,
                  p      => $p
                  });

      $tree_node->append($self->create_subnode('Sequence_Protein_'.$p, 'Protein sequence',
      [qw( sequence EnsEMBL::Web::Component::Transcript::ProteinSeq )],
	  { 'availability' => 'either', 'concise' => 'Protein sequence', 'url' =>  $url }
					  ));

      $url = $hub->url({
                  type   => 'Transcript',
                  action => 'Domains_'.$p,
                  t      => $t,
                  p      => $p
                  });

      my $D = $self->create_subnode('Domains_'.$p, 'Domains & features',
      [qw( domains EnsEMBL::Web::Component::Transcript::DomainSpreadsheet )],
	   { 'availability' => 'transcript has_domains', 'concise' => 'Domains & features', 'url' =>  $url }
			       );

      $tree_node->append($D);

      $url = $hub->url({
                  type   => 'Transcript',
                  action => 'ProtVariations_'.$p,
                  t      => $t,
                  p      => $p
                  });

      $tree_node->append($self->create_subnode('ProtVariations_'.$p, 'Variations ([[counts::prot_variations]])',
      [qw( protvars EnsEMBL::Web::Component::Transcript::ProteinVariations )],
	   { 'availability' => 'either database:variation has_variations', 'concise' => 'Variations', 'url' =>  $url }
					  ));


      $prot_menu->append( $tree_node );
    }  
  }
  
  # put protein menu at top
  #$tree->child_nodes->[0]->before($prot_menu);
 
  # EG:ENSEMBL-2785 add this new URL so that the Transcript info appears at the top of the page for the Karyotype display with Locations tables
    my $sim_node = $self->get_node('Similarity');
    $sim_node->append($self->create_subnode('Similarity/Locations', '',
      [qw(
         genome  EnsEMBL::Web::Component::Location::Genome
      ) ],
      {  'availability' => 'transcript', 'no_menu_entry' => 1 }
    ));
  # EG:ENSEMBL-2785 end
}


1;

