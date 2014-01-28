package EnsEMBL::Web::Component::UserData::IDmapper;

use strict;

use Bio::EnsEMBL::StableIdHistoryTree;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Component::UserData);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $html       = '<h2>Stable ID Mapper Results:</h2>';
  my $size_limit = $hub->param('id_limit'); 
  my @files      = $hub->param('convert_file');

  foreach my $file_name (@files) {
    my ($file, $name)    = split ':', $file_name;
    my ($ids, $unmapped) = @{$object->get_stable_id_history_data($file, $size_limit)}; 
    
    $html .= $self->format_mapped_ids($ids);
## Bacteria
#    $html .= $self->_info('Information', '<p>The numbers in the above table indicate the version of a stable ID present in a particular release.</p>', '100%');
## /Bacteria
    $html .= $self->add_unmapped_ids($unmapped) if scalar keys %$unmapped > 0;
  }

  return $html;
}    

sub format_mapped_ids { 
  my ($self, $ids) = @_;
  my %stable_ids       = %$ids;
  my $earliest_archive = $self->object->get_earliest_archive;
  
  return '<p>No IDs were succesfully converted</p>' if scalar keys %stable_ids < 1;
  
  my $table = $self->new_table([], [], { margin => '1em 0px' });
  
  $table->add_columns(
    { key => 'request', align => 'left', title => 'Requested ID'  },
    { key => 'match',   align => 'left', title => 'Matched ID(s)' },
    { key => 'rel',     align => 'left', title => 'Releases:'     },
  );
  
  my (%releases, @rows);

  foreach my $req_id (sort keys %stable_ids) {
    my %matches;
    warn $req_id;
    warn "REF " .  ref $stable_ids{$req_id}->[1];
    
    foreach (@{$stable_ids{$req_id}->[1]->get_all_ArchiveStableIds}) {
      warn "----------------------------------------------------------------------------\n";

## Bacteria
#      my $linked_text = $_->version;
      
      $releases{$_->release} = 1; 
#            
#      if ($_->release > $earliest_archive) {
#        my $archive_link = $self->archive_link($stable_ids{$req_id}[0], $_->stable_id, $_->version, $_->release);
#           $linked_text  = qq{<a href="$archive_link">$linked_text</a>} if $archive_link;
#      }
#      
#      $matches{$_->stable_id}{$_->release} = $linked_text; 

      $matches{$_->stable_id}{$_->release} = '&#10004;'; # html tick symbol
    }
    
    # self matches
    push @rows, {
      request => $self->idhistoryview_link($stable_ids{$req_id}->[0], $req_id),
      match   => $req_id,
      rel     => '',
       %{$matches{$req_id}}
    };

    # other matches
    foreach (sort keys %matches) {
      next if $_ eq $req_id;
      
      push @rows, {
        request => '',
#        match   => $_,
        match   =>  $self->idhistoryview_link($stable_ids{$_}->[0] || 'Gene', $_),
        rel     => '',
        %{$matches{$_}},
      };
    }
  } 
## /Bacteria  

  $table->add_columns({ key => $_, align => 'left', title => $_ }) for sort { $a <=> $b } keys %releases;
  $table->add_rows(@rows);

  return $table->render;
}

1;
