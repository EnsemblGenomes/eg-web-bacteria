// $Revision: 1.5 $

Ensembl.Panel.ImageMap =  Ensembl.Panel.ImageMap.extend({
  
  makeImageMap: function () {
    var panel = this;
    
    var highlight = !!( window.location.pathname.match(/\/Location\/|\/Variation_Gene\/Image/) && !this.vdrag);
    var rect = [ 'l', 't', 'r', 'b' ];
    var speciesNumber, c, r, start, end, scale;
    
    this.elLk.areas.each(function () {
      c = { a: this };
      
      if (this.shape && this.shape.toLowerCase() !== 'rect') {
        c.c = [];
        $.each(this.coords.split(/[ ,]/), function () { c.c.push(parseInt(this, 10)); });
      } else {
        $.each(this.coords.split(/[ ,]/), function (i) { c[rect[i]] = parseInt(this, 10); });
      }
      
      panel.areas.push(c);
      
      if (this.className.match(/drag/)) {
        // r = [ '#drag', image number, species number, species name, region, start, end, strand ]
        r     = c.a.href.split('|');
        start = parseInt(r[5], 10);
        end   = parseInt(r[6], 10);
        
//// EG        
        var midpointChr = parseInt(r[8]) || 0;
 	      var midpointImg = parseInt(r[9]) || 0;

        if(start <= end) {
          scale = (end - start + 1) / (c.r - c.l);                   // bps per pixel on image
        } else {
          scale = (end + midpointChr - start + 1) / (c.r - c.l);     // bps per pixel on image
        }
 
        c.range = { start: start, end: end, scale: scale, midchr: midpointChr, midimg: midpointImg };
////
        
        panel.draggables.push(c);
        
        if (highlight === true) {
          r = this.href.split('|');
          speciesNumber = parseInt(r[1], 10) - 1;
          
          if (panel.multi || !speciesNumber) {
            if (!panel.highlightRegions[speciesNumber]) {
              panel.highlightRegions[speciesNumber] = [];
              panel.speciesCount++;
            }
            
            panel.highlightRegions[speciesNumber].push({ region: c });
            panel.imageNumber = parseInt(r[2], 10);
            
            Ensembl.images[panel.imageNumber] = Ensembl.images[panel.imageNumber] || {};
            Ensembl.images[panel.imageNumber][speciesNumber] = [ panel.imageNumber, speciesNumber, parseInt(r[5], 10), parseInt(r[6], 10) ];
          }
        }
      }
    });
    
    if (Ensembl.images.total) {
      this.highlightAllImages();
    }
      
    this.elLk.drag.on({
      mousedown: function (e) {
        // Only draw the drag box for left clicks.
        // This property exists in all our supported browsers, and browsers without it will draw the box for all clicks
        if (!e.which || e.which === 1) {
          panel.dragStart(e);
        }
        
        return false;
      },
      click: function (e) {
        if (panel.clicking) {
          panel.makeZMenu(e, panel.getMapCoords(e));
        } else {
          panel.clicking = true;
        }
      }
    });
  },
  
  /**
   * Highlights regions of the image.
   * In MultiContigView, each image can have numerous regions to highlight - one per species
   *
   * redbox:  Dotted red line outlining the draggable region of an image. 
   *          Only shown where an image displays a region contained in another region.
   *          In practice this means redbox never appears on the first image on the page.
   *
   * redbox2: Solid red line outlining the region of an image displayed on the next image.
   *          If there is only one image, or the next image has an invalid coordinate system 
   *          (eg AlignSlice or whole chromosome), highlighting is taken from the r parameter in the url.
   */
  highlightImage: function (imageNumber, speciesNumber, start, end) {
    // Make sure each image is highlighted based only on itself or the next image on the page
    if (!this.draggables.length || this.vdrag || imageNumber - this.imageNumber > 1 || imageNumber - this.imageNumber < 0) {
      return;
    }
    
    var i = this.highlightRegions[speciesNumber].length;
    var link = true; // Defines if the highlighted region has come from another image or the url
    var highlight, coords;
    
    while (i--) {
      highlight = this.highlightRegions[speciesNumber][i];
      
      if (!highlight.region.a) {
        break;
      }
      
      // Highlighting base on self. Take start and end from Ensembl core parameters
      if (this.imageNumber === imageNumber) {
        // Don't draw the redbox on the first imagemap on the page
        if (this.imageNumber !== 1) {
          this.highlight(highlight.region, 'redbox', speciesNumber, i);
        }
        
        if (speciesNumber && Ensembl.multiSpecies[speciesNumber]) {
          start = Ensembl.multiSpecies[speciesNumber].location.start;
          end   = Ensembl.multiSpecies[speciesNumber].location.end;
        } else {
          start = Ensembl.location.start;
          end   = Ensembl.location.end;
        }
        
        link = false;
      }

      var r_val;      

      //start param > end param and the whole length of the chromosome is represented in the ViewTop container
      if ((start > end) && (highlight.region.range.midchr == 0)) {

        r_val = end - highlight.region.range.start;

        var coords = {
          t: highlight.region.t + 2,
          b: highlight.region.b - 2,
          l: highlight.region.l,
          r: (r_val / highlight.region.range.scale) + highlight.region.l
        };

        var coords2 = {
	        t: highlight.region.t + 2,
          b: highlight.region.b - 2,
          l: ((start - highlight.region.range.start) / highlight.region.range.scale) + highlight.region.l,
          r: highlight.region.r
	      };
        
        if (this.params.highlight) {
          this.highlight(coords,  'redbox2', speciesNumber, i);
          this.highlight(coords2, 'redbox2', speciesNumber, i, true);
	      }

      } else {

	     if(start > end) {
         r_val = end - highlight.region.range.start;
         if(r_val < 0) {
           r_val = r_val + highlight.region.range.midchr;
         }
        } else {
         r_val = end - highlight.region.range.start;
        }

        var coords = {
          t: highlight.region.t + 2,
          b: highlight.region.b - 2,
          l: ((start - highlight.region.range.start) / highlight.region.range.scale) + highlight.region.l,
          r: (r_val / highlight.region.range.scale) + highlight.region.l
        };

        // Highlight unless it's the bottom image on the page
        if (this.params.highlight) {
          this.highlight(coords, 'redbox2', speciesNumber, i);
        }
      }
    }
  },

  highlight: function (coords, cl, speciesNumber, multi, forceDraw) {
    var w = coords.r - coords.l + 1;
    var h = coords.b - coords.t + 1;
    var originalClass, els;

    var style = {
      l: { left: coords.l, width: 1, top: coords.t, height: h },
      r: { left: coords.r, width: 1, top: coords.t, height: h },
      t: { left: coords.l, width: w, top: coords.t, height: 1, overflow: 'hidden' },
      b: { left: coords.l, width: w, top: coords.b, height: 1, overflow: 'hidden' }
    };

    if (typeof speciesNumber !== 'undefined') {
      originalClass = cl;
      cl = cl + '_' + speciesNumber + (multi || '');
    }

    els = $('.' + cl, this.el);

    if (!els.length || forceDraw) {
      els = $([
        '<div class="', cl, ' l"></div>', 
        '<div class="', cl, ' r"></div>', 
        '<div class="', cl, ' t"></div>', 
        '<div class="', cl, ' b"></div>'
      ].join('')).insertAfter(this.elLk.img);
    }
    
    els.each(function () {
      $(this).css(style[this.className.split(' ')[1]]);
    });
    
    if (typeof speciesNumber !== 'undefined') {
      els.addClass(originalClass);
    }
    
    els = null;
  }
  
});
