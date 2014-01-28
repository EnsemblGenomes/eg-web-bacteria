package EnsEMBL::Web::Component::Location::ChromosomeImage;

### Module to replace part of the former MapView, in this case displaying 
### an overview image of an individual chromosome 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use Data::Dumper;
use Image::Size;


sub bacterial_chromosome {
  my $self         = shift;
  my $object       = $self->object;
  my $species_defs = $self->hub->species_defs;

  return '' unless $object && $object->seq_region_name;

  my $slice = $object->database('core')->get_SliceAdaptor->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );

  my $species      = $object->species;
  my $display_name = $species_defs->species_display_label($species);
  my $chr_name     = $object->seq_region_name;
  my $img          = 'region_'.$species.'_'.$chr_name.'.png';
  my $region_name  = $object->seq_region_name;
  

  # get the image size
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
  
  my $cr = $slice->is_circular || 0;

  return '<input class="panel_type" type="hidden" value="IdeogramPanel" />
          <span class="labelImg" style="display:block;margin:auto;width:400px;text-align:center;font-size:10px;">                                                          
          '.$display_name.'<br>'.$region_name.'                                                                                                                                                              
          <div style="width:'.$width.'px;height:'.$height.'px;margin: 0px auto 10px auto;">
<img class="circularImage" height="'.$height.'" width="'.$width.'" alt="Click and drag the handles to select a region" id="'.$region_name.'~'.$object->seq_region_length.'~'.$cr.'~0" src="/img/species/'.$img.'" border="0"></div>                                                                                   
            <div class="labelDiv" style="visibility: hidden; font-size: 10px; padding-bottom: 4px;">Drag the handles to select a region and click on selected region to update location</div>                     
          </span>                                                                                                                                                                                                 
  ';

  #return $image->render;
}


sub content {
  my $self = shift;

## All bacteria region images are static
  my $chr_form    = $self->chromosome_form('Vsynteny');
  my $image_html = $self->bacterial_chromosome;

  my $chr_selector =  $self->chromosome_form('Vmapview')->render;
  $chr_selector =~ s/\/Location\"/\/Location\/Chromosome\"/;
  my $html = sprintf('
  <div class="chromosome_image">
    %s
  </div>
  <div class="chromosome_stats">
    %s
    <h3>Chromosome Statistics</h3>
    %s
  </div>',
  $image_html,  $chr_selector, $self->stats_table->render);

  return $html;
}


1;
