package EnsEMBL::Web::DBSQL::DBConnection;


use strict;
use warnings;
no warnings "uninitialized";
use Carp;

use Bio::EnsEMBL::Registry;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Hub;
my $reg = "Bio::EnsEMBL::Registry";


sub get_DBAdaptor {
  my $self = shift;
  my $database = shift || $self->error( 'FATAL', "Need a DBAdaptor name" );
  $database = "SNP" if $database eq "snp";
  $database = "otherfeatures" if $database eq "est";
  my $species = shift || $self->default_species();
  $self->{'_dbs'}->{$species} ||= {}; 
  my $hub = EnsEMBL::Web::Hub->new;
  
  # if we have connected to the db before, return the adaptor from the cache
  if(exists($self->{'_dbs'}->{$species}->{$database})){
    return $self->{'_dbs'}->{$species}->{$database};
  }
    
  # try to retrieve the DBAdaptor from the Registry
  my $dba = $reg->get_DBAdaptor($species, $database);
  #warn "$species - $database - $dba";

## Bacteria
  if (! $dba ) {
    my $sg = $hub->species_defs->get_config($species, "SPECIES_DATASET");
    $dba = $reg->get_DBAdaptor($sg, $database) if $sg;
  }
  
  if ($dba) {
    $dba->{_is_multispecies} = 1;
    $dba->{_species_id} = $hub->species_defs->get_config($species, "SPECIES_META_ID");
  }
##

  # Glovar
  $self->{'_dbs'}->{$species}->{$database} = $dba;

  if (!exists($self->{'_dbs'}->{$species}->{$database})) {
    return undef;
  }
  return $self->{'_dbs'}->{$species}->{$database};
}


1;
