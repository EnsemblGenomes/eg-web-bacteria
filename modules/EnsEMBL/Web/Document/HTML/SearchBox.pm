package EnsEMBL::Web::Document::HTML::SearchBox;

### Generates small search box (used in top left corner of pages)

use strict;
use warnings;

sub search_url {
  my $self   = shift;

  my $spath = $self->species_defs->species_path($ENV{'ENSEMBL_SPECIES'});
  return $ENV{'ENSEMBL_SPECIES'} ? "$spath/psychic" : '/common/psychic';
}

1;
