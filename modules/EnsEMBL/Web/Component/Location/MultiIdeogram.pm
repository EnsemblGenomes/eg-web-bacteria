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

package EnsEMBL::Web::Component::Location::MultiIdeogram;

use Image::Size;

sub content {
  my $self = shift;
  
  my $object       = $self->object;
  my $species_defs = $self->hub->species_defs;
  my $image_width  = $self->image_width;
  my $i            = 1;
  my @images;
  
  my $slices = $object->multi_locations;

  my $coord_name = '';
  foreach (@$slices) {
    $coord_name = 'other' if ($_->{'slice'}->coord_system_name !~ /chromosome|plasmid/);
  }

  if ($coord_name eq 'other') {

    foreach (@$slices) {
      my $image_config = $object->get_imageconfig('MultiIdeogram', "chromosome_$i", $_->{'species'});
      my $chromosome = $_->{'slice'}->adaptor->fetch_by_region(undef, $_->{'name'});

      $image_config->set_parameters({
      container_width => $chromosome->seq_region_length,
      image_width     => $image_width,
      slice_number    => "$i|1",
      multi           => 1
      });

      if ($image_config->get_node('annotation_status')) {
	$image_config->get_node('annotation_status')->set('caption', '');
	$image_config->get_node('annotation_status')->set('menu', 'no');
      };

      $image_config->get_node('ideogram')->set('caption', $_->{'short_name'});

      push @images, $chromosome, $image_config;
      $i++;
    }

    my $image = $self->new_image(\@images);

    return if $self->_export_image($image);

    $image->imagemap = 'yes';
    $image->set_button('drag', 'title' => 'Click or drag to centre display');
    $image->{'panel_number'} = 'ideogram';

    my $html = $image->render;

    return $html;

  } else { 

    my $html = '<span class="labelImg" style="display:block;margin:auto;text-align:center;font-size:10px;">';
  
    foreach (@$slices) {
    
      my $species      = $_->{'species'};
      my $display_name = $species_defs->species_display_label($species);
      my $chr_name     = $_->{'name'};
      my $img          = 'region_'.$species.'_'.$chr_name.'.png';
      my $chromosome   = $_->{'slice'}->adaptor->fetch_by_region(undef, $_->{'name'});
      my $region_name  =  $chromosome->seq_region_name;
      my $cr           = $chromosome->is_circular || 0;
      my $id           = $region_name.'~'.$chromosome->seq_region_length.'~'.$cr.'~'.$i.'~~'.@$slices; 

      my ($width, $height);
      for (my $i = 0; $i < @{SiteDefs::ENSEMBL_HTDOCS_DIRS}; $i++) {
        next unless (${SiteDefs::ENSEMBL_PLUGIN_ROOTS}->[$i] =~ /EnsEMBL::EnsemblBacteria/);
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
      my $new_w = $width  + 10;
      my $new_h = $height + 10;

      $html .= '
       <input class="panel_type" type="hidden" value="IdeogramPanel" />                                                                                                                           
       <div style="margin: 3px 20px 20px 3px; display: inline-block; vertical-align: top; zoom:1; *display:inline">
         <p style="margin-bottom:5px">'.$display_name.'<br>'.$region_name.'</p>
         <img style="margin-left: 8px; margin-right: 8px" class="circularImage" align="middle" height="'.$height.'" width="'.$width.'" alt="Click and drag the handles to select a region" id="'.$id.'" src="/img/species/'.$img.'">
       </div>
      ';

      $i++;
    }

    $i++;
  
    $html .=  ' 
      <div class="labelDiv" style="visibility: hidden; font-size: 10px; padding-bottom: 4px;">Drag the handles to select a region and click on selected region to update location</div> 
    </span>
    ';

    return $html;
  }

}

1;
