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

      my $D = $self->create_subnode('Domains_'.$p, 'Domains & features ([[counts::prot_domains]])',
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
  
  my @reversed_nodes = reverse(@{$tree->child_nodes});
  foreach my $node (@reversed_nodes) {                                                                                                                                                                       
    $prot_menu->after($node);
  }   
  
  #Ontology graphs are split in separate pages:


  my $go_menu = $self->get_node('GO');
  $self->delete_node('Ontology/Image');
  $self->delete_node('Ontology/Table');

  # get all ontologies mapped to this species
  my %olist = map {$_ => 1} @{$species_defs->DISPLAY_ONTOLOGIES ||[]};

  if (%olist) {


     # get all ontologies available in the ontology db
     my %clusters = $species_defs->multiX('ONTOLOGIES');

     # get all the clusters that can generate a graph
     my @clist =  grep { $olist{ $clusters{$_}->{db} }} sort {$clusters{$a}->{db} cmp $clusters{$b}->{db}} keys %clusters; # Find if this ontology has been loaded into ontology db

     foreach my $oid (@clist) {
	 my $cluster = $clusters{$oid};
	 my $dbname = $cluster->{db};

	 my $go_hash  = $self->object ? $object->get_ontology_chart($dbname, $cluster->{root}) : {};
	 next unless (%$go_hash);
	 my @c = grep { $go_hash->{$_}->{selected} } keys %$go_hash;
	 my $num = scalar(@c);
	 
	 my $url2 = $hub->url({
	     type    => 'Transcript',
	     action  => 'Ontology/'.$oid,
	     oid     => $oid
			      });

	 (my $desc2 = "$cluster->{db}: $cluster->{description}") =~ s/_/ /g;
	 $go_menu->append($self->create_node('Ontology/'.$oid, "$desc2 ($num)",
					     [qw( go EnsEMBL::Web::Component::Gene::Ontology )],
					     { 'availability' => 'transcript has_go', 'concise' => $desc2, 'url' =>  $url2 }
			  ));
	 
     }
  }
  #Ontology graphs EOF      
}


1;

