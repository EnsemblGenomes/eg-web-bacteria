=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ConfigPacker;

use strict;
use warnings;
no warnings qw(uninitialized);

use Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;
use Bio::EnsEMBL::ExternalData::DAS::SourceParser;
use Data::Dumper;


sub _summarise_generic {
  my( $self, $db_name, $dbh ) = @_;

  my $t_aref = $dbh->selectall_arrayref( 'show table status' );
#---------- Table existance and row counts
  foreach my $row ( @$t_aref ) {
    $self->db_details($db_name)->{'tables'}{$row->[0]}{'rows'} = $row->[4];
  }
#---------- Meta coord system table...
  if( $self->_table_exists( $db_name, 'meta_coord' )) {
    $t_aref = $dbh->selectall_arrayref(
      'select table_name,max_length
         from meta_coord'
    );
    foreach my $row ( @$t_aref ) {
      $self->db_details($db_name)->{'tables'}{$row->[0]}{'coord_systems'}{$row->[1]}=$row->[2];
    }
  }
#---------- Meta table (everything except patches)
## Needs tweaking to work with new ensembl_ontology_xx db, which has no species_id in meta table
  if( $self->_table_exists( $db_name, 'meta' ) ) {
    my $hash = {};

# With multi species DB there is no way to define the list of chromosomes for the karyotype in the ini file
# The idea is the people who produce the DB can define the lists in the meta table using region.toplevel met key
# In case there is no such definition of the karyotype - we just create the lists of toplevel regions 
    if( $db_name =~ /CORE/) {
        my $t_aref = $dbh->selectall_arrayref(
					      qq{SELECT cs.species_id, s.name FROM seq_region s, coord_system cs
WHERE s.coord_system_id = cs.coord_system_id and cs.attrib = 'default_version' and cs.name in ('plasmid', 'chromosome')
ORDER by cs.species_id, s.seq_region_id}
					      );

        foreach my $row ( @$t_aref ) {
            push @{$hash->{$row->[0]}{'region.toplevel'}}, $row->[1];
        }
    }

    $t_aref  = $dbh->selectall_arrayref(
      'select meta_key,meta_value,meta_id, species_id
         from meta
        where meta_key != "patch"
        order by meta_key, meta_id'
    );

    foreach my $r( @$t_aref) {
      push @{ $hash->{$r->[3]+0}{$r->[0]}}, $r->[1];
    }
    $self->db_details($db_name)->{'meta_info'} = $hash;
  }
}

sub _summarise_core_tables {
  my $self   = shift;
  my $db_key = shift;
  my $db_name = shift; 
  my $dbh    = $self->db_connect( $db_name ); 
  return unless $dbh; 
  
  push @{ $self->db_tree->{'core_like_databases'} }, $db_name;

  $self->_summarise_generic( $db_name, $dbh );
##
## Grab each of the analyses - will use these in a moment...
##
  my $t_aref = $dbh->selectall_arrayref(
    'select a.analysis_id, lower(a.logic_name), a.created,
            ad.display_label, ad.description,
            ad.displayable, ad.web_data
       from analysis a left join analysis_description as ad on a.analysis_id=ad.analysis_id'
  );
  my $analysis = {};
  foreach my $a_aref (@$t_aref) { 
    ## Strip out "crap" at front and end! probably some q(')s...
    ( my $A = $a_aref->[6] ) =~ s/^[^{]+//;
    $A =~ s/[^}]+$//;
    my $T = eval($A);
    if (ref($T) ne 'HASH') {
      if ($A) {
	warn "Deleting web_data for $db_key:".$a_aref->[1].", check for syntax error";
      }
      $T = {};
    }
    $analysis->{ $a_aref->[0] } = {
      'logic_name'  => $a_aref->[1],
      'name'        => $a_aref->[3],
      'description' => $a_aref->[4],
      'displayable' => $a_aref->[5],
      'web_data'    => $T
    };
  }
  ## Set last repeat mask date whilst we're at it, as needed by BLAST configuration, below
  my $r_aref = $dbh->selectall_arrayref( 
      'select max(date_format( created, "%Y%m%d"))
      from analysis, meta
      where logic_name = meta_value and meta_key = "repeat.analysis"' 
  );
  my $date;
  foreach my $a_aref (@$r_aref){
    $date = $a_aref->[0];
  } 
  if ($date) { $self->db_tree->{'REPEAT_MASK_DATE'} = $date; } 

  #get website version the db was first released on - needed for Vega BLAST auto configuration
  (my $initial_release) = $dbh->selectrow_array(qq(SELECT meta_value FROM meta WHERE meta_key = 'initial_release.version'));
  if ($initial_release) { $self->db_tree->{'DB_RELEASE_VERSION'} = $initial_release; }

## 
## Let us get analysis information about each feature type...
##
  foreach my $table ( qw(
	dna_align_feature protein_align_feature simple_feature
        protein_feature marker_feature
	repeat_feature ditag_feature 
        transcript gene prediction_transcript unmapped_object
  )) { 
    my $res_aref = $dbh->selectall_arrayref(
      "select analysis_id,count(*) from $table group by analysis_id"
    );
    foreach my $T ( @$res_aref ) {
      my $a_ref = $analysis->{$T->[0]}
        || ( warn("Missing analysis entry $table - $T->[0]\n") && next );
      my $value = {
        'name'  => $a_ref->{'name'},
        'desc'  => $a_ref->{'description'},
        'disp'  => $a_ref->{'displayable'},
        'web'   => $a_ref->{'web_data'},
        'count' => $T->[1]
      };
      $self->db_details($db_name)->{'tables'}{$table}{'analyses'}{$a_ref->{'logic_name'}} = $value;
    }
  }

#---------- Additional queries - by type...

#
# * Check to see if we have any interpro? - not sure why may drop...
#

#
# * Repeats
#
  $t_aref = $dbh->selectall_arrayref(
    'select rf.analysis_id,rc.repeat_type, count(*)
       from repeat_consensus as rc, repeat_feature as rf
      where rc.repeat_consensus_id = rf.repeat_consensus_id
      group by analysis_id, repeat_type'
  );
  foreach my $row (@$t_aref) {
    my $a_ref = $analysis->{$row->[0]};
    $self->db_details($db_name)->{'tables'}{'repeat_feature'}{'analyses'}{$a_ref->{'logic_name'}}{'types'}{$row->[1]} = $row->[2];
  }
#
# * Misc-sets
#
  $t_aref = $dbh->selectall_arrayref(
    'select ms.code, ms.name, ms.description, count(*) as N, ms.max_length
       from misc_set as ms, misc_feature_misc_set as mfms
      where mfms.misc_set_id = ms.misc_set_id
      group by ms.misc_set_id'
  );
  $self->db_details($db_name)->{'tables'}{'misc_feature'}{'sets'} = { map {
    ( $_->[0] => { 'name' => $_->[1], 'desc' => $_->[2], 'count' => $_->[3], 'max_length' => $_->[4] })
  } @$t_aref };

#
# * External-db
#
  my $sth = $dbh->prepare(qq(select * from external_db));
  $sth->execute;
  my $hashref;
  while ( my $t =  $sth->fetchrow_hashref) {
    $hashref->{$t->{'external_db_id'}} = $t;
  }
  $self->db_details($db_name)->{'tables'}{'external_db'}{'entries'} = $hashref;

#---------- Now for the core only ones.......

  if( $db_key eq 'core' ) {
#
# * Co-ordinate systems..
#

    my $aref =  $dbh->selectall_arrayref(
      'select sr.name, sr.length 
         from seq_region as sr, coord_system as cs 
        where cs.name in( "chromosome", "group" ) and
              cs.coord_system_id = sr.coord_system_id' 
    );
    $self->db_tree->{'MAX_CHR_NAME'  } = undef;
    $self->db_tree->{'MAX_CHR_LENGTH'} = undef;
    my $max_length = 0;
    my $max_name;
    foreach my $row (@$aref) {
      $self->db_tree->{'ALL_CHROMOSOMES'}{$row->[0]} = $row->[1];
      if( $row->[1] > $max_length ) {
        $max_name = $row->[0];
        $max_length = $row->[1];
      }
    }
    $self->db_tree->{'MAX_CHR_NAME'  } = $max_name;
    $self->db_tree->{'MAX_CHR_LENGTH'} = $max_length;

#
# * Ontologies
#
    my $oref =  $dbh->selectall_arrayref(
     'select distinct(db_name) from ontology_xref
       left join object_xref using(object_xref_id)
        left join xref using(xref_id)
         left join external_db using(external_db_id)'
                                         );
    foreach my $row (@$oref) {
        push @{$self->db_tree->{'SPECIES_ONTOLOGIES'}}, $row->[0];
    }

  }

$self->db_tree->{'ASSEMBLY_VERSION'} = ''; # must be non-null for BLAST ticket ORM

## EG - it doesn't *look* like this is still needed, so I've dropped it to help slim down
##      Bacteria's bloated configs
# #---------------
# #
# # * Assemblies...
# # This is a bit ugly, because there's no easy way to sort the assemblies via MySQL
#   $t_aref = $dbh->selectall_arrayref(
#     'select version, attrib from coord_system where version is not null' 
#   );
#   my (%default, %not_default);
#   foreach my $row (@$t_aref) {
#     my $version = $row->[0];
#     my $attrib = $row->[1];
#     if ($attrib =~ /default_version/) {
#       $default{$version}++;
#     }
#     else {
#       $not_default{$version}++;
#     }
#   }
#   my @assemblies = keys %default;
#   push @assemblies, sort keys %not_default;
#   $self->db_tree->{'CURRENT_ASSEMBLIES'} = join(',', @assemblies);
## EG

#----------
  $dbh->disconnect();
}

sub _summarise_funcgen_db {
  my($self, $db_key, $db_name) = @_;
  my $dbh  = $self->db_connect( $db_name );
  return unless $dbh;
  push @{ $self->db_tree->{'funcgen_like_databases'} }, $db_name;
  $self->_summarise_generic( $db_name, $dbh );
##
## Grab each of the analyses - will use these in a moment...
##
  my $t_aref = $dbh->selectall_arrayref(
    'select a.analysis_id, a.logic_name, a.created,
            ad.display_label, ad.description,
            ad.displayable, ad.web_data
       from analysis a left join analysis_description as ad on a.analysis_id=ad.analysis_id'
  );
  my $analysis = {};
  foreach my $a_aref (@$t_aref) {
## Strip out "crap" at front and end! probably some q(')s...
    ( my $A = $a_aref->[6] ) =~ s/^[^{]+//;
    $A =~ s/[^}]+$//;
    my $T = eval($A);

    $T = {} unless ref($T) eq 'HASH';
    $analysis->{ $a_aref->[0] } = {
      'logic_name'  => $a_aref->[1],
      'name'        => $a_aref->[3],
      'description' => $a_aref->[4],
      'displayable' => $a_aref->[5],
      'web_data'    => $T
    };
  }

##
## Let us get analysis information about each feature type...
##
  foreach my $table ( qw(
   probe_feature feature_set result_set 
  )) {
    my $res_aref = $dbh->selectall_arrayref(
      "select analysis_id,count(*) from $table group by analysis_id"
    );
    foreach my $T ( @$res_aref ) {
      my $a_ref = $analysis->{$T->[0]};
        #|| ( warn("Missing analysis entry $table - $T->[0]\n") && next );
      my $value = {
        'name'  => $a_ref->{'name'},
        'desc'  => $a_ref->{'description'},
        'disp'  => $a_ref->{'displayable'},
        'web'   => $a_ref->{'web_data'},
        'count' => $T->[1]
      }; 
      $self->db_details($db_name)->{'tables'}{$table}{'analyses'}{$a_ref->{'logic_name'}} = $value;
    }
  }

###
### Store the external feature sets available for each species
###
  my @feature_sets;
  my $f_aref = $dbh->selectall_arrayref(
    "select name
      from feature_set
      where type = 'external'"
  );
  foreach my $F ( @$f_aref ){ push (@feature_sets, $F->[0]); }  
  $self->db_tree->{'databases'}{'DATABASE_FUNCGEN'}{'FEATURE_SETS'} = \@feature_sets;


#---------- Additional queries - by type...

#
# * Oligos
#
#  $t_aref = $dbh->selectall_arrayref(
#    'select a.vendor, a.name,count(*)
#       from array as a, array_chip as c straight_join probe as p on
#            c.array_chip_id=p.array_chip_id straight_join probe_feature f on
#            p.probe_id=f.probe_id where a.name = c.name
#      group by a.name'
#  );

  $t_aref = $dbh->selectall_arrayref(
    'select a.vendor, a.name, a.array_id  
       from array a, array_chip c, status s, status_name sn where  sn.name="DISPLAYABLE" 
       and sn.status_name_id=s.status_name_id and s.table_name="array" and s.table_id=a.array_id 
       and a.array_id=c.array_id
    '       
  );
  my $sth = $dbh->prepare(
    'select pf.probe_feature_id
       from array_chip ac, probe p, probe_feature pf, seq_region sr, coord_system cs
       where ac.array_chip_id=p.array_chip_id and p.probe_id=pf.probe_id  
       and pf.seq_region_id=sr.seq_region_id and sr.coord_system_id=cs.coord_system_id 
       and cs.is_current=1 and ac.array_id = ?
       limit 1 
    '
  );
  foreach my $row (@$t_aref) {
    my $array_name = $row->[0] .':'. $row->[1];
    $sth->bind_param(1, $row->[2]);
    $sth->execute;
    my $count = $sth->fetchrow_array();# warn $array_name ." ". $count;
    if( exists $self->db_details($db_name)->{'tables'}{'oligo_feature'}{'arrays'}{$array_name} ) {
      warn "FOUND";
    }
    $self->db_details($db_name)->{'tables'}{'oligo_feature'}{'arrays'}{$array_name} = $count ? 1 : 0;
  }
  $sth->finish;
#
# * functional genomics tracks
#

  $f_aref = $dbh->selectall_arrayref(
    'select ft.name, ct.name 
       from supporting_set ss, data_set ds, feature_set fs, feature_type ft, cell_type ct  
       where ds.data_set_id=ss.data_set_id and ds.name="RegulatoryFeatures" 
       and fs.feature_set_id = ss.supporting_set_id and fs.feature_type_id=ft.feature_type_id 
       and fs.cell_type_id=ct.cell_type_id 
       order by ft.name;
    '
  );   
  foreach my $row (@$f_aref) {
    my $feature_type_key =  $row->[0] .':'. $row->[1];
    $self->db_details($db_name)->{'tables'}{'feature_type'}{'analyses'}{$feature_type_key} = 2;   
  }


  $dbh->disconnect();
}

#========================================================================#
# The following functions munge the multi-species databases              #
#========================================================================#

sub _munge_meta {
  my $self = shift;

  my %keys = qw(
    species.taxonomy_id           TAXONOMY_ID
    species.display_name          SPECIES_COMMON_NAME
    species.production_name       SPECIES_PRODUCTION_NAME
    species.scientific_name       SPECIES_SCIENTIFIC_NAME
    assembly.accession            ASSEMBLY_ACCESSION
    assembly.web_accession_source ASSEMBLY_ACCESSION_SOURCE
    assembly.web_accession_type   ASSEMBLY_ACCESSION_TYPE
    assembly.default              ASSEMBLY_NAME
    assembly.name                 ASSEMBLY_DISPLAY_NAME
    liftover.mapping              ASSEMBLY_MAPPINGS
    genebuild.method              GENEBUILD_METHOD
    provider.name                 PROVIDER_NAME
    provider.url                  PROVIDER_URL
    provider.logo                 PROVIDER_LOGO
    species.strain                SPECIES_STRAIN
    species.sql_name              SYSTEM_NAME
    species.biomart_dataset       BIOMART_DATASET
    species.alias                 SPECIES_ALIAS
  );

  my @months = qw(blank Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my $meta_info = $self->_meta_info('DATABASE_CORE') || {};
  my @sp_count = grep {$_ > 0} keys %$meta_info;
  
  ## How many species in database?
  $self->tree->{'SPP_IN_DB'} = scalar @sp_count;

  if (scalar(@sp_count) > 1) {
    if ($meta_info->{0}{'species.group'}) {
      $self->tree->{'DISPLAY_NAME'} = $meta_info->{0}{'species.group'};
    }
    else {
      (my $group_name = $self->{'_species'}) =~ s/_collection//;
      $self->tree->{'DISPLAY_NAME'} = $group_name;
    }
  }
  else {
    $self->tree->{'DISPLAY_NAME'} = $meta_info->{1}{'species.display_name'}[0];
  }

  while (my ($species_id, $meta_hash) = each (%$meta_info)) {
#      warn "\t $species_id ::  $meta_hash->{'species.sql_name'}->[0] \n";
    next unless $species_id && $meta_hash && ref($meta_hash) eq 'HASH';

    ## Do species name and group
    my ($bioname, $bioshort);
    my $taxonomy = $meta_hash->{'species.classification'};
    my $species = $meta_hash->{'species.production_name'}->[0] || $meta_hash->{'species.compara_name'}->[0] || $meta_hash->{'species.display_name'}->[0];
    $species =~ s/ /_/g;


    if ($taxonomy && scalar(@$taxonomy)) {
      $species ||= $taxonomy->[1].'_'.$taxonomy->[0];
#      $bioname = $taxonomy->[1].' '.$taxonomy->[0];
      $bioname = $taxonomy->[0];
#      $bioshort = substr($taxonomy->[1],0,1).'.'.$taxonomy->[0];
     $bioshort = substr($taxonomy->[0],0,1).' '.substr($taxonomy->[0], index($taxonomy->[0], ' '));

      my $order = $self->tree->{'TAXON_ORDER'};
      foreach my $taxon (@$taxonomy) {
        foreach my $group (@$order) {
          if ($taxon eq $group) {
            $self->tree->{$species}{'SPECIES_GROUP'} = $group;
            last;
          }
        }
        last if $self->tree->{$species}{'SPECIES_GROUP'};
      }
    }
    else {
      ## Default to same name as database 
      $species = $self->{'_species'};
      ($bioname = $species) =~ s/_/ /g;
      ($bioshort = $bioname) =~ s/^([A-Z])[a-z]+_([a-z]+)$/$1.$2/;
    }
    $self->tree->{$species}{'SPECIES_BIO_NAME'} = $bioname;
    $self->tree($species)->{'SPECIES_BIO_NAME'} = $bioname;
    $self->tree->{$species}{'SPECIES_BIO_SHORT'} = $bioshort;
    $self->tree->{$species}{'SYSTEM_NAME'} = $species;
    $self->tree($species)->{'SYSTEM_NAME'} = $species;

    $self->tree->{lc($species)}{'SYSTEM_NAME'} = $species;
    $self->tree(lc($species))->{'SYSTEM_NAME'} = $species;

 #   if ($self->tree->{'ENSEMBL_SPECIES'}) {
      push @{$self->tree->{'DB_SPECIES'}}, $species;
 #   }
 #   else {
#      $self->tree->{'DB_SPECIES'} = [$species];
 #   }

    ## Get assembly info 
    while (my ($meta_key, $key) = each (%keys)) {
      next unless $meta_hash->{$meta_key};
      my $value = scalar(@{$meta_hash->{$meta_key}}) > 1 ? $meta_hash->{$meta_key} : $meta_hash->{$meta_key}[0]; 

      $self->tree->{$species}{$key} = $value;
      $self->tree($species)->{$key} = $value;
    }
    $self->tree->{$species}{'SPECIES_META_ID'} = $species_id;
    $self->tree($species)->{'SPECIES_META_ID'} = $species_id;
    ## Munge genebuild info
#    my $gb_start = $meta_hash->{'genebuild.start_date'}[0];
    my $gb_start = $meta_hash->{'genebuild.version'}[0];
    my @A = split('-', $gb_start);
    $self->tree->{$species}{'GENEBUILD_START'} = $months[$A[1]].' '.$A[0];
    $self->tree->{$species}{'GENEBUILD_DATE'} = $months[$A[1]].' '.$A[0];
    $self->tree->{$species}{'GENEBUILD_BY'} = $A[2];

    $self->tree($species)->{'GENEBUILD_START'} = $months[$A[1]].' '.$A[0];
    $self->tree($species)->{'GENEBUILD_DATE'} = $months[$A[1]].' '.$A[0];
    $self->tree($species)->{'GENEBUILD_BY'} = $A[2];

    my $gb_release = $meta_hash->{'genebuild.initial_release_date'}[0];
    @A = split('-', $gb_release);
    $self->tree->{$species}{'GENEBUILD_RELEASE'} = $months[$A[1]].' '.$A[0];
    my $gb_latest = $meta_hash->{'genebuild.last_geneset_update'}[0];
    @A = split('-', $gb_latest);
    $self->tree->{$species}{'GENEBUILD_LATEST'} = $months[$A[1]].' '.$A[0];
    my $assembly_date = $meta_hash->{'assembly.date'}[0];
    @A = split('-', $assembly_date);
    $self->tree->{$species}{'ASSEMBLY_DATE'} = $months[$A[1]].' '.$A[0];

# check if there are sample search entries defined in meta table ( the case with Ensembl Genomes)
# they can be overwritten at a later stage  via INI files
    my @ks = grep { /^sample\./ } keys %{$meta_hash || {}};
    my $shash;

    foreach my $k (@ks) {
        (my $k1 = $k) =~ s/^sample\.//;
        $shash->{ uc($k1) } = $meta_hash->{$k}->[0];
    }

    $self->tree($species)->{SAMPLE_DATA} = $shash if ($shash);
# check if the karyotype/list of toplevel regions ( normally chroosomes) is defined in meta table
    @{$self->tree($species)->{'TOPLEVEL_REGIONS'}} = @{$meta_hash->{'region.toplevel'}} if $meta_hash->{'region.toplevel'};
    @{$self->tree($species)->{'ENSEMBL_CHROMOSOMES'}} = (); #nickl: need to explicitly define as empty array by default otherwise SpeciesDefs looks for a value at collection level
    @{$self->tree($species)->{'ENSEMBL_CHROMOSOMES'}} = @{$meta_hash->{'region.toplevel'}} if $meta_hash->{'region.toplevel'};

    #If the top level regions are other than palsmid or chromosome, ENSEMBL_CHROMOSOMES is set to an empty array 
    #in order to disable the 'Karyotype' and 'Chromosome summary' links in the menu tree 
    if ($meta_hash->{'region.toplevel'}) {

      my $db_name = 'DATABASE_CORE';
      my $dbh  = $self->db_connect( $db_name );
   
      #it's sufficient to check just the first elem, assuming the list doesn't contain a mixture of plasmid/chromosome and other than plasmid/chromosome regions:  
      my $sname = $meta_hash->{'region.toplevel'}->[0]; 
      my $t_aref = $dbh->selectall_arrayref("select       
        coord_system.name, 
        seq_region.name
        from 
        meta, 
        coord_system, 
        seq_region, 
        seq_region_attrib
        where 
        coord_system.coord_system_id = seq_region.coord_system_id
        and seq_region_attrib.seq_region_id = seq_region.seq_region_id
        and seq_region_attrib.attrib_type_id =  (SELECT attrib_type_id FROM attrib_type where name = 'Top Level') 
        and meta.species_id=coord_system.species_id 
        and meta.meta_key = 'species.production_name'
        and meta.meta_value = '".$species."'
        and seq_region.name = '".$sname."'
        and coord_system.name not in ('plasmid', 'chromosome')") || [];

      if (@$t_aref) {
        @{$self->tree($species)->{'ENSEMBL_CHROMOSOMES'}} = ();
      }
    }

    (my $group_name = $self->{'_species'}) =~ s/_collection//;

    $self->tree($species)->{'SPECIES_DATASET'} = $group_name;
    $self->tree->{$species}{'SPECIES_DATASET'} = $group_name;

  }

  #  munge EG genome info 
  my $metadata_db = $self->full_tree->{MULTI}->{databases}->{DATABASE_METADATA};

  if ($metadata_db) {
    my $dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(
      -USER   => $metadata_db->{USER},
      -PASS   => $metadata_db->{PASS},
      -PORT   => $metadata_db->{PORT},
      -HOST   => $metadata_db->{HOST},
      -DBNAME => $metadata_db->{NAME}
    );

    my $genome_info_adaptor = Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->new(-DBC => $dbc);
    
    if ($genome_info_adaptor) {
      my $dbname = $self->tree->{databases}->{DATABASE_CORE}->{NAME};
      foreach my $genome (@{ $genome_info_adaptor->fetch_all_by_dbname($dbname) }) {
        my $species = $genome->species;
        $self->tree($species)->{'SEROTYPE'}     = $genome->serotype;
        $self->tree($species)->{'PUBLICATIONS'} = $genome->publications;
      }
    }
  } 
}

sub _configure_blast {
  my $self = shift;
$DB::single = 1;
  my $tree = $self->tree;
  my $species = $self->species;

  my $assembly = $tree->{$species}{'ASSEMBLY_NAME'};

  $species =~ s/ /_/g;
  my $method = $self->full_tree->{'MULTI'}{'ENSEMBL_BLAST_METHODS'};



  my %valid_species = map {($_,1)} keys %{$self->full_tree};
  my $vhash;

  foreach my $vs (sort keys %valid_species) {
      ref $self->tree($vs) eq 'HASH' or next; 
      my $sname = $self->tree($vs)->{SYSTEM_NAME} || next;
      next if ($vhash->{$sname});
      $vhash->{$sname} = 1;

      foreach my $blast_type (keys %$method) { ## BLASTN, BLASTP, BLAT, etc
	  next unless ref($method->{$blast_type}) eq 'ARRAY';
	  my @method_info = @{$method->{$blast_type}};
	  my $search_type = uc($method_info[0]); ## BLAST or BLAT at the moment
#	  warn "ST : $blast_type : $search_type \n";
	  my $sources = $self->full_tree->{'MULTI'}{$search_type.'_DATASOURCES'};
#	  warn Dumper $sources;

	  $self->tree($sname)->{$blast_type.'_DATASOURCES'}{'DATASOURCE_TYPE'} = $method_info[1]; ## dna or peptide

	  my $db_type = $method_info[2]; ## dna or peptide
	  foreach my $source_type (keys %$sources) { ## CDNA_ALL, PEP_ALL, etc
	      next if $source_type eq 'DEFAULT';
	      next if ($db_type eq 'dna' && $source_type =~ /^PEP/);
	      next if ($db_type eq 'peptide' && $source_type !~ /^PEP/);
	      if ($source_type eq 'CDNA_ABINITIO') { ## Does this species have prediction transcripts?
		  next unless 1;
	      }
	      elsif ($source_type eq 'RNA_NC') { ## Does this species have RNA data?
		  next unless 1;
	      }
	      elsif ($source_type eq 'PEP_KNOWN') { ## Does this species have species-specific protein data?
		  next unless 1;
	      }

	      my $assembly = $self->tree($vs)->{'ASSEMBLY_NAME'};

	      (my $type = lc($source_type)) =~ s/_/\./ ;
	      my $version =  $SiteDefs::ENSEMBL_VERSION -1; ### -1 for debug 
	      
	      if ($type =~ /latestgp/) {
		  if ($search_type ne 'BLAT') {
		      $type =~ s/latestgp(.*)/dna$1\.toplevel/;
		      $type =~ s/.masked/_rm/;
		      my $repeat_date = $self->db_tree->{'REPEAT_MASK_DATE'};;
#		      my $file = sprintf( '%s.%s.%s.%s', $sname, $assembly, $version, $type ).".fa";
	              my $file = sprintf( '%s.%s.%s', $sname, $assembly, $type ).".fa";
#		      warn "AUTOGENERATING $source_type......$file\t";
		      $self->tree($sname)->{$blast_type.'_DATASOURCES'}{$source_type} = $file;
		  }
	      } 
	      else {
		  $type = "ncrna" if $type eq 'rna.nc';
	#	  my $file = sprintf( '%s.%s.%s', $sname, $assembly, $version, $type ).".fa";
		  my $file = sprintf( '%s.%s.%s', $sname, $assembly, $type ).".fa";
#		  warn "AUTOGENERATING $source_type......$file\t";
		  $self->tree($sname)->{$blast_type.'_DATASOURCES'}{$source_type} = $file;
	      }
	  }
      }
  }
}

# Remove ucfirst 
sub _summarise_compara_db {
  my ($self, $code, $db_name) = @_;
  
  my $dbh = $self->db_connect($db_name);
  return unless $dbh;
  
  push @{$self->db_tree->{'compara_like_databases'}}, $db_name;

  $self->_summarise_generic($db_name, $dbh);
  
  # Lets first look at all the multiple alignments
  ## We've done the DB hash...So lets get on with the multiple alignment hash;
  my $res_aref = $dbh->selectall_arrayref('
    select ml.class, ml.type, gd.name, mlss.name, mlss.method_link_species_set_id, ss.species_set_id
      from method_link ml, 
        method_link_species_set mlss, 
        genome_db gd, species_set ss 
      where mlss.method_link_id = ml.method_link_id and
        mlss.species_set_id = ss.species_set_id and 
        ss.genome_db_id = gd.genome_db_id and
        (ml.class like "GenomicAlign%" or ml.class like "%.constrained_element" or ml.class = "ConservationScore.conservation_score")
  ');
  
  my $constrained_elements = {};
  my %valid_species = map {($_, 1)} keys %{$self->full_tree};
  
  foreach my $row (@$res_aref) {
#    my ($class, $type, $species, $name, $id, $species_set_id) = ($row->[0], uc $row->[1], ucfirst $row->[2], $row->[3], $row->[4], $row->[5]);
    my ($class, $type, $species, $name, $id, $species_set_id) = ($row->[0], uc $row->[1], $row->[2], $row->[3], $row->[4], $row->[5]);
    my $key = 'ALIGNMENTS';
    
    if ($class =~ /ConservationScore/ || $type =~ /CONSERVATION_SCORE/) {
      $key  = 'CONSERVATION_SCORES';
      $name = 'Conservation scores';
    } elsif ($class =~ /constrained_element/ || $type =~ /CONSTRAINED_ELEMENT/) {
      $key = 'CONSTRAINED_ELEMENTS';
      $constrained_elements->{$species_set_id} = $id;
    } elsif ($type !~ /EPO_LOW_COVERAGE/ && ($class =~ /tree_alignment/ || $type  =~ /EPO/)) {
      $self->db_tree->{$db_name}{$key}{$id}{'species'}{'ancestral_sequences'} = 1 unless exists $self->db_tree->{$db_name}{$key}{$id};
    }
    
    $species =~ tr/ /_/;
    
    $self->db_tree->{$db_name}{$key}{$id}{'id'}                = $id;
    $self->db_tree->{$db_name}{$key}{$id}{'name'}              = $name;
    $self->db_tree->{$db_name}{$key}{$id}{'type'}              = $type;
    $self->db_tree->{$db_name}{$key}{$id}{'class'}             = $class;
    $self->db_tree->{$db_name}{$key}{$id}{'species_set_id'}    = $species_set_id;
    $self->db_tree->{$db_name}{$key}{$id}{'species'}{$species} = 1;
  }
  
  foreach my $species_set_id (keys %$constrained_elements) {
    my $constr_elem_id = $constrained_elements->{$species_set_id};
    
    foreach my $id (keys %{$self->db_tree->{$db_name}{'ALIGNMENTS'}}) {
      $self->db_tree->{$db_name}{'ALIGNMENTS'}{$id}{'constrained_element'} = $constr_elem_id if $self->db_tree->{$db_name}{'ALIGNMENTS'}{$id}{'species_set_id'} == $species_set_id;
    }
  }

  $res_aref = $dbh->selectall_arrayref('select meta_key, meta_value FROM meta where meta_key LIKE "gerp_%"');
  
  foreach my $row (@$res_aref) {
    my ($meta_key, $meta_value) = ($row->[0], $row->[1]);
    my ($conservation_score_id) = $meta_key =~ /gerp_(\d+)/;
    
    next unless $conservation_score_id;
    
    $self->db_tree->{$db_name}{'ALIGNMENTS'}{$meta_value}{'conservation_score'} = $conservation_score_id;
  }
  
  my %sections = (
    ENSEMBL_ORTHOLOGUES => 'GENE',
    HOMOLOGOUS_GENE     => 'GENE',
    HOMOLOGOUS          => 'GENE',
  );
  
  # We've done the DB hash... So lets get on with the DNA, SYNTENY and GENE hashes;

## ENA - this query returns >25million rows for ENA and we don't need it!
  $res_aref = [];
#  $res_aref = $dbh->selectall_arrayref('
#    select ml.type, gd1.name, gd2.name
#      from genome_db gd1, genome_db gd2, species_set ss1, species_set ss2,
#       method_link ml, method_link_species_set mls1,
#       method_link_species_set mls2
#     where mls1.method_link_species_set_id = mls2.method_link_species_set_id and
#       ml.method_link_id = mls1.method_link_id and
#       ml.method_link_id = mls2.method_link_id and
#       gd1.genome_db_id != gd2.genome_db_id and
#       mls1.species_set_id = ss1.species_set_id and
#       mls2.species_set_id = ss2.species_set_id and
#       ss1.genome_db_id = gd1.genome_db_id and
#       ss2.genome_db_id = gd2.genome_db_id
#  ');
## /ENA

  # See if there are any intraspecies alignments (ie a self compara)
  my %config;
  my $q = q{
    select ml.type, gd.name, gd.name, count(*) as count
      from method_link_species_set as mls, 
        method_link as ml, species_set as ss, genome_db as gd 
      where mls.species_set_id = ss.species_set_id
        and ss.genome_db_id = gd.genome_db_id 
        and mls.method_link_id = ml.method_link_id
        and ml.type not like '%PARALOGUES'
      group by mls.method_link_species_set_id, mls.method_link_id
      having count = 1
  };
  
  my $sth       = $dbh->prepare($q);
  my $rv        = $sth->execute || die $sth->errstr;
  my $v_results = $sth->fetchall_arrayref;
  
  # if there are intraspecies alignments then get full details of all genomic alignments, ie start and stop
  # currently these are only needed for Vega where there are only strictly defined regions in compara
  # but this could be extended to e! if we needed to know this
  if (scalar @$v_results) {
    # get details of seq_regions in the database
    $q = '
      select df.dnafrag_id, df.name, df.coord_system_name, gdb.name
        from dnafrag df, genome_db gdb
        where df.genome_db_id = gdb.genome_db_id
    ';
    
    $sth = $dbh->prepare($q);
    $rv  = $sth->execute || die $sth->errstr;
    
    my %genomic_regions;
    
    while (my ($dnafrag_id, $sr, $coord_system, $species) = $sth->fetchrow_array) {
      $species =~ s/ /_/;
      
      $genomic_regions{$dnafrag_id} = {
        species      => $species,
        seq_region   => $sr,
        coord_system => $coord_system,
      };
    }
    
#    warn "genomic regions are ",Dumper(\%genomic_regions);

    # get details of methods in the database -
    $q = '
      select mlss.method_link_species_set_id, ml.type, mlss.name
        from method_link_species_set mlss, method_link ml
        where mlss.method_link_id = ml.method_link_id
    ';
    
    $sth = $dbh->prepare($q);
    $rv  = $sth->execute || die $sth->errstr;
    my (%methods, %names);
    
    while (my ($mlss, $type, $name) = $sth->fetchrow_array) {
      $methods{$mlss} = $type;
      $names{$mlss}   = $name;
    }
    
    # get details of alignments
    $q = '
      select genomic_align_block_id, method_link_species_set_id, dnafrag_start, dnafrag_end, dnafrag_id
        from genomic_align
        order by genomic_align_block_id, dnafrag_id
    ';
    
    $sth = $dbh->prepare($q);
    $rv  = $sth->execute || die $sth->errstr;
        
    # parse the data
    my (@seen_ids, $prev_id, $prev_df_id, $prev_comparison, $prev_method, $prev_start, $prev_end, $prev_sr, $prev_species, $prev_coord_sys);
    
    while (my ($gabid, $mlss_id, $start, $end, $df_id) = $sth->fetchrow_array) {
      my $id = $gabid . $mlss_id;
      
      if ($id eq $prev_id) {
        my $this_method    = $methods{$mlss_id};
        my $this_sr        = $genomic_regions{$df_id}->{'seq_region'};
        my $this_species   = $genomic_regions{$df_id}->{'species'};
        my $this_coord_sys = $genomic_regions{$df_id}->{'coord_system'};
        my $comparison     = "$this_sr:$prev_sr";
        my $coords         = "$this_coord_sys:$prev_coord_sys";
        
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'coord_systems'}  = "$coords";  # add a record of the coord systems used (might be needed for zebrafish ?)
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'source_name'}    = "$this_sr"; # add names of compared regions
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'source_species'} = "$this_species";
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'target_name'}    = "$prev_sr";
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'target_species'} = "$prev_species";
        $config{$this_method}{$this_species}{$prev_species}{$comparison}{'mlss_id'}        = "$mlss_id";
        
        $self->_get_vega_regions(\%config, $this_method, $comparison, $this_species, $prev_species, $start, $prev_start,'start'); # look for smallest start in this comparison
        $self->_get_vega_regions(\%config, $this_method, $comparison, $this_species, $prev_species, $end, $prev_end, 'end');      # look for largest ends in this comparison
      } else {
        $prev_id        = $id;
        $prev_df_id     = $df_id;
        $prev_start     = $start;
        $prev_end       = $end;
        $prev_sr        = $genomic_regions{$df_id}->{'seq_region'};
        $prev_species   = $genomic_regions{$df_id}->{'species'};
        $prev_coord_sys = $genomic_regions{$df_id}->{'coord_system'};
      }        
    }
    
    # add reciprocal entries for each comparison
    foreach my $method (keys %config) {
      foreach my $p_species (keys %{$config{$method}}) {
        foreach my $s_species (keys %{$config{$method}{$p_species}}) {                                                
          foreach my $comp (keys %{$config{$method}{$p_species}{$s_species}}) {
            my $revcomp = join ':', reverse(split ':', $comp);
            
            if (!exists $config{$method}{$s_species}{$p_species}{$revcomp}) {
              my $coords = $config{$method}{$p_species}{$s_species}{$comp}{'coord_systems'};
              my ($a,$b) = split ':', $coords;
              
              $coords = "$b:$a";
              
              my $record = {
                source_name    => $config{$method}{$p_species}{$s_species}{$comp}{'target_name'},
                source_species => $config{$method}{$p_species}{$s_species}{$comp}{'target_species'},
                source_start   => $config{$method}{$p_species}{$s_species}{$comp}{'target_start'},
                source_end     => $config{$method}{$p_species}{$s_species}{$comp}{'target_end'},
                target_name    => $config{$method}{$p_species}{$s_species}{$comp}{'source_name'},
                target_species => $config{$method}{$p_species}{$s_species}{$comp}{'source_species'},
                target_start   => $config{$method}{$p_species}{$s_species}{$comp}{'source_start'},
                target_end     => $config{$method}{$p_species}{$s_species}{$comp}{'source_end'},
                mlss_id        => $config{$method}{$p_species}{$s_species}{$comp}{'mlss_id'},
                coord_systems  => $coords,
              };
              
              $config{$method}{$s_species}{$p_species}{$revcomp} = $record;
            }
          }
        }
      }
    }

    # get a summary of the regions present (used for Vega 'availability' calls)
    my $region_summary;
    foreach my $method (keys %config) {
      foreach my $p_species (keys %{$config{$method}}) {
        foreach my $s_species (keys %{$config{$method}{$p_species}}) {                                                
          foreach my $comp (keys %{$config{$method}{$p_species}{$s_species}}) {
            my $target_name  = $config{$method}{$p_species}{$s_species}{$comp}{'target_name'};
            my $source_name  = $config{$method}{$p_species}{$s_species}{$comp}{'source_name'};
            my $source_start = $config{$method}{$p_species}{$s_species}{$comp}{'source_start'};
            my $source_end   = $config{$method}{$p_species}{$s_species}{$comp}{'source_end'};
            my $mlss_id      = $config{$method}{$p_species}{$s_species}{$comp}{'mlss_id'};
            my $name         = $names{$mlss_id};
            
            push @{$region_summary->{$p_species}{$source_name}}, {
              secondary_species => $s_species,
              target_name       => $target_name,
              start             => $source_start,
              end               => $source_end,
              mlss_id           => $mlss_id,
              alignment_name    => $name,
            };
          }
        }
      }
    }
    
    $self->db_tree->{$db_name}{'VEGA_COMPARA'} = \%config;
    $self->db_tree->{$db_name}{'VEGA_COMPARA'}{'REGION_SUMMARY'} = $region_summary;
  }
  
  ## That's the end of the compara region munging!

  my $res_aref_2 = $dbh->selectall_arrayref(qq{
    select ml.type, gd.name, gd.name, count(*) as count
      from method_link_species_set as mls, method_link as ml, species_set as ss, genome_db as gd 
      where mls.species_set_id = ss.species_set_id and
        ss.genome_db_id = gd.genome_db_id and
        mls.method_link_id = ml.method_link_id and
        ml.type not like '%PARALOGUES'
      group by mls.method_link_species_set_id, mls.method_link_id
      having count = 1
  });
  
  push @$res_aref, $_ for @$res_aref_2;
  
  foreach my $row (@$res_aref) {
#    my ($species1, $species2) = (ucfirst $row->[1], ucfirst $row->[2]);
    my ($species1, $species2) = ($row->[1], $row->[2]);
    
    $species1 =~ tr/ /_/;
    $species2 =~ tr/ /_/;
    
    my $key = $sections{uc $row->[0]} || uc $row->[0];
    
    $self->db_tree->{$db_name}{$key}{'merged'}{$species2}  = $valid_species{$species2};
    $self->db_tree->{$db_name}{$key}{$species1}{$species2} = $valid_species{$species2};
  }             
  
  ###################################################################
  ## Section for colouring and colapsing/hidding genes per species in the GeneTree View
  # 1. Only use the species_sets that have a genetree_display tag
  
  $res_aref = $dbh->selectall_arrayref(q{SELECT species_set_id FROM species_set_tag WHERE tag = 'genetree_display'});
  
  foreach my $row (@$res_aref) {
    # 2.1 For each set, get all the tags
    my ($species_set_id) = @$row;
    my $res_aref2 = $dbh->selectall_arrayref("SELECT tag, value FROM species_set_tag WHERE species_set_id = $species_set_id");
    my $res;
    
    foreach my $row2 (@$res_aref2) {
      my ($tag, $value) = @$row2;
      $res->{$tag} = $value;
    }
    
    my $name = $res->{'name'}; # 2.2 Get the name for this set (required)
    
    next unless $name; # Requires a name for the species_set
    
    # 2.3 Store the values
    while (my ($key, $value) = each %$res) {
      next if $key eq 'name';
      $self->db_tree->{$db_name}{'SPECIES_SET'}{$name}{$key} = $value;
    }

    # 3. Get the genome_db_ids for each set
    $res_aref2 = $dbh->selectall_arrayref("SELECT genome_db_id FROM species_set WHERE species_set_id = $species_set_id");
    
    push @{$self->db_tree->{$db_name}{'SPECIES_SET'}{$name}{'genome_db_ids'}}, $_->[0] for @$res_aref2;
  }
  
  ## End section about colouring and colapsing/hidding gene in the GeneTree View
  ###################################################################

  ###################################################################
  ## Section for storing the genome_db_ids <=> species_name
  $res_aref = $dbh->selectall_arrayref('SELECT genome_db_id, name, assembly FROM genome_db WHERE assembly_default = 1');
  
  foreach my $row (@$res_aref) {
    my ($genome_db_id, $species_name) = @$row;
    
    $species_name =~ tr/ /_/;
    
    $self->db_tree->{$db_name}{'GENOME_DB'}{$species_name} = $genome_db_id;
    $self->db_tree->{$db_name}{'GENOME_DB'}{$genome_db_id} = $species_name;
  }
  ###################################################################
   
 $dbh->disconnect;
}

1;
