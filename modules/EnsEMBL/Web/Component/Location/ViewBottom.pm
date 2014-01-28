package EnsEMBL::Web::Component::Location::ViewBottom;

use strict;
use warnings;
no warnings 'uninitialized';

use Time::HiRes qw(time);


sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $threshold   = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1);
  my $image_width = $self->image_width;
  my $info = '';
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;

  my $slice        = $object->slice;
## EG    
#  my $flank  = int($slice->length / 4);
#  $slice     = $slice->expand($flank, $flank);    
  my $length = $slice->length();
##
  
  my $image_config = $hub->get_imageconfig('contigviewbottom');
  
  $image_config->set_parameters({
    container_width => $length,
    image_width     => $image_width || 800, # hack at the moment
    slice_number    => '1|3'
  });

  ## Force display of individual low-weight markers on pages linked to from Location/Marker
  if (my $marker_id = $hub->param('m')) {
    $image_config->modify_configs(
      [ 'marker' ],
      { marker_id => $marker_id }
    );
  }
  
  # Add multicell configuration
  $image_config->{'data_by_cell_line'} = $self->new_object('Slice', $slice, $object->__data)->get_cell_line_data($image_config) if keys %{$hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'cell_type'}{'ids'}};
  $image_config->_update_missing($object);
  
  my $info  = $self->_add_object_track($image_config);
  my $image = $self->new_image($slice, $image_config, $object->highlights);
  
  return if $self->_export_image($image);
  
  $image->{'panel_number'} = 'bottom';
  $image->imagemap         = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  
  return $info . $image->render;
}

1;
