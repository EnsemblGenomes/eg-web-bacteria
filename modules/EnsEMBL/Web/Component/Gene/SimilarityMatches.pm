=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::SimilarityMatches;


sub matches_to_html {
  my $self           = shift;
  my @dbtypes          = @_;
  my $hub            = $self->hub;
  my $count_ext_refs = 0;
  my (@rows, $html);

  my @columns = ({ 
                  key        => 'transcriptid',
                  title      => 'Transcript ID',
                  align      => 'left',
                  sort       => 'string',
                });

  my (%seen, %hidden_columns, %columns_with_data);

  my @other_columns = @{$hub->species_defs->DEFAULT_XREFS||[]};
  foreach (@other_columns) {
    $_ =~ s/_/ /g;
    push @columns, {
                   key    => $_,
                   title  => $self->format_column_header($_),
                   align  => 'left',
                   sort   => 'string',
                  };
    $seen{$_} = 1;
    $hidden_columns{$_} = 0;
  }

  my @all_xref_types = keys %{$hub->species_defs->XREF_TYPES||{}};
  foreach (sort @all_xref_types) {
    next if $seen{$_};  
    push @columns, {
                    key    => $_,
                    title  => $self->format_column_header($_),
                    align  => 'left',
                    sort   => 'string',
                   };
    $hidden_columns{$_} = 1;
  }
  

  foreach my $transcript (@{$self->object->Obj->get_all_Transcripts}) {
    my $url = sprintf '<a href="%s">%s</a>', $hub->url({ type => 'Transcript', action => 'Summary', function => undef, t => $transcript->stable_id }), $transcript->stable_id;
    my $row = { 'transcriptid' => $url };
    $columns_with_data{'transcriptid'} = 1;

    foreach my $db_entry ($self->get_matches_by_transcript($transcript, @dbtypes)) {
      my $key = $db_entry->db_display_name;
      my %matches = $self->get_similarity_links_hash($db_entry);

      $row->{$key} .= ' ' if defined $row->{$key};
      $row->{$key} .=  $matches{'link'} ? sprintf('<a href="%s">%s</a>', $matches{'link'}, $matches{'link_text'})  : $matches{'link_text'};
      $count_ext_refs++;
      $columns_with_data{$key}++;
    }
    if (keys %$row) {
      push @rows, $row;
    }
  }
  @rows = sort { keys %{$b} <=> keys %{$a} } @rows; # show rows with the most information first

  ## Hide columns with no values, as well as those not shown by default
  my @hidden_cols;
  my $i = 0;
  foreach (@columns) {
    if ($hidden_columns{$_->{'key'}} || !$columns_with_data{$_->{'key'}}) {
      push @hidden_cols, $i;
    }
    $i++; 
  }  

  my $table = $self->new_table(\@columns, \@rows, { 
                                                data_table => 1, 
                                                exportable => 1, 
                                                hidden_columns => \@hidden_cols, 
                                              });

## EG - show a more generic message
  my $entry = lc(ref $self->object->Obj);
  $entry =~ s/bio::ensembl:://;
  
  if ($count_ext_refs == 0) {
    $html.= "<p><strong>No (selected) external database contains entities that describe this $entry.</strong></p>";
  } else {
    $html .= "<p><strong>This $entry is also described by the following entities in other databases:";
    $html .= $table->render;
  }
## EG  

  return $html;
}

1;
