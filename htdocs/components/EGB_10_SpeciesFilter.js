// $Revision: 1.3 $

Ensembl.Panel.SpeciesFilter = Ensembl.Panel.extend({  
  init: function () {
    this.base();

    // SPECIES AUTOCOMPLETE
    var ac = $("#species_autocomplete", this.el);
    ac.autocomplete({
      minLength: 3,
      source: '/Multi/Ajax/species_autocomplete',
      select: function(event, ui) { if (ui.item) Ensembl.redirect(document.location.href + '&filter_species=' + ui.item.value) }
    }).submit(function() {
    	ac.autocomplete('search');
      return false;
    }).focus(function(){ 
    	// add placeholder text
      if($(this).val() == $(this).attr('title')) {
        ac.val('');
        ac.removeClass('inactive');
      } else if($(this).val() != '')  {
        ac.autocomplete('search');
      }
    }).blur(function(){
      // remove placeholder text
      ac.removeClass('invalid');
      ac.addClass('inactive');
      ac.val($(this).attr('title'));
    }).keyup(function(){
      // highlight invalid search strings
      if (ac.val().length >= 3) {
        var url = "/Multi/Ajax/species_autocomplete?term=" + escape(ac.val());
        $.getJSON(url, function(data) {
          if (data && data.length) {
            ac.removeClass('invalid');
          } else {
            ac.addClass('invalid');
          }
        });
      } else {
       ac.removeClass('invalid');
      }
    }).data("ui-autocomplete")._renderItem = function (ul, item) {
      // highlight the term within each match
      var regex = new RegExp("(?![^&;]+;)(?!<[^<>]*)(" + $.ui.autocomplete.escapeRegex(this.term) + ")(?![^<>]*>)(?![^&;]+;)", "gi");
      item.label = item.label.replace(regex, "<strong>$1</strong>");
      return $("<li></li>").data("ui-autocomplete-item", item).append("<a>" + item.label + "</a>").appendTo(ul);
    };
    
    $(window).bind("unload", function() {}); // hack - this forces page to reload if user returns here via the Back Button

  }
});
