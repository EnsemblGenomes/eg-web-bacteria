Ensembl.Panel.BlastSpeciesList = Ensembl.Panel.extend({
  // for Bacteria, make sure blast species names are all-lower-case 
  updateTaxonSelection: function(items) {
  	this.base.apply(this, arguments);
    this.elLk.checkboxes.filter('input[type=checkbox]').each( function(ele) {
      $(this).attr('value', $(this).attr('value').toLowerCase());
    });
  }
});
