#!/usr/bin/env perl
use strict;
use warnings;

use File::Basename qw(dirname);
use FindBin qw($Bin);
#use Data::Dumper;

BEGIN {
  my $serverroot = dirname($Bin) . "/../../";
  unshift @INC, "$serverroot/conf", $serverroot;
  
  require SiteDefs;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;

  require EnsEMBL::Web::DBSQL::WebsiteAdaptor;
  require EnsEMBL::Web::Hub;  
}

my $hub = new EnsEMBL::Web::Hub;
my $dbh = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub)->db;
my $sd  = $hub->species_defs;

$dbh->do(
  'CREATE TABLE IF NOT EXISTS `seq_region_search` (
    `id` int NOT NULL AUTO_INCREMENT ,
    `seq_region_name` varchar(40) NOT NULL,
    `seq_region_length` int(10) NOT NULL,
    `coord_system_name` varchar(40) NOT NULL,
    `species_name` varchar(255) NOT NULL,
    PRIMARY KEY (`id`),
    INDEX `seq_region_name` (`seq_region_name`) USING BTREE 
  )'
);

$dbh->do('TRUNCATE TABLE `seq_region_search`');

print "Fetching seq regions...\n";
my $seq_regions = get_seq_regions();

my @insert;
foreach my $sr (@$seq_regions) {
  push(@insert, sprintf('(%s, %s, %s, %s)', 
    $dbh->quote($sr->{seq_region_name}),
    $dbh->quote($sr->{seq_region_length}),
    $dbh->quote($sr->{coord_system_name}),
    $dbh->quote($sr->{species_name})
  ));
}

# insert in batches of 10,000
print "Inserting records...\n";
while (@insert) {
  my $values = join(',', splice(@insert, 0, 10000));
  $dbh->do("INSERT INTO seq_region_search (seq_region_name, seq_region_length, coord_system_name, species_name) VALUES $values");
  print "remaining" . (scalar @insert) . "\n";
}  

print "Optimising table...\n";
$dbh->do("OPTIMIZE TABLE seq_region_search");

print "Done\n";

exit;

#------------------------------------------------------------------------------

# get hash of species/meta data
sub get_seq_regions {
  my @seq_regions;
  
  foreach my $dataset (@ARGV ? @ARGV : @$SiteDefs::ENSEMBL_DATASETS) {   
    print "Dataset $dataset\n";
    my $adaptor = $hub->get_adaptor('get_GeneAdaptor', 'core', $dataset);
    if (!$adaptor) {
      warn "core db doesn't exist for $dataset\n";
      next;
    }
        
    # process each species
    my $sth = $adaptor->prepare(
      "SELECT sr.name AS seq_region_name, sr.length AS seq_region_length, cs.name AS coord_system_name, cs.species_id
       FROM seq_region sr JOIN coord_system cs USING (coord_system_id)"
    ); 
    $sth->execute;  
    
    while (my $row = $sth->fetchrow_hashref) {
      $row->{species_name} = get_meta_value($adaptor, $row->{species_id}, 'species.production_name');
      push @seq_regions, $row;  
    }
  }
  
  return \@seq_regions;
}

# get value(s) for given meta key
sub get_meta_value {
  my ($adaptor, $species_id, $meta_key) = @_;
  my $sth = $adaptor->prepare("SELECT meta_value FROM meta WHERE species_id = ? AND meta_key = ?"); 
  $sth->execute($species_id, $meta_key);  
  my @values;
  while (my $value = $sth->fetchrow_array) {
    push @values, $value;
  }
  return wantarray ? @values : $values[0];
}


