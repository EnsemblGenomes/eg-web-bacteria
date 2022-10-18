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

package EnsEMBL::Web::Controller::Ajax;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use Storable qw(lock_retrieve lock_nstore);
use JSON qw(from_json to_json);
use Data::Dumper;
use Storable qw(lock_retrieve lock_nstore);

sub ajax_species_list {
  my ($self, $hub) = @_;
  my $species_defs = $hub->species_defs;
  my $cache_file   = $species_defs->ENSEMBL_TMP_DIR . '/species_index.packed';
  my $rows;

  if (-f $cache_file) {

    $rows = lock_retrieve($cache_file);

  } else {
    my $pan_compara  = $species_defs->get_config('MULTI', 'PAN_COMPARA_LOOKUP') || {};
      
    foreach my $species (sort $species_defs->valid_species) {
      my $prod_name      = $species_defs->get_config($species, 'SPECIES_PRODUCTION_NAME');
      my $alias          = $species_defs->get_config($species, 'SPECIES_ALIAS');
      my $tax_id         = $species_defs->get_config($species, 'TAXONOMY_ID');
      my $assembly_name  = $species_defs->get_config($species, 'ASSEMBLY_NAME');
      my $serotype       = $species_defs->get_config($species, 'SEROTYPE');
      my $publications   = $species_defs->get_config($species, 'PUBLICATIONS');
      my $display_name   = $species_defs->species_display_label($species);
      my $in_pan_compara = $pan_compara->{$prod_name} ? 'Y' : 'N'; 
       
      push @$rows, [
        join (' ', ref $alias eq 'ARRAY' ? @$alias : ($alias)),
        qq{<a href="/$species/Info/Index/">$display_name</a>},
        qq{<a href="/$species/Info/Annotation/#assembly">$assembly_name</a>},
        qq{<a href="http://www.uniprot.org/taxonomy/$tax_id">$tax_id</a>},
        $serotype,
        join(' ', map { qq{<a href="http://europepmc.org/abstract/MED/$_">$_</a>} } @{ $publications || [] }),
        $in_pan_compara
      ];
    }
  
    lock_nstore($rows, $cache_file);
  }
 
  $self->print_datatable($hub, $rows);
}

sub ajax_ftp_list {
  my ($self, $hub) = @_;
  my $species_defs = $hub->species_defs;
  my $cache_file   = $species_defs->ENSEMBL_TMP_DIR . '/ftp_list.packed';
  my $rows = [];

  if (-f $cache_file) {

    $rows = lock_retrieve($cache_file);

  } else {
  
    my $rel = $species_defs->SITE_RELEASE_VERSION;    

    my $species_ena = {};
    eval { # wrap in eval in case there is no species_search table
      my $dbh = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($self->hub)->db;
      my $sth = $dbh->prepare("SELECT species, ena_records FROM species_search WHERE genomic_unit = 'bacteria'");
      $sth->execute;
      while (my ($sp, $ena) = $sth->fetchrow_array) {
        $species_ena->{$sp} = [split / /, $ena];
      }
    };
    warn "failed to get ENA records: $@" if $@; 

    my @species = $species_defs->valid_species;

    foreach my $spp (sort @species) {
      (my $sp_name = $spp) =~ s/_/ /;

      my $alias              = $species_defs->get_config($spp, 'SPECIES_ALIAS');
      my $sp_dir             = lc($spp);
      my $sp_var             = lc($spp) . '_variation';
      my $display_name       = $species_defs->get_config($spp, 'SPECIES_DISPLAY_NAME');
      my $genomic_unit       = $species_defs->get_config($spp, 'GENOMIC_UNIT');
      my $collection         = lc ($species_defs->get_config($spp, 'SPECIES_DATASET') . '_collection' );
      my $ftp_base_path_stub = "https://ftp.ensemblgenomes.ebi.ac.uk/pub/release-$rel/$genomic_unit/";
      my $db_name            = $species_defs->get_config($spp, 'databases')->{DATABASE_CORE}->{NAME};
      my $assembly           = $species_defs->get_config($spp, 'ASSEMBLY_NAME');      
      my $sp_vep             = lc($spp) . "_vep_$rel\_$assembly.tar.gz";
      my $embl_link;

      if (my @ranges = $self->_ena_ranges($species_ena->{$spp})) {
        if (@ranges == 1) {
          $embl_link = $self->_ena_link($ranges[0], $assembly, 'EMBL');
        } else {
          my @links = map { $self->_ena_link($_, $assembly) } @ranges;
          $embl_link = join '<br />', ('EMBL', @links);
        }
      } else {
        $embl_link = '-';
      }

      push @$rows, [
        join (' ', ref $alias eq 'ARRAY' ? @$alias : ($alias)),
        sprintf('<strong><i><a href="/%s">%s</a></i></strong>', $sp_dir, $display_name),
        sprintf('<a rel="external" href="%s/fasta/%s/%s/dna/">FASTA</a>',  $ftp_base_path_stub, $collection, $sp_dir),
        sprintf('<a rel="external" href="%s/fasta/%s/%s/cdna/">FASTA</a>',  $ftp_base_path_stub, $collection, $sp_dir),
        sprintf('<a rel="external" href="%s/fasta/%s/%s/pep/">FASTA</a>',  $ftp_base_path_stub, $collection, $sp_dir),
        sprintf('%s',  $embl_link),
        sprintf('<a rel="external" href="%s/mysql/%s">MySQL</a>',  $ftp_base_path_stub, $db_name),
        sprintf('<a rel="external" href="%s/gtf/%s/%s/">GTF</a>',  $ftp_base_path_stub, $collection, $sp_dir),
        sprintf('<a rel="external" href="%s/variation/vep/%s/%s">VEP</a>',  $ftp_base_path_stub, $collection, $sp_vep),
        sprintf('<a rel="external" href="%s/tsv/%s/%s/">TSV</a>',  $ftp_base_path_stub, $collection, $sp_dir),
      ];
    }

    lock_nstore($rows, $cache_file);
  }

  $self->print_datatable($hub, $rows);
}

sub print_datatable {
  my ($self, $hub, $rows) = @_;
  my $species_defs   = $hub->species_defs;
  my $pan_compara    = $species_defs->get_config('MULTI', 'DATABASE_COMPARA_PAN_ENSEMBL');
  my $r              = $hub->apache_handle;
  
  my @data           = @$rows;
  my $total          = @data;  
  
  my $display_start  = $hub->param('iDisplayStart');
  my $display_length = $hub->param('iDisplayLength');
  my $sort_cols      = $hub->param('iSortingCols');
  my $search         = $hub->param('sSearch');
  my $is_sorted      = $hub->param('iSortCol_0');
  my $echo           = $hub->param('sEcho');
  
  # filter (assume all cols are filterable)
    
  @data = grep { join(' ', @$_) =~ /\Q$search\E/i } @data if $search; 
  my $totalFiltered = @data;
  
  # sort 
  
  if ($is_sorted) {
    my $sort = sub {
      my ($a, $b) = @_;
      for my $i (0..$sort_cols) {
        my $col = $hub->param("iSortCol_$i");
        my $cmp = $hub->param("sSortDir_$i") eq 'asc' ? $a->[$col] cmp $b->[$col] : $b->[$col] cmp $a->[$col];
        return $cmp if $cmp;    
      }
      return 0;
    };
    @data = sort { $sort->($a, $b) } @data;
  }
  
  # limit
    
  if ( length($display_start) and $display_length ne '-1' ) {
    my $start = $display_start;
    my $end   = $start + $display_length;
       $end   = @data if $end > @data;
    @data = @data[$start..$end-1];
  }
  
  # return
  
  my $output = {
    sEcho => int($echo),
    iTotalRecords => $total,
    iTotalDisplayRecords => $totalFiltered,
    aaData => \@data,
  };
  
  my $json = to_json($output); 
  $r->content_type('application/json');
  print $json;
}

sub _ena_ranges {
  my ($self, $accessions) = @_;

  return () unless $accessions;
  # compact consecutive accessions into ranges
  
  my @ranges;
  my $start;
  my $end;
  
  foreach my $acc (sort @$accessions) {;
    my $curr = $self->_parse_ena_accession($acc);
    if ($start) {
      if ($curr->{prefix} eq $end->{prefix} and $curr->{num} == ($end->{num} + 1)) {
        # continue range
        $end = $curr;
      } else {
        # end of range
        push @ranges, $start->{acc} eq $end->{acc} ? $start->{acc} : "$start->{acc}-$end->{acc}";
        ($start, $end) = ($curr, $curr); # start new range
      }
    } else {
      # first one
      ($start, $end) = ($curr, $curr);
    }
  }
  push @ranges, $start->{acc} eq $end->{acc} ? $start->{acc} : "$start->{acc}-$end->{acc}";
   
  return @ranges;
}

sub _ena_link {
  my ($self, $range, $assembly, $text) = @_;
  
  $assembly =~ s/\./-/g; # ena website doesn't like the dot in filename
  $text ||= $range;
    
  my $url = "http://www.ebi.ac.uk/ena/data/view/$range&display=text&download&filename=$assembly.$range.txt"; 
  my $link = qq{<a rel="external" href="$url" style="white-space:nowrap">$text</a>};
  return $link; 
}


sub _parse_ena_accession {
  my ($self, $acc) = @_;
  ($acc) = split /\./, $acc;
  my ($prefix, $num) = $acc =~ /^(.*?)([0-9]+)$/;
  return {acc => $acc, prefix => $prefix, num => int($num)};
}

1;
