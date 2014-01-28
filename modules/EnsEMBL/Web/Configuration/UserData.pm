package EnsEMBL::Web::Configuration::UserData;

use strict;
use warnings;

sub modify_tree {
  my $self = shift;

  $self->delete_node('SelectFeatures');
  #$self->delete_node('UploadStableIDs');
}

1;
