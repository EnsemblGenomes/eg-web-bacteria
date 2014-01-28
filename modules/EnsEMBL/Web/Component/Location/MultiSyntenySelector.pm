package EnsEMBL::Web::Component::Location::MultiSyntenySelector;

### Module to replace part of the former SyntenyView, in this case 
### the lefthand menu dropdown of syntenous species

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::MultiSelector);



sub _init {
  my $self = shift;
  
  $self->SUPER::_init;

  $self->{'link_text'}       = 'Select species';
  $self->{'included_header'} = 'Selected species';
  $self->{'excluded_header'} = 'Unselected species';
  $self->{'panel_type'}      = 'MultiSyntenySelector';
  $self->{'url_param'}       = 's';
}

sub content_ajax {
  my $self            = shift;
  my $hub          = $self->hub;
  my $params          = $hub->multi_params; 

  my $primary_species = $hub->species;

  my %shown           = map { $hub->param("s$_") => $_ } grep s/^s(\d+)$/$1/, $hub->param; # get species (and parameters) already shown on the page
  my %species;


  my %synteny_hash = $hub->species_defs->multi('DATABASE_COMPARA', 'SYNTENY');
  my %synteny      = %{$synteny_hash{ $hub->species || {} }};
  
  foreach my $i ( keys %synteny) {
      $species{$i} = $hub->species_defs->species_label($i, 1);
  }
  
  $self->{'all_options'}      = \%species;
  $self->{'included_options'} = \%shown;
  
  $self->SUPER::content_ajax;
}

sub jsonify {
  my ($self, $params) = @_;
  
  $params->{'nav'} = qq{
    <div class="multi_selector_hint">
      <h4>Tip</h4>
      <p>Click on the plus and minus buttons to select or deselect options.</p>
      <p>Selected options can be reordered by dragging them to a different position in the list.</p>
      <p>You can select up to 7 species.</p>
    </div>
  };
  
  return $self->SUPER::jsonify($params);
}


1;

