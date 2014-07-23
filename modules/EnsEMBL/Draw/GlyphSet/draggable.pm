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

package EnsEMBL::Draw::GlyphSet::draggable;

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);
our $counter;

sub _colour_background {
  return 0;
}

sub _init {
  
  my $self = shift;
  
  my $container = $self->{'container'};
  my $strand = $self->strand;
  my $start  = $container->start;
  my $end    = $container->end;

  my $w = $end - $start + 1;
  if ($w < 0 && $container->is_circular) {
      $w += $container->seq_region_length;
  }

  my $glyph = $self->Rect({
    x      => 0,
    y      => 6,
    width  => $w,
    height => 0,
    color  => 'black'
    });

  $self->push($glyph);

  my $A = $strand > 0 ? 1 : 0;

  my $config  = $self->{'config'};

  my $splitfl = 0;
  if($config->{'_parameters'}->{'splitflag'}) {    
      $splitfl = $config->{'_parameters'}->{'splitflag'};
  } 
  my $slicelen = 0;
  if($config->{'_parameters'}->{'slicelen'}) {
      $slicelen = $config->{'_parameters'}->{'slicelen'};
  }
 
  my $href;  
  if($start>$end) {
      my $reg_end = $container->seq_region_length;

    $href = join('|',  
      '#drag', $self->get_parameter('slice_number'), $self->species,
      $container->seq_region_name, $start, $end, $container->strand, $reg_end, $self->scalex * ($reg_end - $start), $splitfl
    );
  } else {
    $href = join('|',
      '#drag', $self->get_parameter('slice_number'), $self->species,
      $container->seq_region_name, $start, $end, $container->strand, ($slicelen ? $slicelen : 0), 0, $splitfl
    );
  }
   
  my @common = (
    'y'     => $A,
    'style' => 'fill',
    'z'     => -10,
    'href'  => $href,
    'alt' => 'Click and drag to select a region',
    'class' => 'drag' . ($self->get_parameter('multi') ? ' multi' : $self->get_parameter('compara') ? ' align' : '')
  );
  
  $self->join_tag($glyph, 'draggable', { 'x' => $A, @common });
  $self->join_tag($glyph, 'draggable', { 'x' => 1 - $A, @common });
}

1;
