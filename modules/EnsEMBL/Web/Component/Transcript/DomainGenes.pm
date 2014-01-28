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

package EnsEMBL::Web::Component::Transcript::DomainGenes;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);



sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;
  return unless $object->param('domain');
  my $genes   = $object->get_domain_genes;
  return unless( @$genes );
  
  my $html;

  ## Karyotype showing genes associated with this domain (optional)
  my $gene_stable_id = $object->gene ? $object->gene->stable_id : 'xx';
### eb! commented out as the image is wrong
  if(0 && @{$object->species_defs->ENSEMBL_CHROMOSOMES} ) {
    $object->param('aggregate_colour', 'red'); ## Fake CGI param - easiest way to pass this parameter
    my $wuc   = $object->get_imageconfig( 'Vkaryotype' );
    my $image = $self->new_karyotype_image();
    $image->image_type = 'domain';
    $image->image_name = "$species-".$object->param('domain');
    $image->imagemap = 'yes';
    my %high = ( 'style' => 'arrow' );
    foreach my $gene (@$genes){
warn "HERE........................ $gene";
      my $stable_id = $gene->stable_id;
      my $chr       = $gene->seq_region_name;
      my $colour    = $gene_stable_id eq $stable_id ? 'red' : 'blue';
      my $point = {
        'start' => $gene->seq_region_start,
        'end'   => $gene->seq_region_end,
        'col'   => $colour,
        'href'  => $object->url("/$species/Gene/Summary?g=$stable_id"),
      };
      if(exists $high{$chr}) {
        push @{$high{$chr}}, $point;
      } else {
        $high{$chr} = [ $point ];
      }
    }
    $image->set_button('drag');
    $image->karyotype( $object, [\%high] );
    $html .= '<div style="margin-top:10px">'.$image->render.'</div>';
  }

  ## Now do table
  my $table = new EnsEMBL::Web::Document::Table( [], [], {'margin' => '1em 0px'} );

  $table->add_columns(
    { 'key' => 'id',   'title' => 'Gene',                  'width' => '30%', 'align' => 'center' },
    { 'key' => 'loc',  'title' => 'Genome Location',       'width' => '20%', 'align' => 'left' },
    { 'key' => 'desc', 'title' => 'Description(if known)', 'width' => '50%', 'align' => 'left' }
  );

  my $spath = $object->species_defs->species_path($species);

  foreach my $gene ( sort { $object->seq_region_sort( $a->seq_region_name, $b->seq_region_name ) ||
                            $a->seq_region_start <=> $b->seq_region_start } @$genes ) {
    my $row = {};
    my $xref_id;
    if ($gene->display_xref) {
	$xref_id = $gene->display_xref->display_id;
    }
    else { $xref_id = '-novel-';}
    $row->{'id'} = sprintf '<a href="%s/Gene/Summary?g=%s">%s</a><br />(%s)',
	$spath, $gene->stable_id, $gene->stable_id, $xref_id;

    my $readable_location = sprintf(
      '%s: %s-%s',
      $self->neat_sr_name($gene->slice->coord_system->name, $gene->slice->seq_region_name),
      $gene->start,
      $gene->end
    );

    $row->{'loc'}  = sprintf '<a href="%s/Location/View?g=%s">%s</a>',
                             $spath, $gene->stable_id, $readable_location;
    my %description_by_type = ( 'bacterial_contaminant' => "Probable bacterial contaminant" );
    $row->{'desc'} = $gene->description || $description_by_type{ $gene->biotype } || 'No description';
    $table->add_row( $row );
  }
  $html .= $table->render;

  return $html;
}

1;

