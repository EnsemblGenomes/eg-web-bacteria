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

# $Id: Tabs.pm,v 1.9 2012-12-19 15:31:51 nl2 Exp $

package EnsEMBL::Web::Document::Element::Tabs;

use previous qw(init);

## Bacteria
sub init {
  my $self = shift;

  $self->PREV::init(@_);

  if (my ($info_tab) = grep {($_->{'type'} || '') eq 'Info'} @{$self->entries}) {
    $info_tab->{'caption'} =~ s/\(\)//; # remove empty assembly name parens
  }
}

sub init_species_list {
  $self->{'species_list'} = [];
}
##

1;
