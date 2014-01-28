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

package Bio::EnsEMBL::Slice;

sub get_all_Operons {
  my ($self,$logic_name) = @_;

  if(!$self->adaptor()) {
    warning('Cannot get Operons without attached adaptor');
    return [];
  }
  my $db = $self->adaptor->db;
  my $ofa = $db->get_OperonAdaptor();
  return $ofa->fetch_all_by_Slice($self,$logic_name);
}
1;
