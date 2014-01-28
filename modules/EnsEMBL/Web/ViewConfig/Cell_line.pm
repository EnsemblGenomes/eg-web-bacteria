package EnsEMBL::Web::ViewConfig::Cell_line;

use strict;

## EG - reverting evidence_info change to previous revision - need to ask Simon about this

sub set_columns {
  my ($self, $image_config) = @_;
     $image_config   = ref $image_config ? $image_config : $self->hub->get_imageconfig($image_config);
  my $funcgen_tables = $self->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'};
## EG  
  #my $evidence_info  = $self->hub->get_adaptor('get_FeatureTypeAdaptor', 'funcgen')->get_regulatory_evidence_info;
## /EG  
  my $tree           = $image_config->tree;
  
  foreach (grep $_->data->{'set'}, map $_ ? $_->nodes : (), $tree->get_node('regulatory_features_core'), $tree->get_node('regulatory_features_non_core')) {
    my $set       = $_->data->{'set'};
    my $cell_line = $_->data->{'cell_line'};
    my $renderers = $_->get('renderers');
    my %renderers = @$renderers;
    my $conf      = $self->{'matrix_config'}{$_->data->{'menu_key'}}{$set} ||= {
      menu         => "regulatory_features_$set",
      track_prefix => 'reg_feats',
      section      => 'Regulation',
## EG      
      #caption      => $evidence_info->{$set}{'name'},
      #header       => $evidence_info->{$set}{'long_name'},
      caption      => $set eq 'core' ? 'Open chromatin & TFBS' : 'Histones & polymerases',
      header       => $set eq 'core' ? 'Open chromatin & Transcription Factor Binding Sites' : 'Histones & Polymerases',
## /EG      
      description  => $funcgen_tables->{'feature_set'}{'analyses'}{'Regulatory_Build'}{'desc'}{$set},
      axes         => { x => 'cell', y => 'evidence type' },
    };
    
    push @{$conf->{'columns'}}, { display => $_->get('display'), renderers => $renderers, x => $cell_line, name => $tree->clean_id(join '_', $conf->{'track_prefix'}, $set, $cell_line) };
    
    $conf->{'features'}{$cell_line} = $self->deepcopy($funcgen_tables->{'regbuild_string'}{'feature_type_ids'}{$cell_line});
    $conf->{'renderers'}{$_}++ for keys %renderers;
  }
  
  $self->SUPER::set_columns($image_config);
}

1;
