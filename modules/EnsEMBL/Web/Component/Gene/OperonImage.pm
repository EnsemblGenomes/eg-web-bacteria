package EnsEMBL::Web::Component::Gene::OperonImage;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init { 
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub caption {
  return 'Transcripts';
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $gene   = $object->Obj;
  my $slice;
  my ($operon) = @{$gene->feature_Slice->get_all_Operons};
  if($operon){
    my ($ot)=sort {$b->length <=> $a->length} @{$operon->get_all_OperonTranscripts};
    $slice = $ot->feature_Slice;
  }
  else{
    $slice = $gene->feature_Slice->expand(10e3,10e3);
  }
     
  # Get the web_image_config
  my $image_config = $object->get_imageconfig('gene_summary');
  
  $image_config->set_parameters({
    container_width => $slice->length,
    image_width     => $object->param('i_width') || $self->image_width || 800,
    slice_number    => '1|1',
  });
  
  $self->_attach_das($image_config);

  my $key  = $image_config->get_track_key('transcript', $object);
  my $node = $image_config->get_node(lc $key);
  
  $node->set('display', 'transcript_label') if $node && $node->get('display') eq 'off';
  $image_config->modify_configs([$key], {no_operons=>0});

  my $image = $self->new_image($slice, $image_config, [ $gene->stable_id ]);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  return $image->render;
}

1;
