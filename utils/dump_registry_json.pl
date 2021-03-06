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

#
# Dump Bacteria registry JSON file
#

use strict;
use FindBin qw($Bin);
use Getopt::Long;
use lib "$Bin/../../eg-web-common/utils";
use LibDirs;
use lib "$LibDirs::SERVERROOT/ensemblgenomes-api/modules";
use lib "$LibDirs::SERVERROOT/eg-web-bacteria/modules";

use Bio::EnsEMBL::LookUp::LocalLookUp;

my ($host, $port, $user, $pass);
my $file = "$Bin/../htdocs/registry.json";

GetOptions(
  "host=s" => \$host,
  "port=s" => \$port,
  "user=s" => \$user,
  "pass=s" => \$pass,
  "file=s" => \$file
);
                                    
print "registering dbs...\n";

Bio::EnsEMBL::LookUp::LocalLookUp->register_all_dbs($host, $port, $user, $pass);

print "writing $file...\n";

my $helper = Bio::EnsEMBL::LookUp::LocalLookUp->new(-NO_CACHE => 1);
$helper->write_registry_to_file($file);

print "done\n";

#------------------------------------------------------------------------------
# Redefine Bio::EnsEMBL::LookUp->_registry_to_hash to force it to output 
# public db credentials even if we dumped from a private server.
#
# We do this so that we can dump from an internal server before the data is
# available to the publuc, but still have public-ready output.

package Bio::EnsEMBL::LookUp::LocalLookUp;
use strict;
use warnings;

sub _registry_to_hash {
  my ($self) = @_;
  # hash dbcs and dbas by locators
  my $dbc_hash;
  my $dba_hash;
  for my $dba (values %{$self->{dbas}}) {
    my $dbc_loc = _dbc_to_locator($dba->dbc());
    $dbc_hash->{$dbc_loc} = $dba->dbc();
    push @{$dba_hash->{$dbc_loc}}, $dba;
  }
  # create auxillary hashes
  my $acc_hash   = _invert_dba_hash($self->{dbas_by_vacc});
  my $name_hash  = _invert_dba_hash($self->{dbas_by_name});
  my $taxid_hash = _invert_dba_hash($self->{dbas_by_taxid});
  my $gc_hash    = _invert_dba_hash($self->{dbas_by_vgc});
  # create array of hashes
  my $out_arr;
  while (my ($dbc_loc, $dbconn) = each(%{$dbc_hash})) {
  my $dbc_h = {driver   => 'mysql',
## HACK: use public credentials
         host     => 'mysql.ebi.ac.uk',
         port     => '4157',
         username => 'anonymous',
         password => '',
##
         dbname   => $dbconn->dbname(),
         species  => []};
  for my $dba (@{$dba_hash->{$dbc_loc}}) {
    my $dba_loc = _dba_to_locator($dba);
    my $gc      = $gc_hash->{$dba_loc};
    if (ref $gc eq 'ARRAY') {
    $gc = $gc->[0];
    }
    push @{$dbc_h->{species}}, {
     species_id => $dba->species_id(),
     species    => $dba->species(),
     taxids     => $taxid_hash->{$dba_loc},
     aliases    => $name_hash->{$dba_loc},
     accessions => $acc_hash->{$dba_loc},
     gc         => $gc};
  }
  push @{$out_arr}, $dbc_h;
  }
  return $out_arr;
} ## end sub _registry_to_hash

1;

