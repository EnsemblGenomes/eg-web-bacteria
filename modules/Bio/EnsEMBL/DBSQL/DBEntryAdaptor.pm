=head1 LICENSE

Copyright [2009-2022] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::DBSQL::DBEntryAdaptor;


sub fetch_all_by_Operon {
  my ( $self, $gene, $ex_db_reg, $exdb_type ) = @_;

  if(!ref($gene) || !$gene->isa('Bio::EnsEMBL::Operon')) {
    throw("Bio::EnsEMBL::Operon argument expected.");
  }

  return $self->_fetch_by_object_type($gene->dbID(), 'Operon', $ex_db_reg, $exdb_type);
}

1;
