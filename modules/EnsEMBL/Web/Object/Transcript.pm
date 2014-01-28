# $Id: Transcript.pm,v 1.6 2013-01-28 14:01:05 ek3 Exp $

package EnsEMBL::Web::Object::Transcript;

=head2 translation_object

 Arg[1]      : none
 Example     : $ensembl_translation = $transdata->translation
 Description : returns the ensembl translation object if it exists on the transcript object
                else it creates it from the core-api.
 Return type : Bio::EnsEMBL::Translation

=cut

sub translation_object {
  my $self = shift;
  my $hub  = $self->hub;
  my $protein = $hub->param('p') || 0;

  unless (exists $self->{'data'}{'_translation'}) {
    my $translation = $self->transcript->translation;
    if (($translation) && (($translation->stable_id eq $protein) || (!$protein)) ) {
      my $translationObj = $self->new_object(
         'Translation', $translation, $self->__data
      );
      $translationObj->gene($self->gene);
      $translationObj->transcript($self->transcript);
      $self->{'data'}{'_translation'} = $translationObj;
     
    } else {
      if($self->transcript->get_all_alternative_translations) {
        foreach my $atrans (@{$self->transcript->get_all_alternative_translations}) {
	  next if ($atrans->stable_id ne $protein);
          my $translationObj = $self->new_object(
             'Translation', $atrans, $self->__data
	     );
	  $translationObj->gene($self->gene);
	  $translationObj->transcript($self->transcript);
	  $self->{'data'}{'_translation'} = $translationObj;
	  last;
	}
      } else  {
	$self->{'data'}{'_translation'} = undef;
      }
    }
  }
  return $self->{'data'}{'_translation'};
}

sub short_caption {
    my $self = shift;
    my $hub  = $self->hub;   
    my $p    = $hub->param('p');

    return 'Transcript-based displays' unless shift eq 'global';
    return ucfirst($self->Obj->type) . ': ' . $self->Obj->stable_id if $self->Obj->isa('EnsEMBL::Web::Fake');

    my $dxr   = $self->Obj->can('display_xref') ? $self->Obj->display_xref : undef;
    my $label = $dxr ? $dxr->display_id : $self->Obj->stable_id;
 
    return "Protein: $p" if $p;
    return length $label < 15 ? "Transcript: $label" : "Trans: $label" if($label);

}


1;
