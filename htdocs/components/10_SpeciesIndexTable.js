/* JavaScript for datatable on /info/about/species.html */

Ensembl.Panel.SpeciesIndexTable = Ensembl.Panel.extend({  
  init: function () {
    
    $.fn.dataTableExt.oStdClasses.sWrapper = 'dataTables_wrapper';
    
    $('#species_index_table').dataTable({
        bProcessing: true,
        bServerSide: true,
        sAjaxSource: '/Multi/Ajax/species_list',
        aaSorting: [ [ 1, 'asc' ] ],
        iDisplayLength: 25, 
        oSearch: { sSearch: $('#species_index_search').val() },
        oLanguage: { 
          sSearch: 'Filter',
          sZeroRecords: '<p class="no-results">No species match your search term</p><p class="no-results-help"><a href="/info/about/species.html" class="view-all">View all species</a> or edit your search by typing in the box on the right.</p>',
          oPaginate: {
            sFirst:    '&lt;&lt;',
            sPrevious: '&lt;',
            sNext:     '&gt;',
            sLast:     '&gt;&gt;'
          }
        },
        "aoColumns": [ 
          { sWidth: '0%', bVisible: false },
          { sWidth: '60%' },
          { sWidth: '20%' },
          { sWidth: '10%' },
          { sWidth: '10%' }
        ],
        sPaginationType: 'full_numbers',
        asStripClasses:  [ 'bg1', 'bg2' ],
        bAutoWidth:      false,
        sDom: '<"dataTables_top"lfr>t<"dataTables_bottom"ip>'
    });

    var search = $('#species_index_table_filter input', this.el);
    var viewAll = $('.view-all', this.el);
     
    viewAll.click(function(){ 
      search.val(''); 
      search.trigger('keyup'); 
      return false; 
    });
    
    search.focus();

  }
});