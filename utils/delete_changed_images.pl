#!/usr/local/bin/perl
# Copyright [2009-2024] EMBL-European Bioinformatics Institute
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


# This script will download the lists of deleted/changed bacteria species from the pre-release 
# FTP dir, then delete the corresponding karyo images so that they can be re-generated.
# RUN THIS SCRIPT FROM THE SERVER ROOT DIR,  
# E.g.
# perl eg-web-bacteria/utils/delete_changed_images.pl --release=26

use strict;
use warnings;
use File::Slurp ;
use Getopt::Long;

my @species;
my $release;
my $image_dir = './eg-web-bacteria/htdocs/img/species';
my @files = qw(
  new_genomes.txt
  removed_genomes.txt
  renamed_genomes.txt
  updated_annotations.txt
  updated_assemblies.txt 
);

GetOptions(
  "release=i"   => \$release,
  "image-dir=s" => \$image_dir,
);

die "Usage: delete_changed_images.pl --release=26" unless $release;
die "Image dir not found ($image_dir)" unless -d $image_dir;

foreach (@files) {
  `curl https://ftp.ensemblgenomes.ebi.ac.uk/pub/.release-$release/bacteria/$_ > /tmp/$_`;
  my @lines = read_file( "/tmp/$_" );
  shift @lines; # remove header row
  push @species, map {[split /\s+/]->[0]} @lines;   
}

print `rm -v $image_dir/region_$_*.png` for @species;

1;

