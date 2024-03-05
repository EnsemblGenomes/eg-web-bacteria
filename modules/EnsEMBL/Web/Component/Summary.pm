=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2024] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Summary;

### Content that needs to appear on both Gene and Transcript pages

use strict;

sub get_synonym_html { 
  my $self = shift;
  my $object = $self->object;

  my $html;
  my ($display_name) = $object->display_xref;
  if (my $xref = $object->Obj->display_xref) {
    if (my $sn = $xref->get_all_synonyms) {
      $html = sprintf '<p>%s</p>', join(', ', grep { $_ && ($_ ne $display_name) } @$sn);
    }
  }
  return $html;
}

sub transcript_name {
  my ($self, $transcript) = @_;
  return { value => $_->display_xref ? $_->display_xref->display_id : 'Novel', class => 'bold' };
}

sub protein_action {
  my ($self, $id) = @_;
  return "ProteinSummary_".$id;
}

1;
