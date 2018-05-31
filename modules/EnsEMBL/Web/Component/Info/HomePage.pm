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

# $Id: HomePage.pm,v 1.69 2014-01-17 16:02:23 jk10 Exp $

package EnsEMBL::Web::Component::Info::HomePage;

use strict;

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $species      = $hub->species;
  my $img_url      = $self->img_url;
  my $common_name  = $species_defs->SPECIES_COMMON_NAME;
  my $display_name = $species_defs->SPECIES_SCIENTIFIC_NAME;
  my $taxid        = $species_defs->TAXONOMY_ID;
  my $sound        = $species_defs->SAMPLE_DATA->{'ENSEMBL_SOUND'};
  my $provider_link;

  if ($species_defs->PROVIDER_NAME && ref $species_defs->PROVIDER_NAME eq 'ARRAY') {
    my @providers;
    push @providers, map { $hub->make_link_tag(text => $species_defs->PROVIDER_NAME->[$_], url => $species_defs->PROVIDER_URL->[$_]) } 0 .. scalar @{$species_defs->PROVIDER_NAME} - 1;

    if (@providers) {
      $provider_link = join ', ', @providers;
      $provider_link .= ' | ';
    }
  }
  elsif ($species_defs->PROVIDER_NAME) {
    $provider_link = $hub->make_link_tag(text => $species_defs->PROVIDER_NAME, url => $species_defs->PROVIDER_URL) . " | ";
  }

  my $html = '
    <div class="column-wrapper">  
      <div class="box-left">
        <div class="species-badge">';

  $html .= qq(<img src="${img_url}species/64/$species.png" alt="" title="$sound" />) unless $self->is_bacteria;

  if ($common_name =~ /\./) {
    $html .= qq(<h1>$display_name</h1>);
  } else {
    $html .= qq(<h1>$common_name</h1><p>$display_name</p>);
  }

  $html .= '<p class="taxon-id">';
  $html .= 'Provider ' . $provider_link if $provider_link;
  $html .= sprintf q{Taxonomy ID %s}, $hub->get_ExtURL_link("$taxid", 'UNIPROT_TAXONOMY', $taxid) if $taxid;
  $html .= '</p>';
  $html .= '</div>'; #species-badge

  $html .= EnsEMBL::Web::Document::HTML::HomeSearch->new($hub)->render;

  $html .= '</div>'; #box-left
  $html .= '<div class="box-right">';
  
  if (my $ack_text = $self->_other_text('acknowledgement', $species)) {
    $html .= '<div class="plain-box round-box unbordered">' . $ack_text . '</div>';
  }

  $html .= '</div>'; # box-right
  $html .= '</div>'; # column-wrapper

  $html .= '<div class="column-wrapper"><div class="round-box tinted-box unbordered">'; 
  $html .= qq{<h2 id="about">About <em>$common_name</em></h2>};
  $html .= qq(<p><a href="/$species/Info/Annotation/#about" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />Information and statistics</a></p>);
  $html .= '</div></div>';

  my (@sections);
  

  push(@sections, $self->_assembly_text);
# $html .= '<div class="box-left"><div class="round-box tinted-box unbordered">' . $self->_assembly_text . '</div></div>';
  push(@sections, $self->_genebuild_text) if $species_defs->SAMPLE_DATA->{GENE_PARAM};
 #$html .= '<div class="box-right"><div class="round-box tinted-box unbordered">' . $self->_genebuild_text . '</div></div>' if $species_defs->SAMPLE_DATA->{GENE_PARAM};

# my @box_class = ('box-left', 'box-right');
# my $side = 0;
  
  if ($self->has_compara or $self->has_pan_compara) {
    push(@sections, $self->_compara_text);
 #  $html .= '<div class="' . $box_class[$side % 2] . '"><div class="round-box tinted-box unbordered">' . $self->_compara_text . '</div></div>';
 #  $side++;
  }

  push(@sections, $self->_variation_text);
 #$html .= '<div class="' . $box_class[$side % 2] . '"><div class="round-box tinted-box unbordered">' . $self->_variation_text . '</div></div>';
 #$side++;

  if ($hub->database('funcgen')) {
    push(@sections, $self->_funcgen_text);
  # $html .= '<div class="' . $box_class[$side % 2] . '"><div class="round-box tinted-box unbordered">' . $self->_funcgen_text . '</div></div>';
  # $side++;
  }

  my $other_text = $self->_other_text('other', $species);
  push(@sections, $other_text) if $other_text =~ /\w/;
 #$html .= '<div class="' . $box_class[$side % 2] . '"><div class="round-box tinted-box unbordered">' . $other_text . '</div></div>' if $other_text =~ /\w/;
  
  my @box_class = ('box-left', 'box-right');
  my $side = 0;
  for my $section (@sections){
    $html .= sprintf(qq{<div class="%s"><div class="round-box tinted-box unbordered">%s</div></div>}, $box_class[$side++ %2],$section);
  }
    

  my $ext_source_html = $self->external_sources;
  $html .= '<div class="column-wrapper"><div class="round-box tinted-box unbordered">' . $ext_source_html . '</div></div>' if $ext_source_html;

  return $html;
}


1;
