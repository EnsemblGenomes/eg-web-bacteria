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


# search for species and find out which dataset they belong to

use strict;
use FindBin qw($Bin);
use Data::Dumper;
use lib "$Bin/../../eg-web-common/utils";
use LibDirs;
use LoadPlugins;

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
