=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Registry

=head1 SYNOPSIS

  use Bio::EnsEMBL::Registry;

  my $registry = 'Bio::EnsEMBL::Registry';

  $registry->load_all("configuration_file");

  $gene_adaptor = $registry->get_adaptor( 'Human', 'Core', 'Gene' );

=head1 DESCRIPTION

All Adaptors are stored/registered using this module. This module should
then be used to get the adaptors needed.

The registry can be loaded from a configuration file using the load_all
method.

If a filename is passed to load_all then this is used.  Else if the
environment variable ENSEMBL_REGISTRY is set to the name on an existing
configuration file, then this is used.  Else if the file .ensembl_init
in your home directory exist, it is used.

For the Web server ENSEMBL_REGISTRY should be set in SiteDefs.pm.  This
will then be passed on to load_all.


The registry can also be loaded via the method load_registry_from_db
which given a database host will load the latest versions of the Ensembl
databases from it.

The four types of registries are for db adaptors, dba adaptors, dna
adaptors and the standard type.

=head2 db

These are registries for backwards compatibility and enable the
subroutines to add other adaptors to connections.

e.g. get_all_db_adaptors, get_db_adaptor, add_db_adaptor,
remove_db_adaptor are the old DBAdaptor subroutines which are now
redirected to the Registry.

So if before we had

  my $sfa = $self->adaptor()->db()->get_db_adaptor('blast');

We now want to change this to

  my $sfa =
    Bio::EnsEMBL::Registry->get_adaptor( "human", "core", "blast" );


=head2 DBA

These are the stores for the DBAdaptors

The Registry will create all the DBConnections needed now if you set up
the configuration correctly. So instead of the old commands like

  my $db           = Bio::EnsEMBL::DBSQL::DBAdaptor->new(...);
  my $exon_adaptor = $db->get_ExonAdaptor;

we should now have just

  my $exon_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor( "human", "core", "exon" );


=head2 DNA

This is an internal Registry and allows the configuration of a dnadb.
An example here is to set the est database to get its dna data from the
core database.

  ## set the est db to use the core for getting dna data.
  # Bio::EnsEMBL::Utils::ConfigRegistry->dnadb_add( "Homo Sapiens",
  #   "core", "Homo Sapiens", "est" );


=head2 adaptors

This is the registry for all the general types of adaptors like
GeneAdaptor, ExonAdaptor, Slice Adaptor etc.

These are accessed by the get_adaptor subroutine i.e.

  my $exon_adaptor =
    Bio::EnsEMBL::Registry->get_adaptor( "human", "core", "exon" );

=head1 METHODS

=cut



package Bio::EnsEMBL::Registry;
use strict;
use warnings;


#
# General Adaptors
#

=head2 add_adaptor

  Arg [1]    : name of the species to add the adaptor to in the registry.
  Arg [2]    : name of the group to add the adaptor to in the registry.
  Arg [3]    : name of the type to add the adaptor to in the registry.
  Arg [4]    : The DBAdaptor to be added to the registry.
  Arg [5]    : (optional) Set to allow overwrites of existing adaptors.
  Example    : Bio::EnsEMBL::Registry->add_adaptor("Human", "core", "Gene", $adap);
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable

=cut

sub add_adaptor {
  my ( $class, $species, $group, $type, $adap, $reset ) = @_;

  $species = $class->get_alias($species);
  my $lc_group = lc($group);
  my $lc_type = lc($type);

  if ( !defined($registry_register{_ADAPTORS}) ) {
      $registry_register{_ADAPTORS} = [];
  }
  
  my $ref_type = ref $adap;
  my $adap_type = $ref_type eq "" ? $adap : $ref_type;
  my $idx_adaptor;
  my $ref_adaptors = $registry_register{_ADAPTORS};
  my $num_adaptors = scalar(@$ref_adaptors) / 2;
  for ( my $i = 0; $i < $num_adaptors; $i++ ) {
      if ( $ref_adaptors->[2*$i] eq $lc_type ) {
          if ( $adap_type eq $ref_adaptors->[2*$i+1] ) {
              $idx_adaptor = $i;
              last;
          }
      }
  }
  
  if ( !defined($idx_adaptor) ) {
      push(@$ref_adaptors, $lc_type);
      push(@$ref_adaptors, $adap_type);
      $idx_adaptor = $num_adaptors;
      $num_adaptors++;
  }

  my $array_size = int $num_adaptors / 64 + 1;
  if ( !defined($registry_register{_SPECIES}{$species}{$lc_group}{'adaptors'}) ) {
      $registry_register{_SPECIES}{$species}{$lc_group}{'adaptors'} = [];
      for ( my $i = 0; $i < $array_size; $i++ ) {
          $registry_register{_SPECIES}{$species}{$lc_group}{'adaptors'}->[$i] = 0;
      }
  }
  else {
      my $adaptors = $registry_register{_SPECIES}{$species}{$lc_group}{'adaptors'};
      my $current_size = scalar(@$adaptors);
      for ( my $i = $current_size; $i < $array_size; $i++ ) {
          $registry_register{_SPECIES}{$species}{$lc_group}{'adaptors'}->[$i] = 0;
      }
  }

  my $array_index = int $idx_adaptor / 64;
  my $bit_index   = $idx_adaptor % 64;
  my $bit_mask = 1 << $bit_index;
  $registry_register{_SPECIES}{$species}{$lc_group}{'adaptors'}->[$array_index] |= $bit_mask;
  
  if ( $ref_type ne "" ) {
      $registry_register{_SPECIES}{$species}{ $lc_group }{ $lc_type } = $adap;      
  }

  return;
} ## end sub add_adaptor

=head2 get_adaptor

  Arg [1]     : name of the species to add the adaptor to in the registry.
  Arg [2]     : name of the group to add the adaptor to in the registry.
  Arg [3]     : name of the type to add the adaptor to in the registry.
  Example     : $adap = Bio::EnsEMBL::Registry->get_adaptor("Human", "core", "Gene");
  Description : Finds and returns the specified adaptor. This method will also check
                if the species, group and adaptor combination satisfy a DNADB condition
                (and will return that DNADB's implementation). Also we check for 
                any available switchable adaptors and will return that if available.
  Returntype  : adaptor
  Exceptions  : Thrown if a valid internal name cannot be found for the given 
                name. If thrown check your API and DB version. Also thrown if
                no type or group was given
  Status      : Stable

=cut

sub get_adaptor {
  my ( $class, $species, $group, $type ) = @_;

  my $ispecies = $class->get_alias($species);

  if ( !defined($ispecies) ) {
    throw("Can not find internal name for species '$species'");
  }
  else { $species = $ispecies }
  
  throw 'No adaptor group given' if ! defined $group;
  throw 'No adaptor type given' if ! defined $type;

  $group = lc($group);
  my $lc_type = lc($type);
  

  if($type =~ /Adaptor$/i) {
    warning("Detected additional Adaptor string in given the type '$type'. Removing it to avoid possible issues. Alter your type to stop this message");
    $type =~ s/Adaptor$//i;
  }

  # For historical reasons, allow use of group 'regulation' to refer to
  # group 'funcgen'.
  if ( $group eq 'regulation' ) { $group = 'funcgen' }

  my %dnadb_adaptors = (
    'sequence'                 => 1,
    'assemblymapper'           => 1,
    'karyotypeband'            => 1,
    'repeatfeature'            => 1,
    'coordsystem'              => (($group ne 'funcgen') ? 1 : undef),
    'assemblyexceptionfeature' => 1
  );

  #Before looking for DNA adaptors we need to see if we have a switchable adaptor since they take preference
  if(defined $registry_register{_SWITCHABLE}{$species}{$group}{$lc_type}) {
    return $registry_register{_SWITCHABLE}{$species}{$group}{$lc_type};
  }

  # Look for a possible DNADB group alongside the species hash
  my $dnadb_group = $registry_register{_SPECIES}{$species}{ $group }{'_DNA'};

  # If we found one & this is an adaptor we should be replaced by a DNADB then
  # look up the species to use and replace the current group with the DNADB group
  # (groups are held in _DNA, species are in _DNA2)
  if ( defined($dnadb_group) && defined( $dnadb_adaptors{ $lc_type } ) ) {
    $species = $registry_register{_SPECIES}{$species}{ $group }{'_DNA2'};
    $group = $dnadb_group;

    # Once we have switched to the possibility of a DNADB call now check again for
    # a switchable adaptor
    if(defined $registry_register{_SWITCHABLE}{$species}{$group}{$lc_type}) {
      return $registry_register{_SWITCHABLE}{$species}{$group}{$lc_type};
    }  
  }

  # No switchable adaptor? Ok then continue with the normal logic
  my $ret = $registry_register{_SPECIES}{$species}{ $group }{ $lc_type };
  if ( ref($ret) )      { return $ret }

  if ( !defined($ret) ) {
      my $ref_adaptors = $registry_register{_ADAPTORS};
      my $num_adaptors = scalar(@$ref_adaptors) / 2;
      my $adaptors = $registry_register{_SPECIES}{$species}{$group}{'adaptors'};
      for ( my $i = 0; $i < $num_adaptors; $i++ ) {
          if ( (@$ref_adaptors)[2*$i] eq $lc_type ) {
              my $adaptor = (@$adaptors)[int $i/64];
              if ( $adaptor & (1 << $i) ) {
                  $ret = (@$ref_adaptors)[2*$i+1];
                  last;
              }
          }
      }
  }

  if ( !defined($ret) ) {
      return;      
  }
  
  # Not instantiated yet

  my $dba = $registry_register{_SPECIES}{$species}{ $group }{'_DB'};
  my $module = $ret;

  my $test_eval = eval "require $module"; ## no critic
  if ($@ or (!$test_eval)) {
    warning("'$module' cannot be found.\nException $@\n");
    return;
  }

  if (
    !defined(
      $registry_register{_SPECIES}{$species}{ $group }{'CHECKED'} )
    )
  {
    $registry_register{_SPECIES}{$species}{ $group }{'CHECKED'} = 1;
    $class->version_check($dba);
  }

  my $adap = "$module"->new($dba);
  Bio::EnsEMBL::Registry->add_adaptor( $species, $group, $type, $adap,
                                       'reset' );
  $ret = $adap;

  return $ret;
} ## end sub get_adaptor

=head2 get_all_adaptors

  Arg [SPECIES] : (optional) string 
                  species name to get adaptors for
  Arg [GROUP] : (optional) string 
                  group name to get adaptors for
  Arg [TYPE] : (optional) string 
                  type to get adaptors for
  Example    : @adaps = @{Bio::EnsEMBL::Registry->get_all_adaptors()};
  Returntype : ref to list of adaptors
  Exceptions : none
  Status     : Stable

=cut

sub get_all_adaptors{
  my ($class,@args)= @_;
  my ($species, $group, $type);
  my @ret=();
  my (%species_hash, %group_hash, %type_hash);


  if(@args == 1){ # Old species only one parameter
    warn("-SPECIES argument should now be used to get species adaptors");
    $species = $args[0];
  }
  else{
    # new style -SPECIES, -GROUP, -TYPE
    ($species, $group, $type) =
      rearrange([qw(SPECIES GROUP TYPE)], @args);
  }

  if(defined($species)){
    $species_hash{$species} = 1;
  }
  else{
    # get list of species
    foreach my $dba (@{$registry_register{'_DBA'}}){
      $species_hash{lc($dba->species())} = 1;
    }
  }
  if(defined($group)){
    $group_hash{$group} = 1;
  }
  else{
    foreach my $dba (@{$registry_register{'_DBA'}}){
      $group_hash{lc($dba->group())} = 1;
    }
  }

  if ( defined($type) ) {
    $type_hash{$type} = 1;
  } else {
      my $ref_adaptors = $registry_register{_ADAPTORS};
      my $num_adaptors = scalar(@$ref_adaptors) / 2;
      for ( my $i = 0; $i < $num_adaptors; $i++ ) {
          $type_hash{(@$ref_adaptors)[2*$i]} = 1;
      }      
  }

  ### NOW NEED TO INSTANTIATE BY CALLING get_adaptor
  foreach my $sp ( keys %species_hash ) {
    foreach my $gr ( keys %group_hash ) {
      foreach my $ty ( keys %type_hash ) {
        my $temp = $class->get_adaptor( $sp, $gr, $ty );
        if ( defined($temp) ) {
          push @ret, $temp;
        }
      }
    }
  }

  return (\@ret);
}

1;
