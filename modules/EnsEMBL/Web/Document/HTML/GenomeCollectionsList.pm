package EnsEMBL::Web::Document::HTML::GenomeCollectionsList;

use base qw(EnsEMBL::Web::Document::HTML::SpeciesList);

use strict;
use warnings;

sub render {
  return sprintf( qq{
    <div class="home-search-flex">
      <div id="species_list" class="js_panel">
        <input type="hidden" class="panel_type" value="SpeciesList" />
        <input type="hidden" name="sitePrefix" value="%s" />
        <h3 class="first">Search for a genome</h3>
        <form id="species_autocomplete_form" action="/info/about/species.html" style="margin-bottom:5px" method="get">
          <div>
           <input name="search" type="text" id="species_autocomplete" class="ui-autocomplete-input inactive" style="width:95\%; margin: 0" title="Start typing the name of a genome..." value="Start typing the name of a genome...">
          </div>
        </form>
        <p style="margin-bottom:0">
          e.g. type <b>esc</b> to find Escherichia
        </p>
      </div>
    </div>},
    $SiteDefs::SITE_PREFIX
  );
}

1;
