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

package EnsEMBL::Web::Component::Location::Genome;

### Module to replace Karyoview

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
use Data::Dumper;
use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::RegObj;
use Image::Size;
use JSON;

sub feature_tables {
  my $self = shift;
  my $feature_dets = shift;
  my $hub          = $self->hub;
  #my $data_type = $object->param('ftype');
  my $data_type    = $hub->param('ftype');
  my $html;
  my @tables;

  my $spath = $hub->species_defs->species_path($hub->species);

  foreach my $feature_set (@{$feature_dets}) {
    my $features      = $feature_set->[0];
    my $extra_columns = $feature_set->[1];
    my $feat_type     = $feature_set->[2];

##
    # could show only gene links for xrefs, but probably not what is wanted:
    # next SET if ($feat_type eq 'Gene' && $data_type =~ /Xref/);
##
    my $data_type = ($feat_type eq 'Gene') ? 'Gene Information:'
      : ($feat_type eq 'Transcript') ? 'Transcript Information:'
      : 'Feature Information:';

    my $table = new EnsEMBL::Web::Document::Table( [], [], {'margin' => '1em 0px'} );
    if ($feat_type =~ /Gene|Transcript/) {
      $table->add_columns({'key'=>'names',  'title'=>'Ensembl ID',      'width'=>'25%','align'=>'left' });
      $table->add_columns({'key'=>'extname','title'=>'External names',  'width'=>'25%','align'=>'left' });
    }
    else {
      $table->add_columns({'key'=>'loc',   'title'=>'Genomic location','width' =>'15%','align'=>'left' });
      $table->add_columns({'key'=>'length','title'=>'Genomic length',  'width'=>'10%','align'=>'left' });
      $table->add_columns({'key'=>'names', 'title'=>'Names(s)',        'width'=>'25%','align'=>'left' });
    }
  
    my $c = 1;
    for( @{$extra_columns||[]} ) {
      $table->add_columns({'key'=>$_->{'key'}, 'title'=>$_->{'title'}, 'sort'=>$_->{'sort'}, 'width'=>'10%', 'align'=>'left' });
      $c++;
    }
  
    my @data = map { $_->[0] }
      sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
      map { [$_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20 , $_->{'region'}, $_->{'start'}] }
      @{$features};
      
    foreach my $row ( @data ) {

      my $contig_link = 'Unmapped';
      my $names = '';
      my $data_row;

      if ($row->{'region'}) {
	     $contig_link = $self->_location_link($row);
             if ($feat_type =~ /Gene|Transcript/ && $row->{'label'}) {
              my $t = $feat_type eq 'Gene' ? 'g' : 't';
              $names = $self->_names_link($row, $feat_type);
              my $extname = $row->{'extname'};
       #      my $desc =  $row->{'extra'}[0];

              $data_row = { 'extname' => $extname, 'names' => $names};
	    }
            else {
              if ($feat_type && $feat_type !~ /Xref|align|RegulatoryFactor|ProbeFeature/i && $row->{'label'}) {
                $names = sprintf('<a href="%s/Gene/Summary?g=%s;r=%s:%d-%d">%s</a>',
                $spath, $row->{'label'},
                $row->{'region'}, $row->{'start'}, $row->{'end'},
                $row->{'label'});
                $names = $self->_names_link($row, $feat_type);
	      }
              else {
                $names  = $row->{'label'} if $row->{'label'};
              }
              my $length = $row->{'length'};
              $data_row = { 'loc'  => $contig_link, 'length' => $length, 'names' => $names, };
	    }
      }

      for(keys %{$row->{'extra'}}) {
        if($_ =~ /description/ && $row->{'extra'}->{"$_"} =~ /\[Source:(.*);Acc:(.*)\]/){
	  my ($edb, $acc) = ($1, $2);
	  my $l1   =  $hub->get_ExtURL($edb, $acc);
	  $l1      =~ s/\&amp\;/\&/g;
	  my $t1   = "source: $edb $acc";
	  my $link = $l1 ? qq(<a href="$l1">$t1</a>) : $t1;
	  my $desc =  qq( <span class="small">@{[ $link ]}</span>) if $acc && $acc ne 'content';        
	  ($data_row->{"$_"} = $row->{'extra'}->{"$_"}) =~ s/\[(.*)\]/ $desc /eg;
        } else {
	  $data_row->{"$_"} = $row->{'extra'}->{"$_"};
	}
      }
      my $c = 0;
      for( @{$row->{'initial'}||[]} ) {
        $data_row->{"initial$c"} = $_;
        $c++;
      }
      $table->add_row($data_row);
    }
    if (@data) {
      $html .= qq(<strong>$data_type</strong>);
      $html .= $table->render;
    }
  }
  if (! $html) {
    my $id = $hub->param('id');
    $html .= qq(<br /><br />No mapping of $id found<br /><br />);
  }
  return $html;
}

sub content {
 
  my $self = shift;
  my $hub     = $self->hub;
  my $species = $hub->species;
  my $html;

  if (my $id = $hub->param('id') || $hub->referer->{'ENSEMBL_TYPE'} eq 'LRG') { ## "FeatureView"

    my $data_type = $hub->param('ftype');  
    my $features = $self->builder->create_objects('Feature', 'lazy')->convert_to_drawing_parameters;  

    my @all_features;
    my  $has_features = 0;
    while (my ($type, $feature_set) = each (%$features)) {
      push @$feature_set, $type if ($feature_set && @$feature_set);  
      push(@all_features, $feature_set) if ($feature_set && @$feature_set);
      $has_features = 1  if ($feature_set && @$feature_set);
    }

    my $feature_display_name = {
      'Xref'                => 'External Reference',
      'ProbeFeature'        => 'Oligoprobe',
      'DnaAlignFeature'     => 'Sequence Feature',
      'ProteinAlignFeature' => 'Protein Feature',
    };
    my ($xref_type, $xref_name);
    while (my ($type, $feature_set) = each (%$features)) {    
      if ($type eq 'Xref') {
        my $sample = $feature_set->[0][0];
        $xref_type = $sample->{'label'};
        $xref_name = $sample->{'extname'};
        $xref_name =~ s/ \[#\]//;
        $xref_name =~ s/^ //;
      }
    }

    if ($has_features) { 
      unless ($hub->param('ph')) { ## omit h3 header for phenotypes
        my $title = 'Locations';
        $title .= ' of ';
        my ($data_type, $assoc_name);
        my $ftype = $hub->param('ftype');
        if (grep (/$ftype/, keys %$features)) {
          $data_type = $ftype;
        }
        else {
          my @A = sort keys %$features;
          $data_type = $A[0];
          $assoc_name = $hub->param('name');
          unless ($assoc_name) {
            $assoc_name = $xref_type.' ';
            $assoc_name .= $id;
            $assoc_name .= " ($xref_name)" if $xref_name;
          }
        }

        my %names;
        ## De-camelcase names
        foreach (sort keys %$features) {
          my $pretty = $feature_display_name->{$_} || $self->decamel($_);
          $pretty .= 's';
          $names{$_} = $pretty;
        }

        my @feat_names = sort values %names;
        my $last_name = pop(@feat_names);
        if (scalar @feat_names > 0) {
          $title .= join ', ', @feat_names;
          $title .= ' and ';
        }
        $title .= $last_name;
        $title .= " associated with $assoc_name" if $assoc_name;
        $html .= "<h3>$title</h3>" if $title;  
      }
    }
   
    $html .= $self->feature_karyotypes(\@all_features, $data_type);
    $html .= $self->feature_tables(\@all_features);
  
  } else {
   
      if (@{$hub->species_defs->ENSEMBL_CHROMOSOMES}) {
        $html .= $self->chromosomes_structure();
      } else {
        $html .= $self->_info('Unassembled genome', '<p>This genome has yet to be assembled into chromosomes</p>');
      }
      
      my $sfile = sprintf("/ssi/species/stats_%s.html", $species);
      $html .=  EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $sfile);
  }

  return $html;
}

sub chromosomes_structure {
    my $self = shift;
    my $hub  = $self->hub;      
    my @chrs = @{$hub->species_defs->ENSEMBL_CHROMOSOMES};
   
    return unless @chrs;
    
    my $species    = $hub->species;
    my $htdocs_dir = {@{$SiteDefs::ENSEMBL_PLUGINS}}->{'EG::Bacteria'} . '/htdocs';
    my $sa         = $hub->database('core', $species)->get_SliceAdaptor;
    my %slices     = map {$_->seq_region_name => $_} @{$sa->fetch_all('toplevel') || []};
    my $html;
        
    $html .= qq{
      <p>Drag the handles to select a region and click on selected region to update location</p>
      <div class="karyograph">
    };

    my $elem = 'Chromosome';
    if( (grep {$_ eq $elem} @chrs) && ($chrs[0] ne $elem) ) {
        my $jj = 0 ;   
        my %index_chr = map {$_ => $jj++ } @chrs;    
        my $tmp_holder = $chrs[0];
        $chrs[0] = $chrs[$index_chr{$elem}];
        $chrs[$index_chr{$elem}] = $tmp_holder;
    }  
    
    my $i = 1;
    foreach my $ch (@chrs) {
      my $ln    = $slices{$ch}->length;
      my $cr    = $slices{$ch}->is_circular || 0;
      my $image = "/img/species/region_${species}_${ch}.png";
       
      my ($width, $height) = imgsize("$htdocs_dir/$image");

      if ((!$width and !$height) or ($width > 220 and $height > 220)) {
        $width = 220;
        $height = 220;
      } elsif ($width < 100) {
        $width = $width + 1 / 2 * $width;
        $height = $height + 1 / 2 * $height;
      }
       
       # the IE7 css hack 'zoom:1; *display:inline' forces the div into behaving the same as 'display: inline-block' in other browsers
       $html .= qq{ 
         <input class="panel_type" type="hidden" value="IdeogramPanel" />            
         <div style="margin: 3px 30px 20px 3px; display: inline-block; vertical-align: top; zoom:1; *display:inline">
           <p style="margin-bottom:5px"><b>$ch</b></p>
           <img src="$image"  class="circularImage" id="${ch}~${ln}~${cr}~${i}"  alt="Karyograph selector"/>
         </div>
       };
       $i++;
    }

    $html .= qq{
        <table>
          <tr><td><b>Legend:</b></td></tr>
          <tr><td><img src="/img/chromosome_legend.png" alt="Image Legend"/></td></tr>
        </table>
      </div>
    };
    
    return $html;
}

sub feature_karyotypes {
    my ($self, $feature_dets, $data_type) = @_;
    my $hub          = $self->hub;
    my $object       = $self->object;
    my $species      = $hub->species;
    my $species_defs = $hub->species_defs;    
    my $species_path = $species_defs->species_path($species);
    my $htdocs_dir   = {@{$SiteDefs::ENSEMBL_PLUGINS}}->{'EG::Bacteria'} . '/htdocs';
    my $html;
    
    my $link_template2 = "$species_path/Location/View?r=%s:%s-%s";    
    my $link_template =  "$species_path/Location/View?%s=%s;r=%s:%s-%s";
    
    # pick out the features, and create a hash keyed on region 
    # which contains an array of feature start locations for each region
    my %region_features;
    foreach my $feature_set (@{$feature_dets}) {
      next if (($feature_set->[2] =~ /^(gene|transcript)$/i) && ($data_type ne 'Domain'));
      my $t = $feature_set->[2] eq 'transcript' ? 't' : 'g';

      foreach my $feature (@{$feature_set->[0]}) {
        if (my $region = $feature->{region}) {
          $region_features{$region}{start} ||= [];
          $region_features{$region}{label} ||= [];
          $region_features{$region}{t}     ||= [];
          push(@{$region_features{$region}{start}}, $feature->{start});
          push(@{$region_features{$region}{label}}, $feature->{label});
          push(@{$region_features{$region}{t}}, $t);
        }
      }
    }
    
    if (%region_features) {
      
      my @reg_features = keys %region_features;
      
      my $has_images;
      foreach my $region (@reg_features) {
        $has_images ++ if -e "$htdocs_dir/img/species/region_${species}_${region}.png";
      }
      return unless $has_images;
      
      # build a look-up for region slice objects
      my $sa     = $hub->database('core', $species)->get_SliceAdaptor;
      my %slices = map {$_->seq_region_name => $_} @{$sa->fetch_all('toplevel') || []};

      # add the region karyotype images
      $html .= qq{
        <p>Drag the handles to select a region and click on selected region to update location</p>
        <div class="karyograph">
      };

      my $elem = 'Chromosome';
      
      if( (grep {$_ eq $elem} @reg_features) && ($reg_features[0] ne $elem) ) {
        my $jj = 0 ;
        my %index_chr = map {$_ => $jj++ } @reg_features;
        my $tmp_holder = $reg_features[0];
        $reg_features[0] = $reg_features[$index_chr{$elem}];
        $reg_features[$index_chr{$elem}] = $tmp_holder;
      }

      my $i = 1;
      foreach my $region (@reg_features) {
        # the IE7 css hack 'zoom:1; *display:inline' forces the div into behaving the same as 'display: inline-block' in other browsers
        $html .= qq{
          <div style="margin: 3px 30px 20px 3px; display: inline-block; vertical-align: top; zoom:1; *display:inline">
            <p style="margin-bottom:5px"><b>$region</b></p>
        };

        my $ln    = $slices{$region}->length;
        my $cr    = $slices{$region}->is_circular || 0;
        my $feats = join(',', @{$region_features{$region}{start}}); 
        my $links = '';
        
        if($data_type eq 'Domain') {
          my @links_arr;
          for (my $jj = 0 ; $jj< @{$region_features{$region}{start}}; $jj++) {
            $links_arr[$jj] = sprintf($link_template, $region_features{$region}{t}->[$jj], $region_features{$region}{label}->[$jj], $region, $region_features{$region}{start}->[$jj] - 1000, $region_features{$region}{start}->[$jj] + 1000);
          }
          $links = join(',', @links_arr);
        } else {
          $links = join(',', map {sprintf($link_template2, $region, $_ - 1000, $_ + 1000) } @{$region_features{$region}{start}});
        }

        $html .= qq{
            <input class="panel_type" type="hidden" value="IdeogramPanel" />
            <img id="${region}~${ln}~${cr}~${i}~${feats}~${links}" class="circularImage" src="/img/species/region_${species}_${region}.png" alt="Karyograph selector" />
          </div>
        };

        $i++;
      }   
      $html .= '</div>';          
   }
   
    #warn $html;
    return $html;
} 



1;
