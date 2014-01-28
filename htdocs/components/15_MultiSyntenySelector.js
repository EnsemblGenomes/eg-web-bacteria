Ensembl.Panel.MultiSyntenySelector = Ensembl.Panel.MultiSpeciesSelector.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    $('ul span.switch', this.elLk.list).unbind('click').bind('click', function () {
      var li = $(this).parent();
      var excluded, i;
      
      if (li.parent().hasClass('included')) {
        excluded = $('li', panel.elLk.excluded);
        i = excluded.length;

        while (i--) {
          if ($(excluded[i]).text() < li.text()) {
            $(excluded[i]).after(li);
            break;
          }
        }
        
        // item to be added is closer to the start of the alphabet than anything in the excluded list
        if (i == -1) {
          panel.elLk.excluded.prepend(li);
        }
        
        panel.setSelection();
        
        excluded = null;
      } else if ($('li', panel.elLk.included).length < 7) {
        panel.elLk.included.append(li);
        panel.selection.push(li.prop('className'));
      } 
      li = null;
    });
  }
});
