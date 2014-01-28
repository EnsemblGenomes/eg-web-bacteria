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
