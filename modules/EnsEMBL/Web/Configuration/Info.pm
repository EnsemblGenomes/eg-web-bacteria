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
