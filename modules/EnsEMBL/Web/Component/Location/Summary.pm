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

package EnsEMBL::Web::Component::Location::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);

use Image::Size;


use EnsEMBL::Web::RegObj;
use Data::Dumper;

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content { 
  my $self         = shift;
  my $object       = $self->object;
  my $species_defs = $self->hub->species_defs;

  return '' unless $object && $object->seq_region_name && $self->hub->action ne 'Genome' && $self->hub->action ne 'Chromosome';;

  my $slice = $object->database('core')->get_SliceAdaptor->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );

  my $coord_name = $slice->coord_system_name;

  if ($coord_name !~ /chromosome|plasmid/) {

    my $image_config = $object->get_imageconfig('chromosome');

    $image_config->set_parameters({
    container_width => $object->seq_region_length,
    image_width     => $self->image_width,
    slice_number    => '1|1'
    });

    if ($image_config->get_node('annotation_status')) {
      $image_config->get_node('annotation_status')->set('caption', '');
      $image_config->get_node('annotation_status')->set('menu', 'no');
    };

    $image_config->get_node('ideogram')->set('caption', $object->seq_region_type . ' ' . $object->seq_region_name );

    my $image = $self->new_image($slice, $image_config);

    return if $self->_export_image($image);

    $image->imagemap = 'yes';
    $image->{'panel_number'} = 'context';
    $image->set_button('drag', 'title' => 'Click or drag to centre display');

    return $image->render;
  
  } else {

    my $species      = $object->species;
    my $display_name = $species_defs->species_display_label($species);
    my $chr_name     = $object->seq_region_name;
    my $img          = 'region_'.$species.'_'.$chr_name.'.png';
    my $region_name  = $object->seq_region_name;

    # get the image size
    my ($width, $height);
    for (my $i = 0; $i < @{SiteDefs::ENSEMBL_HTDOCS_DIRS}; $i++) {
      next unless (${SiteDefs::ENSEMBL_PLUGIN_ROOTS}->[$i] =~ /Bacteria/); 
      ($width, $height)    = imgsize(${SiteDefs::ENSEMBL_HTDOCS_DIRS}[$i] . "/img/species/".$img);
      last;
    }

    if (((!$width) && (!$height)) || (($width>220) && ($height>220))) {
      $width =  220;
      $height = 220;
    } elsif($width < 100) {
      $width = $width + 1/2*$width;
      $height = $height + 1/2*$height;
    } 
    my $cr = $slice->is_circular || 0;
  
    return '<input class="panel_type" type="hidden" value="IdeogramPanel" />
            <span class="labelImg" style="display:block;margin:auto;width:400px;text-align:center;font-size:10px;">
            '.$display_name.'<br>'.$region_name.'
            <div style="width:'.$width.'px;height:'.$height.'px;margin: 0px auto 10px auto;"><img class="circularImage" height="'.$height.'" width="'.$width.'" alt="Click and drag the handles to select a region" id="'.$region_name.'~'.$object->seq_region_length.'~'.$cr.'~0" src="/img/species/'.$img.'" border="0"></div>
            <div class="labelDiv" style="visibility: hidden; font-size: 10px; padding-bottom: 4px;">Drag the handles to select a region and click on selected region to update location</div> 
          </span>
    ';
  
  }

}

1;
