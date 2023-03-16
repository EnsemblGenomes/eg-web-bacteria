Ensembl.HotJar = {
  init: function() {
    const hotjarId = 3280832;
    this.addScript(hotjarId);
  },

  addScript: (hotjarId) => {
    if (hotjarId) {
      const version = 6;
      (function(h,o,t,j,id,ver){
        h.hj=h.hj||function(){(h.hj.q=h.hj.q||[]).push(arguments)};
        h._hjSettings={hjid:id,hjsv:ver};
        a=o.getElementsByTagName('head')[0];
        r=o.createElement('script');r.async=1;
        r.src=t+h._hjSettings.hjid+j+h._hjSettings.hjsv;
        a.appendChild(r);
      })(window,document,'https://static.hotjar.com/c/hotjar-','.js?sv=',hotjarId,version);
    }
  }
}
// initialise hotjar when Ensembl initializes
Ensembl.extend({
  initialize: function () {
    Ensembl.HotJar.init();
    this.base.apply(this, arguments);
  }
});