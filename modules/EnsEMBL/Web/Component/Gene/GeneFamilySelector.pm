package EnsEMBL::Web::Component::Gene::GeneFamilySelector;

use strict;
use warnings;
no warnings 'uninitialized';
use base qw(EnsEMBL::Web::Component::TaxonSelector);

sub _init {
  my $self = shift;
  my $hub = $self->hub;
  my $gene_family_id = $hub->param('gene_family_id');
  
  $self->SUPER::_init;
  
  $self->{action}          = $hub->species_path($hub->data_species) . '/Gene/Gene_families/SaveFilter'; 
  $self->{method}          = 'post';
  $self->{extra_params}    = { gene_family_id => $gene_family_id };  
  $self->{link_text}       = 'Filter gene family';
  $self->{data_url}        = sprintf '/%s/Ajax/gene_family_dynatree_js?gene_family_id=%s', $hub->species, $gene_family_id;
  $self->{entry_node}      = $hub->data_species;
  $self->{redirect}        = $hub->url({ function => 'Gene_families', gene_family_id => $gene_family_id }, 0, 1); 
}

1;

