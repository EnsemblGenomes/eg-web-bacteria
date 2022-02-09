=head1 LICENSE

Copyright [2009-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::Summary;


sub transcript_table {
  my $self        = shift;
  my $hub         = $self->hub;
  my $action      = $hub->action;
  my $object      = $self->object;
  my ($operon) = $object->can('get_operons')?@{$object->get_operons}:(); 
  return $self->SUPER::transcript_table(@_) if $action ne "OperonSummary" || !$operon;
  my $species     = $hub->species;
  my $page_type   = ref($self) =~ /::gene\b/i ? 'gene' : 'transcript';
  

  # get OperonTranscripts from Operon
  # get all Genes from OperonTranscripts
  # tabulate the Genes: Name, Description, Location
  # tabulate the OperonTranscripts: Label/ID, Genes, Location

  my @optrans = @{$operon->get_all_OperonTranscripts};
  my %optgenes = (); # to include in the Operon details
  my %gene_link = ();
  my %genes_in_operon;
  foreach my $ots (@optrans){
    $optgenes{$ots->dbID}=[];
    my @_genes = $ots->strand>0?sort { $a->seq_region_start <=> $b->seq_region_start } @{$ots->get_all_Genes}:sort { $b->seq_region_start <=> $a->seq_region_start } @{$ots->get_all_Genes};
    foreach my $gene (@_genes){
      $genes_in_operon{$gene->stable_id}=$gene;
      push(@{$optgenes{$ots->dbID}},$gene->stable_id);
    }
  }
  my @sorted_genes = sort {$a->start <=> $b->start} values %genes_in_operon;
  my $gene_count = scalar @sorted_genes;
  my $html = "";
# it should be $operon->display_xref : Dan S to implement
#  my $xref_content = sprintf("%s",$operon->analysis->display_label);
  my $xref_content = '';

  foreach my $xref (@{$operon->get_all_DBEntries}){
    $xref_content .= $hub->get_ExtURL_link(
      sprintf(" %s:%s\n",$xref->db_display_name,$xref->primary_id),
      $xref->dbname,
      $xref->primary_id);
  }

  my $table_rows = [];
  foreach my $gene (@sorted_genes){
      my $gid=$gene->stable_id;
      $object->{'data'}{'_object'}=$gene;
      my $gene_link_data={g=>$gid,t=>undef};
      $gene_link{$gid} = sprintf("gene: <a href=%s>%s</a>",
        $hub->url({type=>'Gene',action=>'Summary',g=>$gid,t=>undef}),$gene->external_name);
    
      my $description = encode_entities($object->gene_description);
      $description    = '' if $description eq 'no description';
      
      if ($description) {
        my ($edb, $acc);
        
        if ($object->get_db eq 'vega') {
          $edb = 'vega';
          $acc = $object->obj->stable_id;
          $description .= sprintf ' <span class="small">%s</span>', $hub->get_ExtURL_link("source: $edb", $edb . '_' . lc $page_type, $acc);
        } else {
          $description =~ s/ec\s+([-*\d]+\.[-*\d]+\.[-*\d]+\.[-*\d]+)/$self->ec_url($1)/e;
          $description =~ s/\[\w+:([-\w\/\_]+)\;\w+:([\w\.]+)\]//g;
          ($edb, $acc) = ($1, $2);
    
          my $l1   =  $hub->get_ExtURL($edb, $acc);
          $l1      =~ s/\&amp\;/\&/g;
          my $t1   = "source: $edb $acc";
          my $link = $l1 ? qq(<a href="$l1">$t1</a>) : $t1;
          
          $description .= qq( <span class="small">@{[ $link ]}</span>) if $acc && $acc ne 'content';
        }
      }
      
      my $seq_region_name  = $object->seq_region_name;
      my $seq_region_start = $object->seq_region_start;
      my $seq_region_end   = $object->seq_region_end;
      
      my $url = $hub->url({
        type   => 'location',
        action => 'view',
        r      => "$seq_region_name:$seq_region_start-$seq_region_end"
      });
      
      my $location_html = sprintf(
        '<a href="%s">%s: %s-%s</a>',
        $url,
        $self->neat_sr_name($object->seq_region_type, $seq_region_name),
        $self->thousandify($seq_region_start),
        $self->thousandify($seq_region_end)
      );
      
      # alternative (vega) coordinates
      if ($object->get_db eq 'vega') {
        my $alt_assemblies  = $hub->species_defs->alternative_assemblies || [];
        my ($vega_assembly) = map { $_ =~ /vega/; $_ } @$alt_assemblies;
        
        # set dnadb to 'vega' so that the assembly mapping is retrieved from there
        my $reg        = 'bio::ensembl::registry';
        my $orig_group = $reg->get_dnaadaptor($species, 'vega')->group;
        
        $reg->add_DNAAdaptor($species, 'vega', $species, 'vega');
    
        my $alt_slices = $object->vega_projection($vega_assembly); # project feature slice onto Vega assembly
        
        # link to Vega if there is an ungapped mapping of whole gene
        if (scalar @$alt_slices == 1 && $alt_slices->[0]->length == $object->feature_length) {
          my $l   = $alt_slices->[0]->seq_region_name . ':' . $alt_slices->[0]->start . '-' . $alt_slices->[0]->end;
          my $url = $hub->ExtURL->get_url('VEGA_CONTIGVIEW', $l);
          
          $location_html .= ' [<span class="small">This corresponds to ';
          $location_html .= sprintf(
            '<a href="%s" target="external">%s-%s</a>',
            $url,
            $self->thousandify($alt_slices->[0]->start),
            $self->thousandify($alt_slices->[0]->end)
          );
          
          $location_html .= " in $vega_assembly coordinates</span>]";
        } else {
          $location_html .= sprintf qq{ [<span class="small">There is no ungapped mapping of this %s onto the $vega_assembly assembly</span>]}, lc $object->type_name;
        }
        
        $reg->add_DNAAdaptor($species, 'vega', $species, $orig_group); # set dnadb back to the original group
      }
      
      # Haplotype/PAR locations
      my $alt_locs = $object->get_alternative_locations;
      if (@$alt_locs) {
        $location_html .= '
          <p> This gene is mapped to the following HAP/PARs:</p>
          <ul>';
        foreach my $loc (@$alt_locs) {
          my ($altchr, $altstart, $altend, $altseqregion) = @$loc;
          $location_html .= sprintf('
            <li><a href="/%s/Location/View?l=%s:%s-%s">%s : %s-%s</a></li>', 
            $species, $altchr, $altstart, $altend, $altchr,
            $self->thousandify($altstart),
            $self->thousandify($altend)
          );
        }
        $location_html .= '
          </ul>';
      }
      push(@$table_rows, {
        label => {width => undef, value => $gene_link{$gid}},
        desc  => {width => undef, value => $description},
        loc   => {width => undef, value => $location_html}
      });

  }
  
  my $table = $self->new_table( 
    [
      { key=>'label', title=>'Feature',     align => 'left', width=>'20%' },
      { key=>'desc',  title=>'Description', align => 'left', width=>'20%' },
      { key=>'loc',   title=>'Location',    align => 'left', width=>'20%' }
    ],
    $table_rows,
    {
      data_table => 1,
      width => "600px", 
      toggleable => 1,
      sorting => [ 'chr asc' ], 
      exportable => 0, 
      id => "operongenes_table", 
      class => 'toggle_table' . ($hide ? ' hide' : ''), 
      summary => "Genes appearing in this operon, in any operon-transcript"  
    }
  );

  my $hide = $hub->get_cookie_value('toggle_operongenes_table') eq 'closed';
  my $info_table = $self->new_twocol;
  $info_table->add_row('Source', $xref_content);
  $info_table->add_row(
    sprintf('<a rel="operongenes_table" class="toggle set_cookie %s" href="#" title="Click to toggle the features table">Features</a>', $hide ? 'closed' : 'open'),
    sprintf('%d %s',scalar @sorted_genes, (@sorted_genes > 1) ? "genes" : "gene")
  );

  $html .= $info_table->render . $table->render;


# operon transcripts
  $table_rows=[];
  foreach my $ots (@optrans){
    my $label=$ots->display_label;
    my $description = join(", ", map {$gene_link{$_}} @{$optgenes{$ots->dbID}});
    my $seq_region_name  = $ots->seq_region_name;
    my $seq_region_start = $ots->seq_region_start;
    my $seq_region_end   = $ots->seq_region_end;
    my $url = $hub->url({
      type   => 'Location',
      action => 'View',
      r      => "$seq_region_name:$seq_region_start-$seq_region_end"
    });
    my $location_html = sprintf(
      '<a href="%s">%s: %s-%s</a>',
      $url,
      $seq_region_name,
      $self->thousandify($seq_region_start),
      $self->thousandify($seq_region_end)
    );
    push(@$table_rows, {
      label=>{width=>undef,value=>$label},desc=>{width=>undef,value=>$description},loc=>{width=>undef,value=>$location_html}});
    
  }
  $hide = $self->hub->get_cookie_value('toggle_operontranscripts_table');

  $table = $self->new_table( 
    [
      { key=>'label', title=>'Transcript',  align => 'left', width=>'20%' },
      { key=>'desc',  title=>'Features',    align => 'left', width=>'40%' },
      { key=>'loc',   title=>'Location',    align => 'left', width=>'40%' }
    ],
    $table_rows,
    {
      data_table => 1, 
      width => "600px", 
      toggleable => 1,
      sorting => [ 'chr asc' ], 
      exportable => 0, 
      id => "operontranscripts_table",
      class => 'toggle_table' . ($hide ? ' hide' : ''), 
      summary => "Transcripts of this operon" 
    }
  );
  
  $hide = $hub->get_cookie_value('toggle_operontranscripts_table') eq 'closed';
  $info_table = $self->new_twocol;
  $info_table->add_row(
    sprintf('<a rel="operontranscripts_table" class="toggle set_cookie %s" href="#" title="Click to toggle the features table">Transcripts</a>', $hide ? 'closed' : 'open'),
    sprintf('%d %s', scalar @optrans, (@optrans > 1) ? "transcripts" : "transcript")
  ); 
  

 $html .= $info_table->render . $table->render;
  
# end
  return qq{<div class="summary_panel">$html</div>};
  
}

1;

