package Bio::EnsEMBL::DBSQL::DBEntryAdaptor;


sub fetch_all_by_Operon {
  my ( $self, $gene, $ex_db_reg, $exdb_type ) = @_;

  if(!ref($gene) || !$gene->isa('Bio::EnsEMBL::Operon')) {
    throw("Bio::EnsEMBL::Operon argument expected.");
  }

  return $self->_fetch_by_object_type($gene->dbID(), 'Operon', $ex_db_reg, $exdb_type);
}

1;
