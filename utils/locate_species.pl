#!/usr/local/bin/perl

# search for species and find out which dataset they belong to

use strict;
use FindBin qw($Bin);
use Data::Dumper;

BEGIN {
  unshift @INC, "$Bin/../../../conf";
  unshift @INC, "$Bin/../../../";
  require SiteDefs;
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;
}

require LoadPlugins;
LoadPlugins::plugin(sub {/(SpeciesDefs.pm)$/});

use EnsEMBL::Web::SpeciesDefs;
my $sd = EnsEMBL::Web::SpeciesDefs->new;
my @all_sp = $sd->valid_species;

foreach my $sp (@ARGV) {

  print "\nMatches for '$sp':\n";
  my @matches = grep {/$sp/i} @all_sp;
  foreach (@matches) {
    printf "  %-50s in collection %s\n", $_, $sd->get_config($_, "SPECIES_DATASET");
  } 
  
}

1;