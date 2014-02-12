Ensembl.Panel.BlastSpeciesList = Ensembl.Panel.extend({ 
  updateTaxonSelection: function(items) {
  	var panel = this;
  	var key;
  	
  	// empty and re-populate the species list
  	$('option', panel.elLk.list).remove();
  	$.each(items, function(index, item){
  		////Bacteria
  		//key = item.key.charAt(0).toUpperCase() + item.key.substr(1); // ucfirst
   		key = key.toLowerCase();  		
      ////
  		//$(panel.elLk.list).append(new Option(item.kye, item.key)); // this fails in IE - see http://bugs.jquery.com/ticket/1641
  		$(panel.elLk.list).append('<option value="' + key + '">' + key + '</option>'); // this works in IE 
  	}); 
  	
  	// update the modal link href
  	var modalBaseUrl = panel.elLk.modalLink.attr('href').split('?')[0];
  	var keys = $.map(items, function(item){ return item.key; });
  	var queryString = $.param({s: keys}, true);
  	panel.elLk.modalLink.attr('href', modalBaseUrl + '?' + queryString);
  }
});
