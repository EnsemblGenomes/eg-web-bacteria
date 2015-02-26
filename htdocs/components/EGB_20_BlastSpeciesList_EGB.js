Ensembl.Panel.BlastSpeciesList = Ensembl.Panel.BlastSpeciesList.extend({
  // for Bacteria, make sure blast species names are all-lower-case 
  updateTaxonSelection: function(items) {
  	var panel = this; 
    panel.base.apply(this, arguments);
    $('input[type=checkbox]', panel.elLk.checkboxes).each( function(ele) {
      $(this).attr('value', $(this).attr('value').toLowerCase());
    });
  }
});
