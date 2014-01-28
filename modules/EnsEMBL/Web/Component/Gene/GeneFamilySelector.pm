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

