/* JavaScript for datatable on /species.html */

Ensembl.Panel.FTPTable = Ensembl.Panel.extend({  
  init: function () {
    
    $.fn.dataTableExt.oStdClasses.sWrapper = 'dataTables_wrapper';
    
    $('#ftp_table').dataTable({
        bProcessing: true,
        bServerSide: true,
        sAjaxSource: '/Multi/Ajax/ftp_list',
        aaSorting: [ [ 1, 'asc' ] ],
        iDisplayLength: 25, 
        oSearch: { sSearch: $('#ftp_table_search').val() },
        oLanguage: { 
          sSearch: 'Filter',
          sZeroRecords: '<p class="no-results">No rows match your search term</p><p class="no-results-help"><a href="/info/website/ftp/index.html" class="view-all">View all rows</a> or edit your search by typing in the box on the right.</p>',
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
          { sWidth: '5%' },
          { sWidth: '5%' },
          { sWidth: '5%' },
          { sWidth: '5%' },
          { sWidth: '5%' },
          { sWidth: '5%' },
          { sWidth: '5%' },
          { sWidth: '5%' }
        ],
        sPaginationType: 'full_numbers',
        asStripClasses:  [ 'bg1', 'bg2' ],
        bAutoWidth:      false,
        sDom: '<"dataTables_top"lfr>t<"dataTables_bottom"ip>'
    });

    var search = $('#ftp_table_filter input', this.el);
    var viewAll = $('.view-all', this.el);
     
    viewAll.click(function(){ 
      search.val(''); 
      search.trigger('keyup'); 
      return false; 
    });
    
    search.focus();

  }
});
