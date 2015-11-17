/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

Ensembl.Panel.VEPResultsSummary = Ensembl.Panel.VEPResultsSummary.extend({
  init: function () {
    var panel = this;

    this.base();

// EG - we already have Raphael loaded, but still need to load graph libs
    if (typeof Raphael.g === 'undefined') {
      $.getScript('/raphael/g.raphael-min.js', function () {
        $.getScript('/raphael/g.pie-modified-min.js', function () { panel.getContent(); });
      });
    }
//
  }
});
