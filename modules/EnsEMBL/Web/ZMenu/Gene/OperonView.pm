# $Id $

package EnsEMBL::Web::ZMenu::Gene::OperonView;

use strict;

use base qw(EnsEMBL::Web::ZMenu);
use Data::Dumper;
sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $gene = $object->Obj;
  my ($operon) = @{$gene->feature_Slice->get_all_Operons};
  if(!defined $operon){return undef;}
  my $label = $operon->display_label;
  my $xref_content = "";
  foreach my $xref (@{$operon->get_all_DBEntries}){
    $xref_content .= sprintf("%s:\n%s\n",$xref->db_display_name,$xref->primary_id);
  }

  $self->caption($xref_content);
 #$self->caption($label);
  my %geneids;
  foreach my $ots (@{$operon->get_all_OperonTranscripts}){
    $geneids{$_->stable_id}=$_ for @{$ots->get_all_Genes};
  }
  my @genes;
  if(int($gene->strand)<0){
    @genes=reverse sort {$a->start<=>$b->start} values %geneids;
  }
  else{
    @genes=sort {$a->start<=>$b->start} values %geneids;
  }
  $label = sprintf("%s:%d-%d(%s)",
    $operon->display_label,
    $operon->feature_Slice->start,$operon->feature_Slice->end,
    $genes[0]->strand>0?'+':$genes[0]->strand<0?'-':' ');
  $self->add_entry({
      type  => 'Operon',
      label => $label,
      link  => $hub->url({ type => 'Gene', action => 'OperonSummary',g=>[$genes[0]->stable_id] })
  });
  foreach my $og (@genes){
  # $object->Obj($og);
    $label = sprintf("%s:%d-%d(%s)",
      $og->external_name || $og->stable_id,
      $og->start,$og->end,
      $og->strand>0?'+':$og->strand<0?'-':' ');
    $self->add_entry({
      type  => 'Gene',
      label => $label,
      link  => $hub->url({ type => 'Gene', action => 'Summary',g=>[$og->stable_id] })
    });
  }
 #$self->add_entry({
 #  type  => 'Gene',
 #  label => $object->stable_id,
 #  link  => $hub->url({ type => 'Gene', action => 'OperonView' })
 #});
  
  $self->add_entry({
    type  => 'Location',
    label => sprintf(
      '%s: %s-%s',
      $self->neat_sr_name($object->seq_region_type, $object->seq_region_name),
      $self->thousandify($object->seq_region_start),
      $self->thousandify($object->seq_region_end)
    ),
    link  => $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
    })
  });
  
# $self->add_entry({
#   type  => 'Gene type',
#   label => $object->gene_type
# });
  
  $self->add_entry({
    type  => 'Strand',
    label => $object->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });
  
  if ($object->analysis) {
    $self->add_entry({
      type  => 'Analysis',
      label => $object->analysis->display_label
    });
    
    $self->add_entry({
      type       => 'Prediction method',
      label_html => $object->analysis->description
    });
  }
}

1;
