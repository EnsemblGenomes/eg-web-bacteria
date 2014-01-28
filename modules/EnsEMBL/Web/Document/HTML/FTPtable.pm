package EnsEMBL::Web::Document::HTML::FTPtable;

### This module outputs a table of links to the FTP site

use strict;
use warnings;

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $hub             = new EnsEMBL::Web::Hub;
  my $species_defs    = $hub->species_defs;
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
  
  my $html = qq(
<table class="ss tint" cellpadding="4">
  <tr>
    <th>Species</th>
    <th colspan="10" style="text-align:center">Files</th>
  </tr>
  );
  
  my @species = $species_defs->valid_species;
  my $row = 0;
  my $class;
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
    
    $class = $row % 2 == 0 ? 'bg1' : 'bg2';

    $html .= qq(
  <tr class="$class">
    <td><strong><i>$sp_name</i></strong> ($common)</td>
    <td><a rel="external" href="$ftp_base_path_stub/fasta/$collection/$sp_dir/dna/">FASTA</a> (DNA)</td>
    <td><a rel="external" href="$ftp_base_path_stub/fasta/$collection/$sp_dir/cdna/">FASTA</a> (cDNA)</td>
    <td><a rel="external" href="$ftp_base_path_stub/fasta/$collection/$sp_dir/pep/">FASTA</a> (protein)</td>
    <td>$embl_link</td>
    <td><a rel="external" href="$ftp_base_path_stub/mysql/$db_name">MySQL</a></td>
    <td><a rel="external" href="$ftp_base_path_stub/gtf/$collection/$sp_dir">GTF</a></td>
    <td><a rel="external" href="$ftp_base_path_stub/vep/$collection/$sp_vep">VEP</a></td>
    <td><a rel="external" href="$ftp_base_path_stub/tsv/$collection/$sp_dir">TSV</a></td>
  </tr>
      );
    $row++;
  }

  $class = $class eq 'bg2' ? 'bg1' : 'bg2';

  $html .= qq(
  <tr class="$class">
    <td><strong>Pantaxonomic compara multi-species</strong></td>
    <td>-</td>
    <td>-</td>
    <td>-</td>
    <td>-</td>
    <td><a rel="external" href="ftp://ftp.ensemblgenomes.org/pub/pan_ensembl/release-$rel/mysql/">MySQL</a></td>
    <td>-</td>
    <td>-</td>
    <td><a rel="external" href="ftp://ftp.ensemblgenomes.org/pub/pan_ensembl/release-$rel/tsv/">TSV</a></td>
  </tr>
</table>
  );

  return $html;
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
