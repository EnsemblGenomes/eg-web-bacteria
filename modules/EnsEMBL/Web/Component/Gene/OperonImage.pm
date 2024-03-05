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
