package EnsEMBL::Web::Command::GeneFamily::SaveFilter;

use strict;

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Data::Session;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self           = shift;
  my $hub            = $self->hub;
  my $session        = $hub->session;
  my $redirect       = $hub->param('redirect') || $hub->species_path($hub->data_species);
  my $gene_family_id = $hub->param('gene_family_id');
  my @species        = $hub->param('s');
 

  my $data = {
    type   => 'genefamilyfilter', 
    code   => $hub->data_species . '_' . $gene_family_id,
    filter => join(',', @species),
  };

  $session->add_data(%$data);

  $self->hub->redirect($redirect);  
}

1;
