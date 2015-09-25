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

package EG::Bacteria::SiteDefs;
use strict;

sub update_conf {
    @SiteDefs::ENSEMBL_PERL_DIRS    = (
	    $SiteDefs::ENSEMBL_WEBROOT.'/perl',
	    $SiteDefs::ENSEMBL_SERVERROOT.'/eg-web-common/perl',
	    $SiteDefs::ENSEMBL_SERVERROOT.'/eg-web-bacteria/perl',
	  );

    $SiteDefs::ENSEMBL_PORT           = 8002;
    $SiteDefs::ENSEMBL_SERVERNAME     = 'bacteria.ensembl.org';

    $SiteDefs::EG_DIVISION = 'bacteria';
    $SiteDefs::SITE_NAME = 'Ensembl Bacteria';
    $SiteDefs::ENSEMBL_SITETYPE = 'Ensembl Bacteria';
    $SiteDefs::SITE_FTP= 'ftp://ftp.ensemblgenomes.org/pub/bacteria';

    $SiteDefs::DISABLE_SPECIES_DROPDOWN = 1;
    $SiteDefs::LARGE_SPECIES_SET        = 1;

    map {delete($SiteDefs::__species_aliases{$_}) } keys %SiteDefs::__species_aliases;
  
    $SiteDefs::ENSEMBL_DATASETS = [];
    push (@{$SiteDefs::ENSEMBL_DATASETS}, "bacteria_$_") foreach (0..125);
    
    $SiteDefs::ENSEMBL_PRIMARY_SPECIES = 'escherichia_coli_str_k_12_substr_mg1655'; 
    $SiteDefs::__species_aliases{ 'escherichia_coli_str_k_12_substr_mg1655'       } = [qw(bc)];
        
    $SiteDefs::ENSEMBL_SECONDARY_SPECIES = 'tropheryma_whipplei_tw08_27'; 
    $SiteDefs::__species_aliases{ 'tropheryma_whipplei_tw08_27'       } = [qw(tw)];
}

1;
