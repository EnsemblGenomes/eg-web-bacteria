package EnsEMBL::Web::SpeciesDefs;

sub species_label {
  my ($self, $key, $no_formatting) = @_;

##ENA  
  # all lowercase now
  #$key = ucfirst $key;
##ENA

  if( my $sdhash          = $self->SPECIES_DISPLAY_NAME) {
      (my $species = lc $key) =~ s/ /_/g;
      return $sdhash->{$species} if $sdhash->{$species};
  }
 
  return 'Ancestral sequence' unless $self->get_config($key, 'SPECIES_BIO_NAME');
  
  my $common = $self->get_config($key, 'SPECIES_COMMON_NAME');
  return $common;

##ENA    
#  my $rtn    = $self->get_config($key, 'SPECIES_BIO_NAME');
#  
#  $rtn = sprintf '<i>%s</i>', $rtn unless $no_formatting;
#  
#  if ($common =~ /\./) {
#    return $rtn;
#  } else {
#    return "$common ($rtn)";
#  }
##ENA   
 
}
sub production_name {
    my ($self, $species) = @_;

    $species ||= $ENV{'ENSEMBL_SPECIES'};
    return unless $species;

    return $species if ($species eq 'common');


# Try simple thing first
    if (my $sp_name = $self->get_config($species, 'SPECIES_PRODUCTION_NAME')) {
      return $sp_name;
    }

## ENA
    # nickl: The code above doesn't work for ENA - I can't see how species aliases are supposed to work here.
    # This fix looks through all the valid species for a matching common name...
    $self->{_common2production} ||= {map {lc($self->get_config($_, 'SPECIES_COMMON_NAME')) => $_} $self->valid_species}; # cache it
    if (my $production_name = $self->{_common2production}->{lc($species)}) {
      return $production_name;
    };
## ENA
  
# species name is either has not been registered as an alias, or it comes from a different website, e.g in pan compara
# then it has to appear in SPECIES_DISPLAY_NAME section of DEFAULTS ini
# check if it matches any key or any value in that section
    (my $nospaces  = $species) =~ s/ /_/g;

    if (my $sdhash = $self->SPECIES_DISPLAY_NAME) {
      return $species if exists $sdhash->{lc($species)};

      return $nospaces if exists $sdhash->{lc($nospaces)};
      my %sdrhash = map { $sdhash->{$_} => $_ } keys %{$sdhash || {}};

      (my $with_spaces  = $species) =~ s/_/ /g;
      my $sname = $sdrhash{$species} || $sdrhash{$with_spaces};
      return $sname if $sname;
    }

    return $nospaces;
}

## ENA
sub core_params { return [@{$_[0]->{'_core_params'}}, 'gene_family_id'] }
## /ENA


sub _parse {
  ### Does the actual parsing of .ini files
  ### (1) Open up the DEFAULTS.ini file(s)
  ### Foreach species open up all {species}.ini file(s)
  ###  merge in content of defaults
  ###  load data from db.packed file
  ###  make other manipulations as required
  ### Repeat for MULTI.ini
  ### Returns: boolean

  my $self = shift; 
  $CONF->{'_storage'} = {};

  $self->_info_log('Parser', 'Starting to parse tree');

  my $tree          = {};
  my $db_tree       = {};
  my $das_tree      = {};
  my $config_packer = EnsEMBL::Web::ConfigPacker->new($tree, $db_tree, $das_tree);
  
  $self->_info_line('Parser', 'Child objects attached');

  # Parse the web tree to create the static content site map
  $tree->{'STATIC_INFO'} = $self->_load_in_webtree;
  ## Parse species directories for static content
  $tree->{'SPECIES_INFO'} = $self->_load_in_species_pages;
  
  $self->_info_line('Filesystem', 'Trawled web tree');
  
  $self->_info_log('Parser', 'Parsing ini files and munging dbs');
  
  # Grab default settings first and store in defaults
  my $defaults = $self->_read_in_ini_file('DEFAULTS', {});
  $self->_info_line('Parsing', 'DEFAULTS ini file');
  
  # Loop for each species exported from SiteDefs
  # grab the contents of the ini file AND
  # IF  the DB/DAS packed files exist expand them
  # o/w attach the species databases/parse the DAS registry, 
  # load the data and store the DB/DAS packed files
  foreach my $species (@$SiteDefs::ENSEMBL_DATASETS, 'MULTI') {
    $config_packer->species($species);
    
    $self->process_ini_files($species, 'db', $config_packer, $defaults);
    $self->_merge_db_tree($tree, $db_tree, $species);
    
    if ($species ne 'MULTI') {
      $self->process_ini_files($species, 'das', $config_packer, $defaults);
      $self->_merge_db_tree($tree, $das_tree, $species);
    }
  }
  
  # Fake a databases/tables hash so we can mess around in ImageConfig with an all species configuration
  $tree->{'merged'} = $self->_created_merged_table_hash($tree);
  $self->_info_line('Creating', 'merged species config');
  $self->_info_log('Parser', 'Post processing ini files');
  
  $self->_merge_in_dhtml($tree);
  
  # Loop over each tree and make further manipulations
  foreach my $species (@$SiteDefs::ENSEMBL_DATASETS, 'MULTI') {
    $config_packer->species($species);
    $config_packer->munge('config_tree');
    $self->_info_line('munging', "$species config");
  }

  foreach my $db (@$SiteDefs::ENSEMBL_DATASETS ) {
      my @species = @{$tree->{$db}->{DB_SPECIES}};

      foreach my $sp (@species) {
          $self->_merge_species_tree( $tree->{$sp}, $tree->{$db} );
      }
  }

  $CONF->{'_storage'} = $tree; # Store the tree
}

sub _merge_species_tree {
    my ($self, $a, $b, $m) = @_;
    foreach my $key (keys %$b) {
        $a->{$key} = $b->{$key} unless exists $a->{$key};
    }
}



1;

