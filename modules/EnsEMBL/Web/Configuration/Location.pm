package EnsEMBL::Web::Configuration::Location;

use strict;
use warnings;

sub modify_tree {
  my $self = shift;
  $self->delete_node('Marker');
  $self->delete_node('Synteny');
  $self->delete_node('Compara');
  $self->delete_node('Variation');
}

1;

