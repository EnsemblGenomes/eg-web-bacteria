# $Id $

package EnsEMBL::Web::ViewConfig::Gene::OperonImage;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->add_image_config('gene_summary');
}

1;
