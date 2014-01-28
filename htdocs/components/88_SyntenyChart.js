Raphael.fn.syntenyChart = function (cx, cy, r, rs, ds, stroke) {
  var paper = this;
  var rad = Math.PI / 180;
  var total = 0;
  var joints = [];
  var colours = [];
  var ribbons = [];
  var ribbon_drawn = [];
  var labels = [];
  var hintX = cx;
  var hintY = cy + r + 60;
  var tickSize = 10;
  var maxRegion = 20000;
  var locationTemplate = "/Location/Compara_Alignments/Image?r=";

  function drawSynteny(cx, cy, r, ds) {
    for (var k = 0; k < ds.length; k++) {
      var pair = ds[k];

      var pid = pair[0].id;
      var sid = pair[1].id;

      var px1 = parseInt(pair[0].s) + joints[pid];
      var px2 = parseInt(pair[0].e) + joints[pid];
      var sx1 = parseInt(pair[1].s) + joints[sid];
      var sx2 = parseInt(pair[1].e) + joints[sid];
      
      var sameStrand = parseInt(pair[0].st) == parseInt(pair[1].st);

      var pa1 = 360 * px1 / total;
      var pa2 = 360 * px2 / total;
      var sa1 = 360 * sx1 / total;
      var sa2 = 360 * sx2 / total;
      
      // don't draw line if it is very close to line already drawn (within a given tolerance)
      var alreadyDrawn = false;
      var tolerance = 0.5;
      for (var ir in ribbons) {
        var rib = ribbons[ir]; 
        if (Math.abs(pa1 - rib.pa1) <= tolerance && 
            Math.abs(pa2 - rib.pa2) <= tolerance && 
            Math.abs(sa1 - rib.sa1) <= tolerance && 
            Math.abs(sa2 - rib.sa2) <= tolerance) {
          alreadyDrawn = true;
          break;
        }
      }

      if (!alreadyDrawn) {
        var r1 = rs[pair[0].id].species + ' : ' + rs[pair[0].id].region;
        var r2 = rs[pair[1].id].species + ' : ' + rs[pair[1].id].region;
        var rtxt = r1+':'+pair[0].s+'-'+pair[0].e+ " => " + r2+':'+pair[1].s+'-'+pair[1].e;
        
        if (sameStrand) {
          var c1 = colours[pid];
          var c2 = colours[sid];
        } else { // inversion
          var c1 = 'black'; 
          var c2 = 'black';
        }

        var rb = ribbon(cx, cy, r-25, pa1, pa2, sa1, sa2, c1, c2, rtxt);
        var rbo = {
            r: rb,
            pid: pid,
            sid: sid,
            pa1: pa1,
            pa2: pa2,
            sa1: sa1,
            sa2: sa2,
            sameStrand: sameStrand
        };
        ribbons.push(rbo);
      }
    }
  }

  function drawChromosome(cx, cy, r, a1, a2, params, chr, j, txt) {
    var chrset = paper.set();
    
    // function to draw arrow at start fo segement
    arrow = function(angle) {
      var x1 = cx + (r -5) * Math.cos(angle * rad);
      var y1 = cy + (r - 5) * Math.sin(angle * rad);
      var x2 = cx + (r - 15) * Math.cos(angle * rad);
      var y2 = cy + (r - 15) * Math.sin(angle * rad);
      var x3 = cx + (r - 10) * Math.cos((angle+2) * rad);
      var y3 = cy + (r - 10) * Math.sin((angle+2) * rad);
      return paper.path(["M", x1, y1, "L", x2, y2, "L", x3, y3]).attr({fill: "white", stroke:"none"})
    }

    // function to draw a region label
    label = function(angle, text) {
      // stack labels that are close to each other
      var stackDepth = 0;
      for (var i = 0; i < labels.length; i++) if (Math.abs(labels[i].a - angle) <= 5) stackDepth++; 
      var angleOffset = (2 * stackDepth);
      var xOffset = 55 + (5 * stackDepth);
      var yOffset = 30 + (5 * stackDepth);
      // draw the stalk
      var x1 = cx + r * Math.cos(angle * rad);
      var y1 = cy + r * Math.sin(angle * rad);
      var x2 = cx + (r + xOffset) * Math.cos((angle + angleOffset) * rad);
      var y2 = cy + (r + yOffset) * Math.sin((angle + angleOffset) * rad);
      var line = paper.path(["M", x1, y1, "L", x2, y2]).attr({stroke: 'grey', "stroke-width": 1});
      // draw the label text
      var lx = Math.floor(cx + (r + xOffset) * Math.cos((angle + angleOffset) * rad));
      var ly = Math.floor(cy + (r + yOffset) * Math.sin((angle + angleOffset) * rad));
      var label = paper.text(lx, ly, text).attr({fill: "#444444", stroke: "none", opacity: 0.8, "font-family": 'Fontin-Sans, Arial', "font-size": "10px"});
      // draw the bounding box
      var b = label.getBBox();
      var xpad = 3; 
      var ypad = 2;
      var box = paper.path(["M", b.x-xpad, b.y-ypad, "L", b.x + b.width+xpad, b.y-ypad, "L", b.x + b.width+xpad, b.y + b.height+ypad, "L", b.x-xpad, b.y + b.height+ypad, "L", b.x-xpad, b.y-ypad]).attr({fill: "white", stroke: 'grey', "stroke-width": 0.5})
      // create set
      var set = paper.set(box, label).toFront();
      labels.push({a: angle, set: set});
      return set;
    }

    if ( (a2-a1) < tickSize) {
      var rlink;
      // we can display the whole chromosome
      if (chr.len < maxRegion) {
        rlink = chr.spath + locationTemplate + chr.region + ':' + 1+'-'+chr.len;
      } else {
        // find the centre point and show the maxRegion around it
        var cpoint = parseInt(chr.len / 2);
        var xs = cpoint - (maxRegion / 2);
        var xe = cpoint + (maxRegion / 2);
        rlink = chr.spath + locationTemplate + chr.region + ':' + xs + '-' + xe;
      }
      var p = sector(cx, cy, r, a1, a2, params);
      p.node.onclick = function() {
        document.location = rlink;
      };
      chrset.push(p);
      var label = label(a1 + ((a2 - a1) / 2), chr.region);

    } else {
      // drawn chromosome segements
      var sAngle = a1;
      var eAngle = a1 + tickSize;
      var rLen = parseInt(chr.len * tickSize / (a2 - a1)); // size of the tick in bps
      var rStart = 1;
      var rEnd = rStart + rLen;

      var segment = function(x, y, r, sa, ea, prm, c) {

        prm.stroke = "white";
        var ps = sector(x, y, r, sa, ea, prm);
        
        var segs = rStart;
        var sege = rEnd;
        if (rLen > maxRegion) {
          var rc = (rEnd - rStart) >> 1;
          segs = rc - (maxRegion >> 1);
          sege = segs + maxRegion;
        }
        var rlink = c.spath + locationTemplate + c.region + ':' + segs +'-'+sege;

        ps.node.onclick = function() {
          document.location = rlink;
        };
        chrset.push(ps);
       
        rStart = rEnd;
        rEnd = rStart + rLen;
      };
      
      var label = label(a1 + ((a2 - a1) / 2), chr.region);
      
      var first = sAngle
      while (eAngle < a2) {
        segment(cx, cy, r, sAngle, eAngle, params, chr);
        if (sAngle == first) chrset.push(arrow(sAngle + 1));
        sAngle += tickSize;
        eAngle += tickSize;
      }

      if (sAngle < a2) {
        segment(cx, cy, r, sAngle, a2, params, chr);
      }
    }
    
    // add mouseover action to chromosomes and labels
    mOver = function () {
      this.node.style.cursor = "pointer";
      chrset.attr({scale: [1.05, 1.05, cx, cy]});
      txt.attr({opacity: 1});
      highlight(j);
      label[0].attr({"fill":"#eeeeee"});
      if (!$.browser.msie && !$.browser.opera) label.toFront(); // toFront() breaks ie and opera, info http://github.com/DmitryBaranovskiy/raphael/issues#issue/126
    }
    mOut = function () {
      this.node.style.cursor = null;
      chrset.attr({scale: [1, 1, cx, cy]});
      txt.attr({opacity: 0});
      unhighlight(j);
      label[0].attr({"fill":"white"});
    }
    chrset.mouseover(mOver).mouseout(mOut);
    label.mouseover(mOver).mouseout(mOut);


    return chrset;
  }
  
  function highlight(rid) {
    for (var i=0; i<ribbons.length; i++) {
      var ribbon = ribbons[i];
      if (rid != ribbon.pid && rid != ribbon.sid) {
        ribbon.r.attr({opacity:0});
      } else {
        var c = ribbon.sameStrand ? colours[ribbon.sid == rid ? ribbon.pid : ribbon.sid] : 'black' ;
        ribbon.r.attr({stroke: c, fill: c});
      }
    }
  }

  function unhighlight(rid) {
    for (var i=0; i<ribbons.length; i++) {
      var ribbon = ribbons[i];
      if (rid != ribbon.pid && rid != ribbon.sid) {
        ribbon.r.attr({opacity:0.2});
      }
    }
  }

  function drawKaryotypes(cx, cy, r, rs) {
    var angle = 0,
    ms = 200,
    process = function (j, o) {
      var value = rs[j].len,
      angleplus = 360 * value / total,
      txt = paper.text(hintX, hintY, 'Current reference:   ' +  rs[j].species+' '+rs[j].region).attr(
        {'background-color':colours[j], fill: 'black', stroke: "none", opacity: 0, "font-weight":"bold", "font-family": 'Fontin-Sans, Arial', "font-size": "12px", "text-anchor": "middle"}
      ),
      p1 = drawChromosome(cx, cy, r, angle, angle + angleplus, {opacity:o, fill:colours[j], stroke: "none", "stroke-width": 1}, rs[j], j, txt);
      angle += angleplus;
    };

    var colourSet = [
      "hsb(1, 1, 1)",
      "hsb(0.3, 1, 1)",
      "hsb(0.6, 1, 1)",
      "hsb(0.5, 1, 1)",
      "hsb(0.8, 1, 1)",
      "hsb(0.2, 1, 1)",
      "hsb(0.1, 1, 1)",
      "hsb(0.9, 1, 1)",
      "hsb(0.4, 1, 1)",
      "hsb(0.7, 1, 1)"
    ];

    // Draw legend on the right, calculate the total length in bps and
    // build an array of joints - at which point one chromosome ends and
    // another starts
    var sc = 0;
    var ii = rs.length;
    for (var i = 0; i < ii; i++) {
      joints[i] = total;
      total += rs[i].len;

      if ((i == 0) || (rs[i].species != rs[i-1].species)) {
			  colours[i] = colourSet.pop();
	      paper.circle(cx + r + 110 , cy - r + sc * 30, 10).attr({fill:colours[i], opacity:1, stroke:"none"});
			  paper.text(cx + r + 130, cy - r + sc * 30, rs[i].species).attr({fill:colours[i], "text-anchor": "start"});
			  sc++;
      } else {
        colours[i] = colours[i-1];
      }
    }

    // draw the inversion legend
    paper.circle(cx + r + 110, cy - r + 15 + sc * 30, 10).attr({fill:'black', opacity:0.5, stroke:"none"});
	  paper.text(cx + r + 130, cy - r + 15 + sc * 30, 'Inversion').attr({fill:'black', opacity:0.5, "text-anchor": "start"});
    
    // draw the sacle bar
    scaleBar(cx + r + 110, cy + r);
    
    // Now draw the chromosome sectors, with alternating opacity for different chromosomes of
    // the same species
    var opa = 0.3;
    for (var j = 0; j < ii; j++) {
      if ((j > 0) && (rs[j].species == rs[j-1].species)) {
        opa *= -1;
      } else {
        opa = 0.3;
      }
      process(j, 0.5 + opa);
    }

    // And finally a white circle
    paper.circle(cx, cy, r - 20).attr({fill:"white"});
  }
  
  function sector(cx, cy, r, startAngle, endAngle, params) {
    var x1 = cx + r * Math.cos(startAngle * rad),
        x2 = cx + r * Math.cos(endAngle * rad),
        y1 = cy + r * Math.sin(startAngle * rad),
        y2 = cy + r * Math.sin(endAngle * rad);
    return paper.path(["M", cx, cy, "L", x2, y2, "A", r, r, 0, +(Math.abs(endAngle - startAngle) > 180), 0, x1, y1, "z"]).attr(params);
  }

  function scaleBar(x, y) {
    var cx = x;
    var cy = y + r;
    var scale = parseInt(tickSize * total / 360);
    var label = scale < 1000 ? scale + 'bp' : (scale < 1000000 ? parseInt(scale/1000) + 'kbp' : parseFloat(scale/1000000).toPrecision(2) + 'Mbp');
    var startAngle = 270 - tickSize / 2;
    var endAngle = 270 + tickSize / 2;
    
    var arcx1 = cx + r * Math.cos(startAngle * rad),
        arcy1 = cy + r * Math.sin(startAngle * rad),
        arcx2 = cx + r * Math.cos(endAngle * rad),
        arcy2 = cy + r * Math.sin(endAngle * rad),
        x1 = cx + (r + 20) * Math.cos(startAngle * rad),
        y1 = cy + (r + 20) * Math.sin(startAngle * rad),
        x2 = cx + (r + 20) * Math.cos(endAngle * rad),
        y2 = cy + (r + 20) * Math.sin(endAngle * rad);
    
    var txt1 = paper.text(cx, y1 - 10, 'Scale').attr({fill:'black', opacity:0.5});
    var bar = paper.path(["M", x2, y2, "L", arcx2, arcy2, "A", r, r, 0, +(Math.abs(endAngle - startAngle) > 180), 0, arcx1, arcy1, "L", x1, y1]).attr({stroke: "black", "stroke-width": 1});
    var txt2 = paper.text(cx, y1 + 30, label).attr({fill:'black', opacity:0.5});
    return paper.set(txt1, bar, txt2);
  }

  function ribbon(cx, cy, r, s1, s2, d1, d2, c1, c2, txt, link) {
    var x1 = cx + r * Math.cos(s1 * rad),
        x2 = cx + r * Math.cos(s2 * rad),
        y1 = cy + r * Math.sin(s1 * rad),
        y2 = cy + r * Math.sin(s2 * rad);

    var x3 = cx + r * Math.cos(d1 * rad),
        x4 = cx + r * Math.cos(d2 * rad),
        y3 = cy + r * Math.sin(d1 * rad),
        y4 = cy + r * Math.sin(d2 * rad);
    
    var ax1 = x1 + (x4 - x1) / 2;
    var cpx1 = cx + (ax1 - cx) /2;

    var ay1 = y1 + (y4 - y1) / 2;
    var cpy1 = cy + (ay1 - cy) /2;

    var ax2 = x2 + (x3 - x2) / 2;
    var cpx2 = cx + (ax2 - cx) /2;

    var ay2 = y2 + (y3 - y2) / 2;
    var cpy2 = cy + (ay2 - cy) /2;

    return paper.path(["M", x2, y2, "A", r, r, 0,+(s1 - s2 > 180), 0, x1, y1, "Q", cpx1, cpy1, x4, y4, "A", r, r, 0,+(d1 - d2 > 180), 0, x3, y3, "Q", cpx2, cpy2, x2, y2, "z"]).attr({fill:c1, stroke:c1, "stroke-width":1, opacity:.3});
  }

  drawKaryotypes(cx, cy, r, rs);
  drawSynteny(cx, cy, r, ds);
};

