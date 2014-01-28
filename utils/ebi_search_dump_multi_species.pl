#!/usr/local/bin/perl
# Copyright [2009-2014] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Dump variation information to an XML file for indexing by the EBI's search engine.
#
# To copy files to the EBI so that they can be picked up:
# scp *.xml.gz glenn@puffin.ebi.ac.uk:xml/
#
# Email eb-eye@ebi.ac.uk after copying so the files can be indexed.
package ebi_search_dump;

use strict;
use DBI;
use Carp;
use Getopt::Long;
use IO::Zlib;
use HTML::Entities;

use Data::Dumper;
use Data::Dump qw(dump);

my (
  $host,    $user,        $pass,   $port,     $species, $ind, $clade,
  $release, $max_entries, $nogzip, $parallel, $dir,     $inifile, $genomic_unit
  );

my %rHash = map { $_ } @ARGV;
if ( $inifile = $rHash{'-inifile'} ) {
  my $icontent = `cat $inifile`;
  warn $icontent;
  eval $icontent;
}

GetOptions(
  "clade=s",       \$clade,
  "host=s",        \$host,        "port=i",    \$port,
  "user=s",        \$user,        "pass=s",    \$pass,
  "species=s",     \$species,     "release=s", \$release,
  "index=s",       \$ind,         "nogzip!",   \$nogzip,
  "max_entries=i", \$max_entries, "parallel",  \$parallel,
  "dir=s",         \$dir,         "help",      \&usage,
  "inifile=s",     \$inifile, "genomic_unit=s" , \$genomic_unit
  );

$clade   ||= 'ALL';
$species ||= 'ALL';
$ind     ||= 'ALL';
$dir     ||= ".";
$release ||= 'LATEST';
$port    ||= 3306;
usage() and exit unless ( $host && $port && $user && $genomic_unit);

my $entry_count;
my $global_start_time = time;
my $total             = 0;
my $FAMILY_DUMPED;

my $fh;
## HACK 1 - if the INDEX is set to all grab all dumper methods...
my @indexes = split ',', $ind;
@indexes = map { /dump(\w+)/ ? $1 : () } keys %ebi_search_dump::
  if $ind eq 'ALL';

#warn Dumper \@indexes;

#my $dbHash = get_databases();

my $dbHash = get_species_by_collection();

#warn Dumper $dbHash;

#warn Dumper $dbcHash;

foreach my $collection ( sort keys %$dbHash ) {
  unless ($clade eq 'ALL' || $collection =~/$clade/i) {
    warn "skip $collection\n";
    next;
  }

  #    warn "Co: $collection .. \n";
  #    next unless $collection =~ /^stre/i;
  my $collection_hash = $dbHash->{$collection};

  next unless ($collection_hash->{species_list});

  warn "\n***** Collection [$collection] *****\n\n";

  foreach my $index (@indexes) {
    my $function = "dump$index";
    no strict "refs";

    $species =~ s/_/ /g;
    if ($index ne 'Family') {
      &$function($collection, $collection_hash);
      print $function,"\n";
    } elsif ($index eq 'Family' && !$FAMILY_DUMPED) {
      warn "skipping Family for now";
      &dumpFamily($collection_hash);

    }

  }
}

print_time($global_start_time);
warn " Dumped $total entries ...\n";

# -------------------------------------------------------------------------------

sub text_month {

  my $m = shift;

  my @months = qw[JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC];

  return $months[$m];

}

# -------------------------------------------------------------------------------

sub print_time {

  my $start = shift;

  my $t = time - $start;
  my $s = $t % 60;
  $t = ( $t - $s ) / 60;
  my $m = $t % 60;
  $t = ( $t - $m ) / 60;
  my $h = $t % 60;

  print "Time taken: " . $h . "h " . $m . "m " . $s . "s\n";

}

#------------------------------------------------------------------------------------------------
sub usage {
  print <<EOF; exit(0);

Usage: perl $0 <options>

  -host         Database host to connect to. Defaults to ens-staging.
  -port         Database port to connect to. Defaults to 3306.
  -species      Species name. Defaults to ALL.
  -index        Index to create. Defaults to ALL.
  -release      Release of the database to dump. Defaults to 'latest'.
  -user         Database username. Defaults to ensro.
  -pass         Password for user.
  -dir          Directory to write output to. Defaults to /lustre/scratch1/ensembl/gp1/xml.
  -nogzip       Don't compress output as it's written.
  -help         This message.
  -inifile      First take the arguments from this file. Then overwrite with what is provided in the command line
  -genomic_unit 
EOF

}

sub get_species_by_collection {

  my $sql =
    qq{select meta.meta_value as species_name, coord_system.species_id, coord_system.coord_system_id, seq_region.seq_region_id,
coord_system.name,   assembly.cmp_seq_region_id , seq_region.name as seqname, seq_region.length
from meta, coord_system, seq_region, seq_region_attrib, assembly where coord_system.coord_system_id = seq_region.coord_system_id 
and seq_region_attrib.seq_region_id = seq_region.seq_region_id
and seq_region_attrib.attrib_type_id =  (SELECT attrib_type_id FROM attrib_type where name = 'Top Level') and
seq_region.seq_region_id = assembly.asm_seq_region_id and meta.species_id=coord_system.species_id and meta.meta_key = 'species.ensembl_alias_name' 
order by species_name, seqname, length DESC};

  my $dbHash;

  my ( $dbHash, $dbcHash );
  my $dsn = "DBI:mysql:host=$host";
  $dsn .= ";port=$port" if ($port);

  my $dbh = DBI->connect( $dsn, $user, $pass );

  my @dbnames =
    map { $_->[0] }
    @{ $dbh->selectall_arrayref("show databases like '%collection_core%'") };

  my ( $species_collection, $db_release, $num, $db_type, $schema_version );
  foreach my $dbname (@dbnames) {

    if ( ( $species_collection, $db_type, $db_release, $schema_version ) = $dbname =~ /^(.*)_collection_([a-z]+)_(\d+)_(\d+)_\w+$/ ){

      $dbHash->{$species_collection}->{dbname} = $dbname;
      my $dsn = "DBI:mysql:host=$host;dbname=$dbname";
      $dsn .= ";port=$port" if ($port);

      my $dbh = DBI->connect( $dsn, $user, $pass );

      #            my $max_chr_plasmid = $dbh->selectall_hashref( $max_sql, ['name'] );

      #           die "max SQL returned nothing" unless $max_chr_plasmid;
      $dbHash->{$species_collection}->{lengths} = 1;
      my $species_to_seq_region =
        $dbh->selectall_hashref( $sql,
        [ 'species_name', 'cmp_seq_region_id' ] )
        || die $dbh->err;

      $DB::single = 1;

      foreach my $species_name (keys %$species_to_seq_region) {
        
        if ( $species ne 'ALL' and  $species_name ne $species) {
          delete $species_to_seq_region->{$species_name};
          next; 
        }
        
        my $system_name_ref = $dbh->selectall_arrayref("select meta_value from meta where meta_key = 'species.db_name' and species_id = (select distinct(species_id) from meta where meta_value = ? limit 0,1) ", undef, $species_name) ;

        $species_to_seq_region->{$species_name}->{system_name} = $system_name_ref->[0]->[0];

      }
      
      if (keys %$species_to_seq_region) {
        $dbHash->{$species_collection}->{species_list} = $species_to_seq_region;
      }
    }
  }

  return $dbHash;

}

sub get_databases {

  my ( $dbHash, $dbcHash );
  my $dsn = "DBI:mysql:host=$host";
  $dsn .= ";port=$port" if ($port);

  my $db = DBI->connect( $dsn, $user, $pass );

  #    warn "DSN: $dsn";

  my @dbnames =
    map { $_->[0] }
    @{ $db->selectall_arrayref("show databases like '%collection_core%'") };

  # get the compara list

  $db->disconnect();

  my $latest_release = 0;
  my ( $db_species, $db_release, $db_type );
  my $compara_hash;
  for my $dbname (@dbnames) {
    if ( ( $db_species, $db_type, $db_release ) =
      $dbname =~ /^([a-z]+_[a-z]+)_([a-z]+)_(\d+)_\w+$/ )
    {

      next if ( $species ne 'ALL' ) && ( $db_species ne $species );
      $latest_release = $db_release if ( $db_release > $latest_release );
      $dbHash->{$db_species}->{$db_type}->{$db_release} = $dbname;

    }
    if ( ($db_release) = $dbname =~ /ensembl_compara_(\d+)/ ) {

      #N.B Re:COMAPARA for now using
      #ensembl_compara_VERSION. Others will follow
      $compara_hash->{$db_release} = $dbname;
    }

  }

  map { $dbHash->{$_}->{'compara'} = $compara_hash } keys %$dbHash;
  $release = $latest_release if ( $release eq 'LATEST' );

  return $dbHash;

}

sub footer {
  my ($ecount) = @_;
  p("</entries>");
  p("<entry_count>$ecount</entry_count>");
  p("</database>");

  print "Dumped $ecount entries\n";
  if ($nogzip) {
    close(FILE) or die $!;
  }
  else {
    $fh->close();
  }
  $total += $ecount;
}

sub header {
  my ( $dbname, $dbspecies, $dbtype ) = @_;

  p("<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>");
  p("<!DOCTYPE database [ <!ENTITY auml \"&#228;\">]>");
  p("<database>");
  p("<name>$dbname $dbspecies</name>");
  p("<description>Ensembl Genomes $dbspecies $dbtype database</description>");
  p("<release>$release</release>");
  p("");
  p("<entries>");
}

sub p {
  my ($str) = @_;

  # TODO - encoding
  $str .= "\n";
  if ($nogzip) {
    print FILE $str or die "Can't write to file ", $!;
  }
  else {
    print $fh $str or die "Can't write string: $str";
  }
}

sub format_date {
  my $t = shift;

  my ( $y, $m, $d, $ss, $mm, $hh ) = ( localtime($t) )[ 5, 4, 3, 0, 1, 2 ];
  $y += 1900;
  $d = "0" . $d if ( $d < 10 );
  my $mm = text_month($m);
  return "$d-$mm-$y";
}

sub format_datetime {
  my $t = shift;

  my ( $y, $m, $d, $ss, $mm, $hh ) = ( localtime($t) )[ 5, 4, 3, 0, 1, 2 ];
  $y += 1900;
  $d = "0" . $d if ( $d < 10 );
  my $ms = text_month($m);
  return sprintf "$d-$ms-$y %02d:%02d:%02d", $hh, $mm, $ss;
}

sub dumpFamily {
  my ( $collection, $collection_hash ) = @_;

  my $db = 'core';
  my $dbname = $collection_hash->{$db}->{$release} or next;

  my $file = "$dir/Family_$dbname.xml";
  $file .= ".gz" unless $nogzip;
  my $start_time = time;
  warn "Dumping $dbname to $file ... ", format_datetime($start_time), "\n";

  unless ($nogzip) {
    $fh = new IO::Zlib;
    $fh->open( "$file", "wb9" )
      || die("Can't open compressed stream to $file: $!");
  }
  else {
    open( FILE, ">$file" ) || die "Can't open $file: $!";
  }
  header( $dbname, $species, $db );
  my $dsn = "DBI:mysql:host=$host";
  $dsn .= ";port=$port" if ($port);
  my $ecount;
  my $dbh = DBI->connect( "$dsn:$dbname", $user, $pass ) or die "DBI::error";

  my $FAMDB = $collection_hash->{'compara'}->{$release};

  my $CORE  = $collection_hash->{'core'}->{$release};
  my $t_sth = $dbh->prepare(qq{select meta_value from $CORE.meta where meta_key='species.taxonomy_id'});
  $t_sth->execute;
  my $taxon_id = ( $t_sth->fetchrow );

  return unless $taxon_id;

  $dbh->do("SET SESSION group_concat_max_len = 100000");
  my $sth = $dbh->prepare(
    qq{ select f.family_id as id, f.stable_id as fid , f.description, group_concat(m.stable_id, unhex('1D') ,m.source_name) as IDS
        from $FAMDB.family as f, $FAMDB.family_member as fm, $FAMDB.member as m 
         where fm.family_id = f.family_id and fm.member_id = m.member_id and m.taxon_id = $taxon_id  group by fid}
    );
  $sth->execute;
  foreach my $xml_data ( @{ $sth->fetchall_arrayref( {} ) } ) {

    my @bits = split /,/, delete $xml_data->{IDS};
    map { push @{ $xml_data->{IDS} }, [ split /\x1D/ ] } @bits;
    $xml_data->{species} = $species;
    p familyLineXML($xml_data);

  }

  footer( $sth->rows );

}

sub familyLineXML {
  my ($xml_data) = @_;

  my $members = scalar @{ $xml_data->{IDS} };

  my $description = $xml_data->{description};

  $description =~ s/</&lt;/g;
  $description =~ s/>/&gt;/g;
  $description =~ s/'/&apos;/g;
  $description =~ s/&/&amp;/g;

  my $xml = qq{
<entry id="$xml_data->{id}"> 
<name>$xml_data->{fid}</name> 
   <description>$description</description>
<cross_references>} . (
    join "",
    (
      map {
        qq{
<ref dbname="$1" dbkey="$_->[0]"/>} if $_->[1] =~ /(Uniprot|ENSEMBL).*/
        } @{ $xml_data->{IDS} }
      )
  )
  . qq{
  </cross_references>
  <additional_fields>
     <field name="familymembers">$members</field>
     <field name="species">$xml_data->{species}</field>
    <field name="featuretype">Ensembl_protein_family</field>
  </additional_fields>
</entry>};
  return $xml;

}

sub c {
  my ($conf) = @_;

  foreach my $species ( keys %{ $conf->{species_list} } ) {
    print "$species\n";
    foreach
      my $seq_region_id ( keys %{ $conf->{species_list}->{$species} } )
    {
      print "\t$seq_region_id\n";
    }
  }
}

sub dumpGene {
  my ($collection, $collection_hash) = @_;
  
  warn "Start dumpGene\n";
  
  my $DB      = 1;

  #	my $SNPDB =  eval {$collection_hash->{variation}->{$release}};
  my $SNPDB = 1;

  my $DBNAME = $collection_hash->{dbname} or warn "no database not found";
  my $dsn = "DBI:mysql:host=$host";
  $dsn .= ";port=$port" if ($port);

  my $dbh = DBI->connect( "$dsn:$DBNAME", $user, $pass )
    or die "DBI::error";

  # SNP query
  my $snp_sth = eval {
    $dbh->prepare("select distinct(vf.variation_name) from $SNPDB.transcript_variation as tv, $SNPDB.variation_feature as vf where vf.variation_feature_id = tv.variation_feature_id and tv.transcript_id in(?)");
  };

  my $taxon_id = $dbh->selectrow_arrayref("select meta_value from meta where meta_key='species.taxonomy_id'");


  my %xrefs      = ();
  #my %xrefs_desc = ();
  #my %disp_xrefs = ();

  my $sql1= qq{
    select ox.ensembl_id, x.display_label, x.dbprimary_acc, ed.db_name, ox.ensembl_object_type, x.description
    from (object_xref as ox, xref as x, external_db as ed)
    where ox.xref_id = x.xref_id and x.external_db_id = ed.external_db_id
  };

  warn "Xref query...\n";

  my $T = $dbh->selectall_arrayref($sql1);
  warn "Got [", scalar(@$T), "] xrefs\n";

  foreach my $row (@$T) {
    my ($oid, $label, $acc, $dbname, $type, $desc) = @{$row||[]};
    $xrefs{$type}{$oid}{$dbname}{$label} = 1 if $label;
    $xrefs{$type}{$oid}{$dbname}{$acc} = 1 if $acc;
    #$xrefs_desc{$type}{$oid}{$desc}       = 1 if $desc;
  }

  my $sql2 = qq{ 
    select g.gene_id, x.display_label, es.synonym
  	from gene g
  	join xref x on (x.xref_id=g.display_xref_id)
  	left join external_synonym as es using (xref_id)
  };

  warn "Synonyms query...\n";
  my %synonyms = ();

  my $S =  $dbh->selectall_arrayref($sql2);
  warn "Got [", scalar(@$S), "] synonyms\n";
  foreach my $row (@$S) {
    my ($oid, $label, $syn) = @{$row || []};
    if ($label) {
      push @{$synonyms{ $oid }{ $label }}, $syn;
    }
  }

  warn "Domains query...\n";
  my %domains;
  my $D = $dbh->selectall_arrayref('
                SELECT DISTINCT g.gene_id, pf.hit_name 
                FROM gene g, transcript t, translation tl, protein_feature pf 
                WHERE g.gene_id = t.gene_id AND t.transcript_id = tl.transcript_id AND tl.translation_id = pf.translation_id');
  warn "Got [" . scalar(@$D) . "] domains\n";
  foreach (@$D) {
    $domains{$_->[0]}{$_->[1]} = 1;
  }
  

  foreach my $species ( keys %{ $collection_hash->{species_list} } ) {
    my $system_name =  delete $collection_hash->{species_list}->{$species}->{system_name};

    warn "-"x50, "\n";
    warn "Species [$system_name]\n";

    #	    next unless $system_name =~ /mitis/;

    my $counter = make_counter(0);
    ( my $species_name_underscores = $species ) =~ s/[\W]/_/g;

    #            print "START... $species_name_underscores";
    my $file = "$dir/Gene_$species_name_underscores" ."_core.xml";
    $file .= ".gz" unless $nogzip;
    my $start_time = time;

    unless ($nogzip) {
      $fh = new IO::Zlib;
      $fh->open( "$file", "wb9" )
        || die("Can't open compressed stream to $file: $!");
    }
    else {
      open( FILE, ">$file" ) || die "Can't open $file: $!";
    }
    header( $DBNAME, $species, $DB );

    warn "Dumping to [$file] ... ", format_datetime($start_time), "\n";
    my $extra = $DB ne 'core' ? ";db=$DB" : '';
    
    warn "Seq regions [" . (scalar keys %{ $collection_hash->{species_list}->{$species} }) . "]\n";
    
    foreach my $cmp_seq_region_id ( keys %{ $collection_hash->{species_list}->{$species} } ) {
      
      my $seq_region_id =  $collection_hash->{species_list}->{$species}->{$cmp_seq_region_id}->{seq_region_id} ;
      
      #warn "Seq region id [$seq_region_id]\n";
      
      #warn "  Gene query...\n";
      my $gene_info = $dbh->selectall_arrayref(q/
        SELECT g.gene_id, t.transcript_id, tr.translation_id,
             g.stable_id AS gsid, t.stable_id AS tsid, tr.stable_id AS trsid,
             g.description, ed.db_name, x.dbprimary_acc,x.display_label, ad.display_label, ad.description, g.source, g.status, g.biotype,
             sr.name AS seq_region_name, g.seq_region_start, g.seq_region_end
        FROM (gene AS g,
             analysis_description AS ad,
             transcript AS t) LEFT JOIN
             translation AS tr ON t.transcript_id = tr.transcript_id LEFT JOIN
             xref AS `x` ON g.display_xref_id = x.xref_id LEFT JOIN
             external_db AS ed ON ed.external_db_id = x.external_db_id LEFT JOIN
             seq_region AS sr ON sr.seq_region_id = g.seq_region_id
        WHERE t.gene_id = g.gene_id AND g.analysis_id = ad.analysis_id AND g.seq_region_id = ?
        ORDER BY g.stable_id, t.stable_id/, 
        undef, 
        $seq_region_id
      );
      #warn "  Got [" . scalar(@$gene_info) . "] genes\n";
      
      next unless @$gene_info; # skip this seq region if there are no genes to dump
      
      my %hash = map { $_->[0] } @$gene_info;
      my $ecount = scalar keys %hash, "\n\n";
      
      #warn "  Exons query...\n";
      my %exons = ();
      my $T     = $dbh->selectall_arrayref(q/
        SELECT DISTINCT t.gene_id, e.stable_id
        FROM transcript AS t, exon_transcript AS et, exon AS e
        WHERE t.transcript_id = et.transcript_id AND et.exon_id = e.exon_id AND t.seq_region_id = ?/,
        undef,
        $seq_region_id
      );
      #warn "  Got [" . scalar(@$T) . "] exons\n";
      foreach (@$T) {
        $exons{ $_->[0] }{ $_->[1] } = 1;
      }
    
      my %old;
      
      #warn "  Dumping rows...\n";
      foreach my $row (@$gene_info) {
        
        my (
          $gene_id,
          $transcript_id,
          $translation_id,
          $gene_stable_id,
          $transcript_stable_id,
          $translation_stable_id,
          $gene_description,
          $extdb_db_display_name,
          $xref_primary_acc,
          $xref_display_label,
          $analysis_description_display_label,
          $analysis_description,
          $gene_source,
          $gene_status,
          $gene_biotype,
          $seq_region_name,
          $seq_region_start,
          $seq_region_end,
        ) = @$row;
                    
        if ( $old{'gene_id'} != $gene_id ) {

          if ( $old{'gene_id'} ) {
            if ( $SNPDB && $DB eq 'core' ) {
              my @transcript_ids = keys %{ $old{transcript_ids} };
              $snp_sth->execute("@transcript_ids");
              my $snps = $snp_sth->fetchall_arrayref;
              $old{snps} = $snps;
            }
            p geneLineXML( $species, \%old, $counter, $collection, $system_name );
          }
          
          %old = (
            'gene_id'                => $gene_id,
            'gene_stable_id'         => $gene_stable_id,
            'description'            => $gene_description,
            'translation_stable_ids' => { $translation_stable_id ? ( $translation_stable_id => 1 ) : () },
            'transcript_stable_ids'  => { $transcript_stable_id ? ( $transcript_stable_id => 1 ) : () },
            'transcript_ids'         => { $transcript_id ? ( $transcript_id => 1 ) : () },
            'exons'                  => {},
            'domains'                => {},
            'external_identifiers'   => {},
            'alt'                    => $xref_display_label ? "($analysis_description_display_label: $xref_display_label)" : "(novel gene)",
            'ana_desc_label'         => $analysis_description_display_label,
            'ad'                     => $analysis_description,
            'source'                 => ucfirst($gene_source),
            'st'                     => $gene_status,
            'biotype'                => $gene_biotype,
            'taxon_id'               => $taxon_id->[0],
            'gene_name'              => $xref_display_label ? $xref_display_label : $gene_stable_id,
            'seq_region_name'        => $seq_region_name,
            'synonyms'               => {},
            'location'               => sprintf( '%s:%s-%s', $seq_region_name, $seq_region_start, $seq_region_end ),
          );
          
          # display name
          if (!$xref_display_label or $xref_display_label eq $gene_stable_id) {
            $old{'display_name'} = $gene_stable_id;
          } else {
            $old{'display_name'} = "$xref_display_label [$gene_stable_id]";
          }
          
          $old{'source'} =~ s/base/Base/;
          $old{'exons'} = $exons{$gene_id};
          foreach my $K ( keys %{ $exons{$gene_id} } ) {
            $old{'i'}{$K} = 1;
          }
          $old{'domains'} = $domains{$gene_id};
          $old{'synonyms'} = $synonyms{$gene_id};

          foreach my $db ( keys %{ $xrefs{'Gene'}{$gene_id} || {} } ) {
            foreach my $K ( keys %{ $xrefs{'Gene'}{$gene_id}{$db} } ) {
              $old{'external_identifiers'}{$db}{$K} = 1;
            }
          }
          foreach my $db ( keys %{ $xrefs{'Transcript'}{$transcript_id} || {} } ) {
            foreach my $K ( keys %{ $xrefs{'Transcript'}{$transcript_id}{$db} } ) {
              $old{'external_identifiers'}{$db}{$K} = 1;
            }
          }
          foreach my $db ( keys %{ $xrefs{'Translation'}{$translation_id} || {} } ) {
            foreach my $K ( keys %{ $xrefs{'Translation'}{$translation_id}{$db} } ) {
              $old{'external_identifiers'}{$db}{$K} = 1;
            }
          }

        }
        else {
          $old{'transcript_stable_ids'}{$transcript_stable_id} = 1;
          $old{'transcript_ids'}{$transcript_id} = 1;
          $old{'translation_stable_ids'}{$translation_stable_id} = 1;

          foreach my $db (keys %{ $xrefs{'Transcript'}{$transcript_id} || {} } ) {
            foreach my $K ( keys %{ $xrefs{'Transcript'}{$transcript_id}{$db} } ) {
              $old{'external_identifiers'}{$db}{$K} = 1;
            }
          }
          foreach my $db (keys %{ $xrefs{'Translation'}{$translation_id} || {} } ) {
            foreach my $K (keys %{ $xrefs{'Translation'}{$translation_id}{$db} } ) {
              $old{'external_identifiers'}{$db}{$K} = 1;
            }
          }
        }
      }

      if ( $SNPDB && $DB eq 'core' ) {
        my @transcript_ids = keys %{ $old{transcript_ids} };
        $snp_sth->execute("@transcript_ids");
        my $snps = $snp_sth->fetchall_arrayref;
        $old{snps} = $snps;
      }

      p geneLineXML( $species, \%old, $counter, $collection, $system_name );

    }
    footer( $counter->() );
    warn "Finished for [$species].\n";

  }
  warn "End dumpGene\n";
}

sub geneLineXML {
  my ( $species, $xml_data, $counter,$collection, $system_name ) = @_;

  return warn "gene id not set" if $xml_data->{'gene_stable_id'} eq '';

  my $gene_id     = $xml_data->{'gene_stable_id'};
  my $location     = $xml_data->{'location'};
  #my $altid       = $xml_data->{'alt'} or die "altid not set";
  my $transcripts = $xml_data->{'transcript_stable_ids'}
    or die "transcripts not set";

  my $snps = $xml_data->{'snps'};
  my $synonyms = $xml_data->{'synonyms'};
  my $taxon_id         = $xml_data->{'taxon_id'};
  my $gene_name   = $xml_data->{'gene_name'};
  my $seq_region_name = $xml_data->{'seq_region_name'};
  
  my $peptides = $xml_data->{'translation_stable_ids'}
    or die "peptides not set";
  my $exons = $xml_data->{'exons'} or die "exons not set";
  my $domains = $xml_data->{'domains'};# or warn "!!!! domains not set for gene_id: $gene_id"; <-- not always present?
  my $external_identifiers = $xml_data->{'external_identifiers'}
    or die "external_identifiers not set";
  my $description = $xml_data->{'description'};
  my $type        = $xml_data->{'source'} . ' ' . $xml_data->{'biotype'}
    or die "problem setting type";

  my $exon_count       = scalar keys %$exons;
  my $domain_count       = scalar keys %$domains;
  my $transcript_count = scalar keys %$transcripts;
  
  my $display_name = $xml_data->{'display_name'};
  $display_name =~ s/</&lt;/g;
  $display_name =~ s/>/&gt;/g;
  
  $description =~ s/</&lt;/g;
  $description =~ s/>/&gt;/g;
  $description =~ s/'/&apos;/g;
  $description =~ s/&/&amp;/g;

  $gene_id =~ s/</&lt;/g;
  $gene_id =~ s/>/&gt;/g;

  #$altid =~ s/</&lt;/g;
  #$altid =~ s/>/&gt;/g;

  my $xml = qq{
 <entry id="$gene_id"> 
   <name>$display_name</name>
<description>$description</description>};

  my $cross_references = qq{<cross_references>};
  $cross_references .= qq{
<ref dbname="ncbi_taxonomy_id" dbkey="$taxon_id"/>};

  foreach my $ext_db_name ( keys %$external_identifiers ) {
    if ( $ext_db_name =~
      /(Uniprot|GOA|GO|Interpro|Medline|Sequence_Publications|EMBL)/ )
    {

      map {
        $cross_references .= qq{
<ref dbname="$1" dbkey="$_"/>};
        } keys %{ $external_identifiers->{$ext_db_name} }

    }
    else {
      foreach my $key ( keys %{ $external_identifiers->{$ext_db_name} } )
      {
        $key         =~ s/</&lt;/g;
        $key         =~ s/>/&gt;/g;
        $key         =~ s/&/&amp;/g;
        $ext_db_name =~ s/^Ens*/ENSEMBL/;
        $cross_references .= qq{
<ref dbname="$ext_db_name" dbkey="$key"/>};
      }

    }
  }

  $cross_references .= qq{</cross_references>};

  #warn "GENE $gene_id \n";
  my @names = keys %{$synonyms || {}};

  my @synonyms =  grep {$_} map { @{$synonyms->{$_}||[]}}   keys %{$synonyms || {}};

  #warn "Names: ($gene_name : $taxon_id) : ", join ' * ', @names, " ### Synonyms : ", join ' * ', @synonyms;

  my $additional_fields .= qq{
<additional_fields>};

  my $synhtml = '';
  map {
    $synhtml .=
      qq{
      <field name="gene_synonym">$_</field> }
    } @synonyms;

  $additional_fields .= (
    join "",
    (
      map {
        qq{
      <ref dbname="ensemblvariation" dbkey="$_->[0]"/>}
        } @$snps
      )
    )

    .  qq{<field name="species">$species</field>
      <field name="collection">$collection</field>
      <field name="system_name">$system_name</field>
      <field name="genomic_unit">$genomic_unit</field>
      <field name="featuretype">Gene</field>
      <field name="source">$type</field>
      <field name="location">$location</field>
      <field name="transcript_count">$transcript_count</field> 
      <field name="gene_name">$gene_name</field>
      <field name="seq_region_name">$seq_region_name</field>
}

    . (
    join "",
    (
      map {
        qq{
      <field name="transcript">$_</field>}
        } keys %$transcripts
      )
    )

    . qq{  <field name="exon_count">$exon_count</field> }

    . (
    join "",
    (
      map {
        qq{
      <field name="exon">$_</field>}
        } keys %$exons
      )
    )
    . qq{  <field name="domain_count">$domain_count</field> }

    . (
    join "",
    (
      map {
        qq{
      <field name="domain">$_</field>}
        } keys %$domains
      )
    )
    . (
    join "",
    (
      map {
        qq{
      <field name="peptide">$_</field>}
        } keys %$peptides
      )
    )
    . $synhtml
    . qq{
</additional_fields>};

  $counter->();
  return $xml . $cross_references . $additional_fields . '</entry>';

}

sub dumpSequence {
  my ( $dbspecies, $conf ) = @_;

  #    my $sanger = sanger_project_names( $conf );
  my $sanger = 'SANGER STUFF';
  my %config = (
    "Homo sapiens" => [
      [
        'Clone',
        'tilepath, cloneset_1mb, cloneset_30k, cloneset_32k',
        'name,well_name,clone_name,synonym,embl_acc,sanger_project,alt_well_name,bacend_well_name'
      ],
      [ 'NT Contig',     'ntctgs', 'name' ],
      [ 'Encode region', 'encode', 'name,synonym,description' ],
      ],
    "Mus musculus" => [
      [
        'BAC',
        'cloneset_0_5mb,cloneset_1mb,bac_map,tilingpath_cloneset',
        'embl_acc,name,clone_name,well_name,synonym,alt_embl_acc'
      ],
      [ 'Fosmid',      'fosmid_map', 'name,clone_name' ],
      [ 'Supercontig', 'superctgs',  'name' ],
      ],
    "Anopheles gambiae" => [
      [ 'BAC',      'bacs',       'name,synonym,clone_name' ],
      [ 'BAC band', 'bacs_bands', 'name,synonym,clone_name' ],
      ],
    "Gallus gallus" => [
      [ 'BAC', 'bac_map', 'name,synonym,clone_name' ],
      [
        'BAC ends',                'bacends',
        'name,synonym,clone_name', 'otherfeatures'
      ]
      ]
    );

  my $dbname = $conf->{'core'}->{$release} or next;

  my $file = "$dir/Sequence_$dbname.xml";
  $file .= ".gz" unless $nogzip;
  my $start_time = time;
  warn "Dumping $dbname to $file ... ", format_datetime($start_time), "\n";

  unless ($nogzip) {
    $fh = new IO::Zlib;
    $fh->open( "$file", "wb9" )
      || die("Can't open compressed stream to $file: $!");
  }
  else {
    open( FILE, ">$file" ) || die "Can't open $file: $!";
  }
  header( $dbname, $dbspecies, 'core' );
  my $dsn = "DBI:mysql:host=$host";
  $dsn .= ";port=$port" if ($port);
  my $ecount;
  my $dbh = DBI->connect( "$dsn:$dbname", $user, $pass ) or die "DBI::error";

  my $COREDB = $dbname;
  my $ESTDB  = $conf->{otherfeatures}->{$release};

  my @types = @{ $config{$dbspecies} || [] };
  my $ecounter;
  foreach my $arrayref (@types) {

    my ( $TYPE, $mapsets, $annotationtypes, $DB ) = @$arrayref;

    my $DB = $DB eq 'otherfeatures' ? $ESTDB : $COREDB;
    my @temp = split( ',', $mapsets );
    my @mapsets;
    foreach my $X (@temp) {
      my $ID = $dbh->selectrow_array(
        "select misc_set_id from $DB.misc_set where code = ?",
        {}, $X );
      push @mapsets, $ID if ($ID);
    }

    next unless @mapsets;
    @temp = split( ',', $annotationtypes );
    my @mapannotationtypes;
    foreach my $X (@temp) {
      my $ID = $dbh->selectrow_array(
        "select attrib_type_id from $DB.attrib_type where code = ?",
        {}, $X );
      push @mapannotationtypes, $ID if ($ID);
    }
    next unless @mapannotationtypes;
    my $Z       = " ma.value";
    my $MAPSETS = join ',', @mapsets;
    my $sth     = $dbh->prepare(
      "select mf.misc_feature_id, sr.name,
              ma.value, mf.seq_region_end-mf.seq_region_start+1 as len, 
              at.code
         from $DB.misc_feature_misc_set as ms, 
              $DB.misc_feature as mf,
              seq_region   as sr,
              $DB.misc_attrib  as ma,
              $DB.attrib_type  as at 
        where mf.seq_region_id = sr.seq_region_id and mf.misc_feature_id = ms.misc_feature_id and ms.misc_set_id in ($MAPSETS) and
              mf.misc_feature_id = ma.misc_feature_id and ma.attrib_type_id = at.attrib_type_id
        order by mf.misc_feature_id, at.code"
      );
    $sth->execute();
    my ( $oldtype, $old_ID, $oldchr, $emblaccs, $oldlen, $synonyms, $NAME );

    while ( my ( $ID, $chr, $val, $len, $type ) = $sth->fetchrow_array() ) {

      if ( $ID == $old_ID ) {
        $NAME = $val
          if $type eq 'well_name'
            || $type eq 'clone_name'
            || $type eq 'name'
            || $type eq 'non_ref';
        $NAME = $val if !$NAME && $type eq 'embl_acc';
        $NAME = $val if !$NAME && $type eq 'synonym';
        $NAME = $val if !$NAME && $type eq 'sanger_project';
        push @{$emblaccs}, $val if $val;
      }
      else {
        p seqLineXML(
          $dbspecies, $TYPE,   $NAME, $oldchr,
          $emblaccs,  $oldlen, $sanger
          ) if $old_ID;
        $NAME     = undef;
        $emblaccs = undef;
        $NAME     = $val
          if $type eq 'well_name'
            || $type eq 'clone_name'
            || $type eq 'name'
            || $type eq 'non_ref';
        $NAME = $val if !$NAME && $type eq 'embl_acc';
        $NAME = $val if !$NAME && $type eq 'synonym';
        $NAME = $val if !$NAME && $type eq 'sanger_project';
        $emblaccs->[0] = $val;
        ( $old_ID, $oldchr, $oldlen ) = ( $ID, $chr, $len );
        $ecounter += 1;
      }
    }
    p seqLineXML( $dbspecies, $TYPE, $NAME, $oldchr, $emblaccs, $oldlen,
      $sanger )
      if $old_ID;
  }

  footer($ecounter);

  #   my $sth = $conf->{'dbh'}->prepare(
  #     "select c.name, c.length, cs.name
  #        from seq_region as c, coord_system as cs
  #       where c.coord_system_id = cs.coord_system_id" );
  #   $sth->execute();
  #   while( my($name,$length,$type) = $sth->fetchrow_array() ) {
  #     my $extra_IDS = ''; mysql $extra_desc = '';
  #     if( %{$sanger->{$name}||{}} ) {
  #       $extra_IDS  = join ' ', '',sort keys %{$sanger->{$name}};
  #       $extra_desc = " and corresponds to the following Sanger projects: ".join( ', ',sort keys %{$sanger->{$name}});
  #     }
  #     print_time O join "\t",
  #       (INC_SPECIES?"$conf->{'species'}\t":"").ucfirst($type),       $name,
  #       ($type eq 'chromosome' && length( $name ) < 5) ?
  #         "/$conf->{'species'}/mapview?chr=$name" :
  #         ($length > 0.5e6 ? "/$conf->{'species'}/cytoview?region=$name" :
  #               "/$conf->{'species'}/contigview?region=$name" ),
  #       "$name$extra_IDS", "$name isnull a @{[ucfirst($type)]} (of length $length)$extra_desc\n";
  #   }
}

sub seqLineXML {
  my ( $species, $type, $name, $chr, $val, $len, $sanger ) = @_;

  pop @$val;

  #     my $description = "$type $name is mapped to Chromosome $chr" .

  #       (
  #         @$val > 0
  #         ? ' and has '
  #           . @$val
  #           . " EMBL accession"
  #           . (
  #             @$val > 1
  #             ? 's'
  #             : ''
  #           )
  #           . "/synonym"
  #           . (
  #             @$val > 1
  #             ? 's '
  #             : ' '
  #           )
  #           . "@$val"
  #         : ''
  #       )

  #       . " and length $len bps\n";

  my $xml = qq{
 <entry id="$name"> 
    <cross_references>}

    . (
    join "",
    (
      map {
        qq{
      <ref dbname="EMBL" dbkey="$_"/>}
        } @$val
      )
    )

    . qq{</cross_references>
    <additional_fields>
      <field name="species">$species</field>
      <field name="type">$type</field>
      <field name="chromosome">$chr</field>
      <field name="length">$len</field>
    <field name="featuretype">Genomic</field>
   </additional_fields>
</entry>};

  return $xml;

}

sub dumpSNP {
  my ( $dbspecies, $conf ) = @_;

  #    warn Dumper $conf;

  warn "\n", '*' x 20, "\n";

  my $COREDB = my $dbname = $conf->{'core'}->{$release};

  my $dbname = $conf->{variation}->{$release} or next;
  my $file = "$dir/SNP_$dbname.xml";
  $file .= ".gz" unless $nogzip;
  my $start_time = time;
  warn "Dumping $dbname to $file ... ", format_datetime($start_time), "\n";
  unless ($nogzip) {
    $fh = new IO::Zlib;
    $fh->open( "$file", "wb9" )
      || die "Can't open compressed stream to $file: $!";
  }
  else {
    open( FILE, ">$file" ) || die "Can't open $file: $!";
  }

  header( $dbname, $dbspecies, $dbname );
  my $dsn = "DBI:mysql:host=$host";
  $dsn .= ";port=$port" if ($port);
  my $ecount;
  my $dbh = DBI->connect( "$dsn:$dbname", $user, $pass )
    or die "DBI::error";
  my $source_hash =
    $dbh->selectall_hashref( qq{SELECT source_id, name FROM source},
    [qw(source_id)] );

  #     my $tid_to_gene = $dbh->selectall_hashref(qq{select  t.transcript_id, gsi.stable_id from $COREDB.gene as g, $COREDB.gene_stable_id as gsi, $COREDB.transcript as t where gsi.gene_id = g.gene_id and t.gene_id = g.gene_id limit 10;},[qw(transcript_id)]);

  #     my $sth = $dbh->prepare("select vf.variation_name, vf.source_id, group_concat(vs.source_id, ' ',vs.name), vf.variation_feature_id,vf.variation_id from variation_feature vf , transcript_variation tv
  # left join variation_synonym vs on vf.variation_id = vs.variation_id where tv.transcript_variation_id = vf.variation_feature_id group by vf.variation_id");

  my $sth = $dbh->prepare(
    "select vf.variation_name, vf.source_id, group_concat(vs.source_id, ' ',vs.name), vf.consequence_type from variation_feature vf left join variation_synonym vs on vf.variation_id = vs.variation_id group by vf.variation_id"
    );

  #     my $vfi2gene_sth = $dbh->prepare(qq{select distinct(gsi.stable_id) from $COREDB.gene as g, $COREDB.gene_stable_id as gsi, $COREDB.transcript as t where gsi.gene_id = g.gene_id and t.gene_id = g.gene_id and transcript_id in
  # (select tv.transcript_id from transcript_variation tv , variation_feature vf where vf.variation_feature_id =tv.variation_feature_id and vf.variation_feature_id = ?)});

  $sth->execute() or die "Error:", $DBI::errstr;

  while ( my $rowcache = $sth->fetchall_arrayref( undef, 10_000 ) ) {

    my $xml;
    while ( my $row = shift( @{$rowcache} ) ) {

      # 	    $vfi2gene_sth->execute($row->[3]);
      # 	      my $gsi = $vfi2gene_sth->fetchall_arrayref;
      my $name       = $row->[0];
      my @synonyms   = split /,/, @$row->[2];
      my $snp_source = $source_hash->{ $row->[1] }->{name};

      # 	    my $description =
      # 	      "A $snp_source SNP with "
      # 		. scalar @synonyms
      # 		  . ' synonym'
      # 		    . (  @synonyms > 1 | @synonyms < 1 ? 's '   : ' ' )
      # 		      . ( @synonyms > 0 ? "( " . (join "",  map{  map{  $source_hash->{$_->[0]}->{name} , ':', $_->[1] , ' ' } [split]  } @synonyms ) . ")" : '' );

      $xml .= qq{<entry id="$name">
  <additional_fields>
    <field name="species">$dbspecies</field>
    <field name="featuretype">SNP</field>
<field name="consequence">$row->[3]</field>};

      foreach my $syn (@synonyms) {
        my @syn_bits = split / /, $syn;
        $syn_bits[1] =~ s/:/ /;

        my $source = $source_hash->{ $syn_bits[0] }->{name};
        $xml .= qq{
<field name="synonym">$syn_bits[1] [source; $source]</field>};
      }
      $xml .= qq{
  </additional_fields>
</entry>
};

    }

    p($xml);
  }

  footer( $sth->rows );
  print_time($start_time);

}

sub dumpUnmappedFeatures {
  my ( $dbspecies, $conf ) = @_;

  my $db     = 'core';
  my $COREDB = $conf->{$db}->{$release} or next;
  my $file   = "$dir/UnmappedFeature_$COREDB.xml";
  $file .= ".gz" unless $nogzip;
  my $start_time = time;
  warn "Dumping $COREDB to $file ... ", format_datetime($start_time), "\n";

  unless ($nogzip) {
    $fh = new IO::Zlib;
    $fh->open( "$file", "wb9" )
      || die("Can't open compressed stream to $file: $!");
  }
  else {
    open( FILE, ">$file" ) || die "Can't open $file: $!";
  }
  header( $COREDB, $dbspecies, $db );
  my $dsn = "DBI:mysql:host=$host";
  $dsn .= ";port=$port" if ($port);
  my $ecount;
  my $dbh = DBI->connect( "$dsn:$COREDB", $user, $pass ) or die "DBI::error";

  my %unmapped_queries = (
    'None' => qq(
      select a.logic_name, e.db_display_name,
             uo.identifier, ur.summary_description,
             'Not mapped'
        from $COREDB.analysis as a, $COREDB.external_db as e, $COREDB.unmapped_object as uo,
             $COREDB.unmapped_reason as ur
       where a.analysis_id = uo.analysis_id and 
             uo.external_db_id = e.external_db_id and
             uo.unmapped_reason_id = ur.unmapped_reason_id and
               uo.ensembl_id = 0 
),
    'Transcript' => qq(
      select a.logic_name, e.db_display_name,
             uo.identifier, ur.summary_description,
             concat( 'Transcript: ', tsi.stable_id, '; Gene: ',gsi.stable_id )
        from $COREDB.analysis as a, $COREDB.external_db as e, $COREDB.unmapped_object as uo,
             $COREDB.unmapped_reason as ur, $COREDB.transcript_stable_id as tsi,
             $COREDB.transcript as t, $COREDB.gene_stable_id as gsi
       where a.analysis_id = uo.analysis_id and 
             uo.external_db_id = e.external_db_id and
             uo.unmapped_reason_id = ur.unmapped_reason_id and
             uo.ensembl_id = t.transcript_id and
             uo.ensembl_object_type = 'Transcript' and
             t.transcript_id = tsi.transcript_id and
             t.gene_id       = gsi.gene_id 
),
    'Translation' => qq(
      select a.logic_name, e.db_display_name, uo.identifier, ur.summary_description,
             concat( 'Translation: ',trsi.stable_id,'; Transcript: ', tsi.stable_id, '; Gene: ',gsi.stable_id )
        from $COREDB.analysis as a, $COREDB.external_db as e, $COREDB.unmapped_object as uo,
             $COREDB.unmapped_reason as ur, $COREDB.transcript_stable_id as tsi,
             $COREDB.translation as tr, $COREDB.translation_stable_id as trsi,
             $COREDB.transcript as t, $COREDB.gene_stable_id as gsi
       where a.analysis_id = uo.analysis_id and 
             uo.external_db_id = e.external_db_id and
             uo.unmapped_reason_id = ur.unmapped_reason_id and
             uo.ensembl_id = tr.translation_id and 
             tr.transcript_id = t.transcript_id and
             trsi.translation_id = tr.translation_id and
             uo.ensembl_object_type = 'Translation' and
             t.transcript_id = tsi.transcript_id and
             t.gene_id       = gsi.gene_id 
    )
    );
  my $entry_count = 0;
  foreach my $type ( keys %unmapped_queries ) {
    my $SQL = $unmapped_queries{$type};
    my $sth = $dbh->prepare($SQL);
    $sth->execute;
    while ( my $T = $sth->fetchrow_arrayref() ) {

      #            print join "\t", ("$species\t") . qq(Unmapped feature),
      #             "$T->[1] $T->[2]",
      #            "$dbspecies/featureview?type=Gene;id=$T->[2]", "$T->[2] $T->[4]",
      #           "$T->[3]; $T->[4]\n";
      p unmappedFeatureXML( $T, $dbspecies )

    }
    $entry_count += $sth->rows

  }

  footer($entry_count);

}

sub unmappedFeatureXML {
  my ( $xml_data, $dbspecies ) = @_;

  return qq{
 <entry id="$xml_data->[2]"> 
   <name>$xml_data->[1] $xml_data->[2]</name>
    <description>$xml_data->[3]; $xml_data->[4]</description>
    <additional_fields>
      <field name="species">$dbspecies</field>
      <field name="featuretype">UnmappedFeature</field>
    </additional_fields>
</entry>};

}

sub dumpUnmappedGenes {
  my ( $dbspecies, $conf ) = @_;

  my $db = 'core';
  my $dbname = $conf->{$db}->{$release} or next;

  my $file = "$dir/UnmappedGene_$dbname.xml";
  $file .= ".gz" unless $nogzip;
  my $start_time = time;
  warn "Dumping $dbname to $file ... ", format_datetime($start_time), "\n";

  unless ($nogzip) {
    $fh = new IO::Zlib;
    $fh->open( "$file", "wb9" )
      || die("Can't open compressed stream to $file: $!");
  }
  else {
    open( FILE, ">$file" ) || die "Can't open $file: $!";
  }
  header( $dbname, $dbspecies, $db );
  my $dsn = "DBI:mysql:host=$host";
  $dsn .= ";port=$port" if ($port);
  my $ecount;
  my $dbh = DBI->connect( "$dsn:$dbname", $user, $pass ) or die "DBI::error";

  my $COREDB = $conf->{$db}->{$release};

  my %current_stable_ids = ();
  foreach my $type (qw(gene transcript translation)) {
    $current_stable_ids{$type} = {
      map { @$_ } @{
        $dbh->selectall_arrayref(
          "select stable_id,1 from $COREDB." . $type . "_stable_id"
          )
        }
      };
  }
  my $species = $dbspecies;
  my $sth     = $dbh->prepare(
    qq(
    select sie.type, sie.old_stable_id, if(isnull(sie.new_stable_id),'NULL',sie.new_stable_id), ms.old_release*1.0 as X, ms.new_release*1.0 as Y
      from $COREDB.mapping_session as ms, $COREDB.stable_id_event as sie
     where ms.mapping_session_id = sie.mapping_session_id and ( old_stable_id != new_stable_id or isnull(new_stable_id) )
     order by Y desc, X desc 
  )
    );

  $sth->execute();
  my %mapping = ();
  while ( my ( $type, $osi, $nsi ) = $sth->fetchrow_array() ) {
    next
      if $current_stable_ids{$type}{ $osi
        };    ## Don't need to cope with current IDS already searchable...
    $mapping{$type}{$osi}{$nsi} = 1;
    if ( $mapping{$type}{$nsi} ) {
      foreach ( keys %{ $mapping{$type}{$nsi} } ) {
        $mapping{$type}{$osi}{$_} = 1;
      }
    }
  }

  foreach my $type ( keys %mapping ) {
    $ecount += scalar keys %{ $mapping{$type} }, '  ';

    foreach my $osi ( keys %{ $mapping{$type} } ) {

      my @current_sis    = ();
      my @deprecated_sis = ();
      foreach ( keys %{ $mapping{$type}{$osi} } ) {
        if ( $current_stable_ids{$_} ) {
          push @current_sis, $_;
        }
        elsif ( $_ ne 'NULL' ) {
          push @deprecated_sis, $_;
        }
      }
      if (@current_sis) {

        my $description =
          qq{$type $osi is no longer in the Ensembl database but it has been mapped to the following current identifiers: @current_sis}
          . (
          @deprecated_sis
          ? "; and the following deprecated identifiers: @deprecated_sis"
          : ''
          );
        p unmappedGeneXML( $osi, $dbspecies, $description, lc($type) );

      }
      elsif (@deprecated_sis) {

        my $description =
          qq($type $osi is no longer in the Ensembl database but it has been mapped to the following identifiers: @deprecated_sis);
        p unmappedGeneXML( $osi, $dbspecies, $description, lc($type) );
      }
      else {

        my $description =
          qq($type $osi is no longer in the Ensembl database and it has not been mapped to any newer identifiers);
        p unmappedGeneXML( $osi, $dbspecies, $description, lc($type) );
      }
    }
  }

  footer($ecount);
}

sub unmappedGeneXML {
  my ( $id, $dbspecies, $description, $type ) = @_;

  return qq{
 <entry id="$id">
    <description>$description</description>
    <additional_fields>
      <field name="species">$dbspecies</field>
      <field name="featuretype">Unmapped$type</field>
    </additional_fields>
</entry>};

}

sub make_counter {
  my $start = shift;
  return sub { $start++ }
}

