=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Query::Availability::Gene;

use strict;
use warnings;

sub _count_go {
  my ($self,$args,$out) = @_;

  my $go_name;
  foreach my $transcript (@{$args->{'gene'}->get_all_Transcripts}) {
    next unless $transcript->translation;
    my $dbc = $self->database_dbc($args->{'species'},$args->{'type'});
    my $tl_dbID = $transcript->translation->dbID;

    # First get the available ontologies
    my $ontologies = $self->sd_config($args,'SPECIES_ONTOLOGIES');
    if(@{$ontologies||[]}) {
      my $ontologies_list = sprintf(" in ('%s') ",join("','",@$ontologies));
      $ontologies_list = " ='$ontologies->[0]'" if @$ontologies == 1;

      my $sql = qq{
        SELECT distinct(dbprimary_acc)
            FROM object_xref ox, xref x, external_db edb
            WHERE ox.xref_id = x.xref_id
            AND x.external_db_id = edb.external_db_id
            AND edb.db_name $ontologies_list
            AND ((ox.ensembl_object_type = 'Translation' AND ox.ensembl_id = ?)
            OR   (ox.ensembl_object_type = 'Transcript'  AND ox.ensembl_id = ?))};

      # Count the ontology terms mapped to the translation
      my $sth = $dbc->prepare($sql);
      $sth->execute($transcript->translation->dbID, $transcript->dbID);
      foreach ( @{$sth->fetchall_arrayref} ) {
        $go_name .= '"'.$_->[0].'",';
      }
    }
  }
  return unless $go_name;
  $go_name =~ s/,$//g;

  my $goadaptor = $self->database_dbc($args->{'species'},'go');

  my $go_sql = qq{SELECT o.ontology_id,COUNT(*) FROM term t1  JOIN closure ON (t1.term_id=closure.child_term_id)  JOIN term t2 ON (closure.parent_term_id=t2.term_id) JOIN ontology o ON (t1.ontology_id=o.ontology_id)  WHERE t1.accession IN ($go_name)  AND t2.is_root=1  AND t1.ontology_id=t2.ontology_id GROUP BY o.namespace};

  my $sth = $goadaptor->prepare($go_sql);
  $sth->execute();

  my %clusters = $self->multiX('ONTOLOGIES');
  $out->{"has_go_$_"} = 0 for(keys %clusters);

  foreach (@{$sth->fetchall_arrayref}) {
    my $goid = $_->[0];
    if ( exists $clusters{$goid} ) {
      $out->{"has_go_$goid"} = $_->[1];
    }
  }
}

sub get {
  my ($self,$args) = @_;

  my $ad = $self->source('Adaptors');
  my $out = $self->super_availability($args);

  my $member = $self->compara_member($args) if $out->{'database:compara'};
  my $panmember = $self->pancompara_member($args) if $out->{'database:compara_pan_ensembl'};
  my $counts = $self->_counts($args,$member,$panmember);

  $out->{'counts'} = $counts;
  $out->{'history'} =
    0+!!($self->table_info($args,'stable_id_event')->{'rows'});
  $out->{'gene'} = 1;
  $out->{'core'} = $args->{'type'} eq 'core';
  $out->{'has_gene_tree'} = $member ? $member->has_GeneTree : 0;
  $out->{'can_r2r'} = $self->sd_config($args,'R2R_BIN');
  if($self->sd_config($args,'RELATED_TAXON')) { #gene tree availability check for strain
    $out->{'has_strain_gene_tree'} = $member ? $member->has_GeneTree($self->sd_config($args,'RELATED_TAXON')) : 0; #TODO: replace hardcoded species
  }  

  if($out->{'can_r2r'}) {
    my $canon = $args->{'gene'}->canonical_transcript;
    $out->{'has_2ndary'} = 0;
    $out->{'has_2ndary_cons'} = 0;
    if($canon and @{$canon->get_all_Attributes('ncRNA')}) {
      $out->{'has_2ndary'} = 1;
    }
    if($out->{'has_gene_tree'}) {
      my $tree = $self->default_gene_tree($args,$member);
      if($tree and $tree->get_tagvalue('ss_cons')) {
        $out->{'has_2ndary_cons'} = 1;
        $out->{'has_2ndary'} = 1;
      }
    }
  }
  $out->{'alt_allele'} = $self->table_info($args,'alt_allele')->{'rows'};
  if($self->regulation_db_adaptor($args)) {
    $out->{'regulation'} =
      0+!!($self->table_info($args,'feature_set','funcgen')->{'rows'});
  }
  $out->{'regulation'} ||= '';
  $out->{'has_species_tree'} = $member ? $member->has_GeneGainLossTree : 0;
  $out->{'family'} = !!$counts->{'families'};
  $out->{'family_count'} = $counts->{'families'};
  $out->{'not_rnaseq'} = $args->{'type'} ne 'rnaseq';
  for (qw(
    transcripts alignments paralogs strain_paralogs orthologs strain_orthologs similarity_matches
    operons structural_variation pairwise_alignments
  )) {
    $out->{"has_$_"} = $counts->{$_};
  }

  $self->_count_go($args, $out);
  $out->{'multiple_transcripts'} = ($counts->{'transcripts'}>1);
  $out->{'not_patch'} = 0+!($args->{'gene'}->stable_id =~ /^ASMPATCH/);
  $out->{'has_alt_alleles'} = 0+!!(@{$self->_get_alt_alleles($args)});
  $out->{'not_human'} = 0+($args->{'species'} ne 'Homo_sapiens');
  if($self->variation_db_adaptor($args)) {
    $out->{'has_phenotypes'} = $self->_get_phenotype($args);
  }
  if($out->{'database:compara_pan_ensembl'} && $self->pancompara_db_adaptor) {
    $out->{'family_pan_ensembl'} = !!$counts->{'families_pan'};
    $out->{'has_gene_tree_pan'} =
      $panmember ? $panmember->has_GeneTree : 0;
    for (qw(alignments_pan paralogs_pan orthologs_pan)) {
      $out->{"has_$_"} = $counts->{$_};
    }
  }

  return [$out];
}

1;
