package EnsEMBL::Web::Object::Gene;

use strict;
use warnings;
no warnings "uninitialized";
use JSON;
use EnsEMBL::Web::TmpFile::Text;

use previous qw(availability);

sub availability {
  my $self = shift; 

  if (!$self->{_availability}) {
    $self->PREV::availability;
    my $db        = $self->database('core');
    my $stable_id = $self->Obj->stable_id;
    my $count     = $db->dbc->db_handle->selectrow_array('SELECT count(*) FROM stable_id_event WHERE old_stable_id = ? OR new_stable_id = ?', undef, $stable_id, $stable_id);
    $self->{_availability}->{history} = !!$count;
  }
  
  return $self->{_availability};
}

sub filtered_family_data {
  my ($self, $family) = @_;
  my $hub       = $self->hub;
  my $family_id = $family->stable_id;
  
  my $members = []; 
  my $temp_file = EnsEMBL::Web::TmpFile::Text->new(prefix => 'genefamily', filename => "$family_id.json"); 
   
  if ($temp_file->exists) {
    $members = from_json($temp_file->content);
  } else {      
    my $member_objs = $family->get_all_Members;
    while (my $member = shift @$member_objs) {
      my $gene_member = $member->gene_member;
      push (@$members, {
        name        => $gene_member->display_label,
        id          => $member->stable_id,
        taxon_id    => $member->taxon_id,
        description => $gene_member->description,
        species     => $member->genome_db->name
      });  
    }
    $temp_file->print($hub->jsonify($members));
  }  
  
  my $total_member_count  = scalar @$members;
     
  my $species;   
  $species->{$_->{species}} = 1 for (@$members);
  my $total_species_count = scalar keys %$species;
 
  # apply filter from session
 
  my @filter_species;
  if (my $filter = $hub->session->get_data(type => 'genefamilyfilter', code => $hub->data_species . '_' . $family_id )) {
    @filter_species = split /,/, $filter->{filter};
  }
    
  if (@filter_species) {
    $members = [grep {my $sp = $_->{species}; grep {$sp eq $_} @filter_species} @$members];
    $species = {};
    $species->{$_->{species}} = 1 for (@$members);
  } 
  
  # return results
  
  my $data = {
    members             => $members,
    species             => $species,
    member_count        => scalar @$members,
    species_count       => scalar keys %$species,
    total_member_count  => $total_member_count,
    total_species_count => $total_species_count,
    is_filtered         => @filter_species ? 1 : 0,
  };
  
  return $data;
}

sub fetch_homology_species_hash {
  my $self                 = shift;
  my $homology_source      = shift;
  my $homology_description = shift;
  my $compara_db           = shift || 'compara';
  
  $homology_source      = 'ENSEMBL_HOMOLOGUES' unless defined $homology_source;
  $homology_description = 'ortholog' unless defined $homology_description;
  
  my $geneid   = $self->stable_id;
  my $database = $self->database($compara_db);
  my %homologues;

  return {} unless $database;
  
  $self->timer_push('starting to fetch', 6);

  my $member_adaptor = $database->get_MemberAdaptor;
  my $query_member   = $member_adaptor->fetch_by_source_stable_id('ENSEMBLGENE', $geneid);

  return {} unless defined $query_member;
  
  my $homology_adaptor = $database->get_HomologyAdaptor;
  my $homologies_array = $homology_adaptor->fetch_all_by_Member($query_member); # It is faster to get all the Homologues and discard undesired entries than to do fetch_all_by_Member_method_link_type

  $self->timer_push('fetched', 6);

  # Strategy: get the root node (this method gets the whole lineage without getting sister nodes)
  # We use right - left indexes to get the order in the hierarchy.
  
  my %classification = ( Undetermined => 99999999 );
  
  if (my $taxon = $query_member->taxon) {
    my $node = $taxon->root;

    while ($node) {
      $node->get_tagvalue('scientific name');
      
      # Found a speed boost with nytprof -- avilella
      # $classification{$node->get_tagvalue('scientific name')} = $node->right_index - $node->left_index;
      $classification{$node->{_tags}{'scientific name'}} = $node->{'_right_index'} - $node->{'_left_index'};
      $node = $node->children->[0];
    }
  }
  
  $self->timer_push('classification', 6);
  
  foreach my $homology (@$homologies_array) {
    next unless $homology->description =~ /$homology_description/;
    
    my ($query_perc_id, $target_perc_id, $genome_db_name, $target_member, $dnds_ratio);
    
    foreach my $member (@{$homology->get_all_Members}) {
      my $gene_member = $member->gene_member;

      if ($gene_member->stable_id eq $query_member->stable_id) {
        $query_perc_id = $member->perc_id;
      } else {
        $target_perc_id = $member->perc_id;
        $genome_db_name = $member->genome_db->name;
        $target_member  = $gene_member;
        $dnds_ratio     = $homology->dnds_ratio; 
      }
    }
    
    # FIXME: ucfirst $genome_db_name is a hack to get species names right for the links in the orthologue/paralogue tables.
    # There should be a way of retrieving this name correctly instead.
#    push @{$homologues{ucfirst $genome_db_name}}, [ $target_member, $homology->description, $homology->subtype, $query_perc_id, $target_perc_id, $dnds_ratio, $homology->ancestor_node_id];
## EG : we don;t need this hack
    push @{$homologues{$genome_db_name}}, [ $target_member, $homology->description, $homology->subtype, $query_perc_id, $target_perc_id, $dnds_ratio, $homology->ancestor_node_id];
  }
  
  $self->timer_push('homologies hacked', 6);
  
  @{$homologues{$_}} = sort { $classification{$a->[2]} <=> $classification{$b->[2]} } @{$homologues{$_}} for keys %homologues;
  
  return \%homologues;
}

sub get_operons{
  my $self    = shift;
  my $obj = $self->Obj;
  return [] unless $obj->can('feature_Slice');
  
  my $stable_id = $obj->stable_id;
  my $slice = $obj->feature_Slice;
  my $species = $self->species;
  my $operon_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Operon");
  my @all_operons = @{$operon_adaptor->fetch_all_by_Slice($obj->feature_Slice)};
  my @operons;
  foreach my $op (@all_operons){
    my $gene_in_ots = 0;
    foreach my $ots (@{$op->get_all_OperonTranscripts}){
      foreach my $gene_stable_id(map {$_->stable_id} @{$ots->get_all_Genes}){
        if($stable_id eq $gene_stable_id){
          push(@operons,$op);
          $gene_in_ots = 1; 
          last;
        }
      }
      last if $gene_in_ots;
    }
  }
  return \@operons;
}

sub caption{
  my $self        = shift;
  my $hub         = $self->hub;
  my $action      = $hub->action;
  my ($operon) = $self->can('get_operons')?@{$self->get_operons}:(); 
  return $self->_caption(@_) if $action ne "OperonSummary" || !$operon;
  return sprintf("Operon: %s",$operon->display_label);
}

sub _caption { # Keep this the same as in the non-plugin module
  my $self = shift;
  my( $disp_id ) = $self->display_xref;
  my $caption = $self->type_name.': ';
  if( $disp_id ) {
    $caption .= "$disp_id (".$self->stable_id.")";
  } else {
    $caption .= $self->stable_id;
  }
  return $caption;
}
  
1;
