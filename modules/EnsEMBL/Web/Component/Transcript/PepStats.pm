=head1 LICENSE

Copyright [2009-2024] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Transcript::PepStats;

sub content {
  my $self = shift;
  my $hub        = $self->hub;
  my $protein   = $self->param('p') || '';
  my $object = $self->object;
  
  my $tl;
  if ($object->Obj->translation->stable_id eq $protein) {
    $tl = $object->Obj->translation; 
  } elsif($object->Obj->get_all_alternative_translations) {
    foreach my $atrans (@{$object->Obj->get_all_alternative_translations}) {
      next if ($atrans->stable_id ne $protein);
      $tl = $atrans;
      last;
    }
  }

  return '' unless $tl;
  return '<p>Pepstats currently disabled for Prediction Transcripts</p>' unless $tl->stable_id;
  my $db_type = ($object->db_type eq 'Ensembl') ? 'core' : lc($object->db_type); #thought there was a better way to do this!
  my $attributeAdaptor = $object->database($db_type)->get_AttributeAdaptor();
  my $attributes = $attributeAdaptor->fetch_all_by_Translation($tl);

  my $stats_to_show = '';
  my @attributes_pepstats = grep {$_->description =~ /Pepstats/} @{$attributes};
  my $duplication = {};
  foreach my $stat (sort {$a->name cmp $b->name} @attributes_pepstats) {
      next if exists $duplication->{$stat->name.$stat->value};
      $duplication->{$stat->name.$stat->value} = 1;
      my $stat_string = $object->thousandify($stat->value);
      if ($stat->name =~ /weight/) {
	$stat_string .= ' g/mol';
      }
      elsif ($stat->name =~ /residues/) {
	$stat_string .= ' aa';
      }
      $stats_to_show .= sprintf("%s: %s<br />", $stat->name, $stat_string);
  }

  my $table  = new EnsEMBL::Web::Document::TwoCol;
  unless ($stats_to_show =~/^\w/){return;}
  $table->add_row('Statistics', "<p>$stats_to_show</p>");
  return $table->render;
}

1;
