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

package EnsEMBL::Web::Configuration::Info;

sub modify_tree {
  my $self  = shift;

  $self->delete_node('WhatsNew');
  
  my $stats = $self->get_node('StatsTable');
  $stats->set('caption', 'Genome Information');
  
  # hack to make the karyo page work
  #my $karyo_node = $self->get_node('Karyotype');
  #$karyo_node->set('url', $karyo_node->get('url') . "?r=Chromosome");
}

1;
