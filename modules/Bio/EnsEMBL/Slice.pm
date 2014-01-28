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
