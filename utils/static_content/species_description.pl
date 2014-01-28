#!/usr/local/bin/perl -
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

use strict;
use warnings;

use Data::Dumper;
use FindBin qw($Bin);
use LWP::Simple;
use XML::Simple;
use Time::HiRes;

BEGIN {
  my $serverroot = "$Bin/../../../../";
  unshift @INC, "$serverroot/conf", $serverroot;
  
  require SiteDefs;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;

  require EnsEMBL::Web::DBSQL::DBAdaptor;
  require EnsEMBL::Web::Hub;  
}

my $hub = new EnsEMBL::Web::Hub;

my $dir = "$Bin/../../htdocs/ssi/species";
die "Dir $dir does not exist" unless -d $dir;
print "\nOutput dir: $dir\n";

foreach my $dataset (@ARGV ? @ARGV : @$SiteDefs::ENSEMBL_DATASETS) {   
  print "$dataset...\n";
  
  my $adaptor = $hub->get_adaptor('get_GeneAdaptor', 'core', $dataset);
  if (!$adaptor) {
    warn "core db doesn't exist for $dataset\n";
    next;
  } 

  my $sth = $adaptor->prepare("SELECT DISTINCT species_id FROM meta WHERE species_id IS NOT null"); 
  $sth->execute;  
  
  while (my $id = $sth->fetchrow_array) {
    next unless my $production_name = get_meta_value($adaptor, $id, 'species.production_name');
       
    my $name = get_meta_value($adaptor, $id, 'species.scientific_name');
    my $taxid = get_meta_value($adaptor, $id, 'species.taxonomy_id');         
    my $wiki_url = get_meta_value($adaptor, $id, 'species.wikipedia_url');         
    my $html .= qq{
<h2 class="first"> <em>$name</em></h2>
<h3>Organism</h3>

<table class=\"organism\">
  <tr><th>Taxonomy ID</th><td><a href="http://www.uniprot.org/taxonomy/$taxid">$taxid</a></td></tr>
  <tr><th>Name</th><td><em>$name</em></td></tr>
    };
	
    if($wiki_url){
      $html .= qq{<tr><th>&nbsp;</th><td><a href="$wiki_url" rel="external">Wikipedia</a></td></tr>};
    }
    
    if (my @alias = sort grep {!/^($name|$production_name)$/i} get_meta_value($adaptor, $id, 'species.alias')) {
      $html .= "<tr><th>Aliases</th><td>\n";
      $html .= "<ul>\n<li>" . join("</li>\n<li>", @alias) . "</li>\n</ul>\n</td></tr>";
    }
    $html .= "</table>\n";
    
    
    # Classification
    
    if (my @classification = get_meta_value($adaptor, $id, 'species.classification')) {
      my $indent = 0;
      $html .= "<table class=\"classification\"><tr><th>Classification</th><td>";
      $html .= "<ul>\n";
      $html .= "<li style=\"margin-left:" . (10 * $indent++) . "px\"><span class=\"arrow\">&rsaquo;</span> $_</li>\n" for @classification;
      $html .= "</ul></td></tr></table>\n";
    }
    $html .= "<div style=\"clear:both\"></div>\n";
    
    # ENA Records
    
    my @ena_record;
    
    my $sth = $adaptor->prepare(q{
      SELECT seq_region.name FROM seq_region JOIN coord_system USING (coord_system_id) 
      WHERE coord_system.name='contig' AND coord_system.species_id=? ORDER BY seq_region.name
    }); 
    $sth->execute($id);  
    
    while (my $value = $sth->fetchrow_array) { push @ena_record, $value };
    
    if (@ena_record) {
      $html .= "<h3>European Nucleotide Archive Records</h3>\n";
      $html .= "<ul class=\"ena_records\">\n<li>" . join("</li>\n<li>", map {qq{<a href="http://www.ebi.ac.uk/ena/data/view/$_">$_</a>}} @ena_record) . "</li>\n</ul>\n";
    }
    
    # References
    
    my @pubmed_id;
    
    $sth = $adaptor->prepare(q{
      SELECT DISTINCT dbprimary_acc pmid FROM seq_region JOIN coord_system USING (coord_system_id) 
      JOIN seq_region_attrib USING (seq_region_id) JOIN attrib_type USING (attrib_type_id) 
      JOIN xref ON (`value`=xref_id) JOIN external_db USING (external_db_id) 
      WHERE CODE='xref_id' AND db_name='PUBMED' AND species_id = ?
    }); 
    $sth->execute($id);  
    
    while (my $value = $sth->fetchrow_array) { push @pubmed_id, $value };
    
    if (@pubmed_id) {
      $html .= "<h3>References</h3>\n";
      $html .= "<ol>\n";
      foreach my $pmid (@pubmed_id) {
        if (my $summary = get_pubmed_summary($pmid)) {
          $html .= "<li><p>\n";
          $html .= "$summary->{title} " . join(', ', @{$summary->{authors}}) . " - $summary->{source} ";
          $html .= "PubMed: <a href=\"http://europepmc.org/abstract/MED/$pmid\">$pmid</a>";
          $html .= "</p></li>\n";
        }
      }
      $html .= "</ol>\n";
    }   
    # Sample code
    
    $html .= "<h3>Ensembl Genomes API Example</h3>\n";
    $html .= "<p>This example Perl script shows how to create a database adaptor for this species. For more information see the <a href=\"/info/data/accessing_ensembl_bacteria.html\">Ensembl Bacteria documentation</a>.</p>";
    $html .= sprintf(
      q|<pre class="code">
#!/usr/bin/env perl
use strict;
use warnings;

use Bio::EnsEMBL::LookUp;

# load the lookup from the main Ensembl Bacteria public server
my $lookup = Bio::EnsEMBL::LookUp->new(
  -URL => "http://bacteria.ensembl.org/registry.json",
  -NO_CACHE => 1
);

# find the correct database adaptor using a unique name
my ($dba) = @{$lookup->get_by_name_exact(
  '%s'
)};

# now work with the database adaptor as for any Ensembl database
</pre>|,
      $production_name
    );    
    
    $html = qq{<div class="species_description">\n$html</div>\n};
     
    my $filename = "$dir/about_${production_name}.html";
    open(my $fh, '>', "$filename") or die $!;
    print $fh $html;
    close($fh);
    
    warn "Wrote $filename\n";
    Time::HiRes::sleep(0.5); # wait 0.5 sec
  } 
}

sub get_meta_value {
  my ($adaptor, $species_id, $meta_key) = @_;
  my $sth = $adaptor->prepare("SELECT meta_value FROM meta WHERE species_id = ? AND meta_key = ? ORDER BY meta_id DESC"); 
  $sth->execute($species_id, $meta_key);  
  my @values;
  while (my $value = $sth->fetchrow_array) {
    push @values, $value;
  }
  return wantarray ? @values : $values[0];
}

sub get_pubmed_summary {
  my $id = shift;
  my $url = "http://www.ebi.ac.uk/Tools/dbfetch/dbfetch/medline/$id/medlinexml";
  
  my $xml = get($url);
  
  unless ($xml) {
    warn "LWP::Simple returned no content for url [$url]";
    return;
  }

  my $data;
  eval {
    $data = XMLin($xml, ForceArray => ['Author'])
  };
  if ($@) {
    warn $@;
    return;
  }
  
  if (!$data or $data->{ERROR}) {
    warn "Error fetching pubmed article ($data->{ERROR})";
    return;
  }
   
  my $article = $data->{PubmedArticle}->{MedlineCitation}->{Article};
  my $journal = $article->{Journal}; 
  my @authors = map {
    $_->{LastName} ? (sprintf("%s %s.", $_->{LastName}, join('.', split //, $_->{Initials})))
                   : $_->{CollectiveName}
  } @{$article->{AuthorList}->{Author}};
  
  return {
    title   => $article->{ArticleTitle},
    authors => \@authors,
    source  => sprintf('<i>%s</i> %s, <b>%s</b>%s:%s', 
      $journal->{ISOAbbreviation} || $journal->{Title},
      $journal->{JournalIssue}->{PubDate}->{Year},
      $journal->{JournalIssue}->{Volume},
      $journal->{JournalIssue}->{Issue} ? "($journal->{JournalIssue}->{Issue})" : '',
      $article->{Pagination}->{MedlinePgn},
    ),
  };
}






