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

sub _summarise_core_tables {
  my $self   = shift;
  my $db_key = shift;
  my $db_name = shift; 
  my $dbh    = $self->db_connect( $db_name );

  return unless $dbh; 

  push @{ $self->db_tree->{'core_like_databases'} }, $db_name;

  $self->_summarise_generic( $db_name, $dbh );

## EG
# ## Get chromosomes in order (replacement for array in ini files)
# ## and also check for presence of LRGs
# ## Only need to do this once!
#   if ($db_name eq 'DATABASE_CORE') {
#     my $s_aref = $dbh->selectall_arrayref(
#       'select s.name 
#       from seq_region s, seq_region_attrib sa, attrib_type a 
#       where sa.seq_region_id = s.seq_region_id 
#         and sa.attrib_type_id = a.attrib_type_id 
#         and a.code = "karyotype_rank" 
#       order by abs(sa.value)'
#     );
#     my $chrs = [];
#     foreach my $row (@$s_aref) {
#       push @$chrs, $row->[0];
#     }
#     $self->db_tree->{'ENSEMBL_CHROMOSOMES'} = $chrs;
#     $s_aref = $dbh->selectall_arrayref(
#         'select count(*) from seq_region where name like "LRG%"'
#     );
#     if ($s_aref->[0][0] > 0) {
#       $self->db_tree->{'HAS_LRG'} = 1;
#     }
#   }
##

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
    my $web_data = $a_aref->[6] ? from_json($a_aref->[6]) : {};
    $analysis->{ $a_aref->[0] } = {
      'logic_name'  => $a_aref->[1],
      'name'        => $a_aref->[3],
      'description' => $a_aref->[4],
      'displayable' => $a_aref->[5],
      'web_data'    => $web_data
    };
  }
  ## Set last repeat mask date whilst we're at it, as needed by BLAST configuration, below
  my $r_aref = $dbh->selectall_arrayref( 
      'select max(date_format( created, "%Y%m%d"))
      from analysis, meta
      where logic_name = lower(meta_value) and meta_key = "repeat.analysis"' 
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

    my $df_aref = $dbh->selectall_arrayref(
      "select analysis_id,file_type from data_file group by analysis_id"
      );
  foreach my $T ( @$df_aref ) {
    my $a_ref = $analysis->{$T->[0]}
        || ( warn("Missing analysis entry data_file - $T->[0]\n") && next );
    my $value = {
        'name'    => $a_ref->{'name'},
        'desc'    => $a_ref->{'description'},
        'disp'    => $a_ref->{'displayable'},
        'web'     => $a_ref->{'web_data'},
        'count'   => 1,
        'format'  => lc($T->[1]),
    };
    $self->db_details($db_name)->{'tables'}{'data_file'}{'analyses'}{$a_ref->{'logic_name'}} = $value;
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
      'SELECT sr.name, sr.length FROM seq_region sr 
       INNER JOIN seq_region_attrib sra USING (seq_region_id) 
       INNER JOIN attrib_type at USING (attrib_type_id)
       WHERE at.code = "karyotype_rank"' 
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
      push @{$self->db_tree->{'SPECIES_ONTOLOGIES'}}, $row->[0] if ($row->[0]);
    }
  }

## EG
# #---------------
# #
# # * Assemblies...
# # This is a bit ugly, because there's no easy way to sort the assemblies via MySQL
#   $t_aref = $dbh->selectall_arrayref(
#     'select version, attrib from coord_system where version is not null order by rank' 
#   );
#   my (%default, %not_default);
#   foreach my $row (@$t_aref) {
#     my $version = $row->[0];
#     my $attrib  = $row->[1];
#     if ($attrib =~ /default_version/) {
#       $self->db_tree->{'ASSEMBLY_VERSION'} ||= $version; # get top ranked default_version
#       $default{$version}++;
#     }
#     else {
#       $not_default{$version}++;
#     }
#   }
#   my @assemblies = keys %default;
#   push @assemblies, sort keys %not_default;
#   $self->db_tree->{'CURRENT_ASSEMBLIES'} = join(',', @assemblies);
 #

#-------------
#
# * Transcript biotypes
# get all possible transcript biotypes
  @{$self->db_details($db_name)->{'tables'}{'transcript'}{'biotypes'}} = map {$_->[0]} @{$dbh->selectall_arrayref(
    'SELECT DISTINCT(biotype) FROM transcript;'
  )};

#----------
  $dbh->disconnect();
}


## EG not applicable to Bacteria
sub _summarise_funcgen_db {}

1;
