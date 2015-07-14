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

package EnsEMBL::Web::Document::HTML::FTPtable;

### This module outputs a table of links to the FTP site

use strict;
use warnings;

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use base qw(EnsEMBL::Web::Document::HTML);
use EnsEMBL::Web::Document::Table;

sub render {
  my $self = shift;
  my $hub             = new EnsEMBL::Web::Hub;
  my $species_defs    = $hub->species_defs;
  my $rel = $species_defs->SITE_RELEASE_VERSION;
  my ($columns, $rows);

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
  
  $columns = [
    { key => 'species', title => 'Species',                      align => 'left',   width => '20%', sort => 'html' },
    { key => 'dna',     title => 'DNA (FASTA)',                  align => 'center', width => '10%', sort => 'none' },
    { key => 'cdna',    title => 'cDNA (FASTA)',                 align => 'center', width => '10%', sort => 'none' },
    { key => 'protseq', title => 'Protein sequence (FASTA)',     align => 'center', width => '10%', sort => 'none' },
    { key => 'embl',    title => 'Annotated sequence (EMBL)',    align => 'center', width => '10%', sort => 'none' },
    { key => 'mysql',   title => 'Whole databases',              align => 'center', width => '10%', sort => 'none' },
    { key => 'gtf',   title => 'GTF',                            align => 'center', width => '10%', sort => 'none' },
    { key => 'vep',    title => 'Variation (VEP)',               align => 'center', width => '10%', sort => 'none' },
    { key => 'tsv',     title => 'TSV',                          align => 'center', width => '10%', sort => 'none' },
  ];



  my @species = $species_defs->valid_species;

foreach my $spp (sort @species) {
   (my $sp_name = $spp) =~ s/_/ /;

   my $sp_dir             = lc($spp);
   my $sp_var             = lc($spp) . '_variation';
   my $sp_vep             = lc($spp) . "_vep_$rel.tar.gz";
   my $common             = $species_defs->get_config($spp, 'SPECIES_COMMON_NAME');
   my $genomic_unit       = $species_defs->get_config($spp, 'GENOMIC_UNIT');
   my $collection         = lc ($species_defs->get_config($spp, 'SPECIES_DATASET') . '_collection' );
   my $ftp_base_path_stub = "ftp://ftp.ensemblgenomes.org/pub/release-$rel/$genomic_unit/";
   my $db_name            = $species_defs->get_config($spp, 'databases')->{DATABASE_CORE}->{NAME};
   my $assembly           = $species_defs->get_config($spp, 'ASSEMBLY_NAME');
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


    push @$rows, {
      species => sprintf('<strong><i>%s</i></strong>', $common),
      dna     => sprintf('<a rel="external" href="%s/fasta/%s/%s/dna/">FASTA</a>',  $ftp_base_path_stub, $collection, $sp_dir),
      cdna    => sprintf('<a rel="external" href="%s/fasta/%s/%s/cdna/">FASTA</a>',  $ftp_base_path_stub, $collection, $sp_dir),
      protseq => sprintf('<a rel="external" href="%s/fasta/%s/%s/pep/">FASTA</a>',  $ftp_base_path_stub, $collection, $sp_dir),
      embl    => sprintf('%s',  $embl_link),
      mysql   => sprintf('<a rel="external" href="%s/mysql/%s">MySQL</a>',  $ftp_base_path_stub, $db_name),
      gtf    =>  sprintf('<a rel="external" href="%s/gtf/%s/%s/">GTF</a>',  $ftp_base_path_stub, $collection, $sp_dir),
      vep    =>  sprintf('<a rel="external" href="%s/vep/%s/%s/">VEP</a>',  $ftp_base_path_stub, $collection, $sp_vep),
      tsv    =>  sprintf('<a rel="external" href="%s/tsv/%s/%s/">TSV</a>',  $ftp_base_path_stub, $collection, $sp_dir),
    };
 }


my $main_table           = EnsEMBL::Web::Document::Table->new($columns, $rows, { data_table => 1, exportable => 0 });
  $main_table->code        = 'FTPtable::'.scalar(@$rows);
  $main_table->{'options'}{'data_table_config'} = {iDisplayLength => 10};

my $pantaxonomic_data = qq{<h2>Pantaxonomic compara multi-species</h2>
    <p>
      Pantaxonomic compara multi-species data on the genomes provided by Ensembl Genomes is available from the FTP site in the following formats.
    </p>
    <p>
      Ensembl Genomes:
      <a href="ftp://ftp.ensemblgenomes.org/pub/pan_ensembl/release-$rel/mysql/">MySQL</a> |
      <a href="ftp://ftp.ensemblgenomes.org/pub/pan_ensembl/release-$rel/tsv/">TSV</a> |
    </p>};



 # $class = $class eq 'bg2' ? 'bg1' : 'bg2';

 # $html .= qq(
 # <tr class="$class">
 #   <td><strong>Pantaxonomic compara multi-species</strong></td>
 #   <td>-</td>
 #   <td>-</td>
 #   <td>-</td>
 #   <td>-</td>
 #   <td><a rel="external" href="ftp://ftp.ensemblgenomes.org/pub/pan_ensembl/release-$rel/mysql/">MySQL</a></td>
 #   <td>-</td>
 #   <td>-</td>
 #   <td><a rel="external" href="ftp://ftp.ensemblgenomes.org/pub/pan_ensembl/release-$rel/tsv/">TSV</a></td>
 # </tr>
 #</table>
 # );

 # return $html;

return sprintf(qq{<div class="js_panel">
      <input type="hidden" class="panel_type" value="Content">
      %s
    </div>%s},$main_table->render, $pantaxonomic_data);
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
