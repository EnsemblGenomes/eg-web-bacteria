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

package EnsEMBL::Web::Component::Gene::TranscriptsImage;

use strict;

sub content {
  my $self   = shift;
  my $object = $self->object || $self->hub->core_object('gene');
  my $gene   = $object->Obj;

## EG  
  my $gene_slice;
  my ($operon) = @{$gene->feature_Slice->get_all_Operons};
  if($operon){
    my ($ot)=sort {$b->length <=> $a->length} @{$operon->get_all_OperonTranscripts};
    $gene_slice = $ot->feature_Slice->expand(5000,5000);
  }
  else{
    $gene_slice = $gene->feature_Slice->expand(10e3,10e3);
  }
##
  $gene_slice = $gene_slice->invert if $object->seq_region_strand < 0;

  # Get the web_image_config
  my $image_config = $object->get_imageconfig('gene_summary');
  
  $image_config->set_parameters({
    container_width => $gene_slice->length,
    image_width     => $object->param('i_width') || $self->image_width || 800,
    slice_number    => '1|1',
  });
  
  my $key  = $image_config->get_track_key('transcript', $object);
  my $node = $image_config->get_node(lc $key);
  
  $node->set('display', 'transcript_label') if $node && $node->get('display') eq 'off';
## EG  
  $image_config->modify_configs([$key], {label_operon_genes=>0});#not working :(
##
  my $image = $self->new_image($gene_slice, $image_config, [ $gene->stable_id ]);
  
  return if $self->_export_image($image);
  
  $image->imagemap         = 'yes';
  $image->{'panel_number'} = 'top';
  $image->set_button('drag', 'title' => 'Drag to select region');
  
  return $image->render;
## EG  
   # . $self->_info(
   #'Configuring the display',
   #'<p>Tip: use the "<strong>Configure this page</strong>" link on the left to show additional data in this region.</p>'
   #);
##
}

1;
