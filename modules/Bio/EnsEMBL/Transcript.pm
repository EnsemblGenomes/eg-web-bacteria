package Bio::EnsEMBL::Transcript;

=head2 translateable_seq

  Args       : (optional) $protein
  Example    : print $transcript->translateable_seq(), "\n";
  Description: Returns a sequence string which is the the translateable part
               of the transcripts sequence.  This is formed by splicing all
               Exon sequences together and apply all defined RNA edits.
               Then the coding part of the sequence is extracted and returned.
               The code will not support monkey exons any more. If you want to
               have non phase matching exons, defined appropriate _rna_edit
               attributes!

               An empty string is returned if this transcript is a pseudogene
               (i.e. is non-translateable).
  Returntype : txt
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub translateable_seq {
  my ( $self, $protein ) = @_;

  if ( !$self->translation() ) {
    return '';
  }

  my $mrna = $self->spliced_seq();

  my $start_phase;
  my $translation = $self->translation;
  if (($translation->stable_id eq $protein) || (!$protein))  {
    $start_phase = $translation->start_Exon->phase();
  } else {
    if($self->get_all_alternative_translations) {
      foreach my $atrans (@{$self->get_all_alternative_translations}) {
        next if ($atrans->stable_id ne $protein);
        $start_phase = $atrans->start_Exon->phase();
        $translation = $atrans;
	last;
      }
    } else {
      return '';
    }
  }

  
  my $start = $self->cdna_coding_start($translation);
  my $end   = $self->cdna_coding_end($translation);

  $mrna = substr( $mrna, $start - 1, $end - $start + 1 );


  #my $start_phase = $self->translation->start_Exon->phase();
  if( $start_phase > 0 ) {
    $mrna = "N"x$start_phase . $mrna;
  }
  if( ! $start || ! $end ) {
    return "";
  }

  return $mrna;
}


=head2 cdna_coding_start

  Arg [1]    : (optional) $value
  Arg [2]    : (optional) Bio::EnsEMBL::Translation  $translation
  Example    : $relative_coding_start = $transcript->cdna_coding_start;
  Description: Retrieves the position of the coding start of this transcript
               in cdna coordinates (relative to the start of the 5prime end of
               the transcript, excluding introns, including utrs).

               This will return undef if this is a pseudogene (i.e. a
               transcript with no translation).
  Returntype : int
  Exceptions : none
  Caller     : five_prime_utr, get_all_snps, general
  Status     : Stable

=cut

sub cdna_coding_start {
  my $self = shift;
  my $translation = shift;

  $translation ||= $self->translation;

  if( @_ ) {
    $self->{'cdna_coding_start'} = shift;
  }

  if(!defined $self->{'cdna_coding_start'} && defined $translation){
    # calc coding start relative from the start of translation (in cdna coords)
    my $start = 0;

    my @exons = @{$self->get_all_Exons};
    my $exon;


    while($exon = shift @exons) {
      if($exon == $translation->start_Exon) {
        #add the utr portion of the start exon
        $start += $translation->start;
        last;
      } else {
        #add the entire length of this non-coding exon
        $start += $exon->length;
      }
    }

    # adjust cdna coords if sequence edits are enabled
    if($self->edits_enabled()) {
      my @seqeds = @{$self->get_all_SeqEdits()};
      # sort in reverse order to avoid adjustment of downstream edits
      @seqeds = sort {$b->start() <=> $a->start()} @seqeds;

      foreach my $se (@seqeds) {
        # use less than start so that start of CDS can be extended
        if($se->start() < $start) {
          $start += $se->length_diff();
        }
      }
    }

    $self->{'cdna_coding_start'} = $start;
  }

  return $self->{'cdna_coding_start'};
}


=head2 cdna_coding_end

  Arg [1]    : (optional) $value
  Arg [2]    : (optional) Bio::EnsEMBL::Translation  $translation
  Example    : $cdna_coding_end = $transcript->cdna_coding_end;
  Description: Retrieves the end of the coding region of this transcript in
               cdna coordinates (relative to the five prime end of the
               transcript, excluding introns, including utrs).

               This will return undef if this transcript is a pseudogene
               (i.e. a transcript with no translation and therefor no CDS).
  Returntype : int
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub cdna_coding_end {
  my $self = shift;
  my $translation = shift;

  $translation ||= $self->translation;

  if( @_ ) {
    $self->{'cdna_coding_end'} = shift;
  }

  if(!defined $self->{'cdna_coding_end'} && defined $translation) {
    my @exons = @{$self->get_all_Exons};

    my $end = 0;
    while(my $exon = shift @exons) {
      if($exon == $translation->end_Exon) {
        # add coding portion of the final coding exon
        $end += $translation->end;
        last;
      } else {
        # add entire exon
        $end += $exon->length;
      }
    }

    # adjust cdna coords if sequence edits are enabled
    if($self->edits_enabled()) {
      my @seqeds = @{$self->get_all_SeqEdits()};
      # sort in reverse order to avoid adjustment of downstream edits
      @seqeds = sort {$b->start() <=> $a->start()} @seqeds;

      foreach my $se (@seqeds) {
        # use less than or equal to end+1 so end of the CDS can be extended
        if($se->start() <= $end + 1) {
          $end += $se->length_diff();
        }
      }
    }

    $self->{'cdna_coding_end'} = $end;
  }

  return $self->{'cdna_coding_end'};
}


=head2 five_prime_utr

  Arg [1]    : none
  Arg [2]    : (optional) Bio::EnsEMBL::Translation  $translation
  Example    : my $five_prime  = $transcrpt->five_prime_utr
                 or warn "No five prime UTR";
  Description: Obtains a Bio::Seq object of the five prime UTR of this
               transcript.  If this transcript is a pseudogene
               (i.e. non-translating) or has no five prime UTR undef is
               returned instead.
  Returntype : Bio::Seq or undef
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub five_prime_utr {
  my $self = shift;
  my $translation = shift;

  $translation ||= undef;

  my $cdna_coding_start  = $self->cdna_coding_start($translation);

  return undef if(!$cdna_coding_start);

  my $seq = substr($self->spliced_seq, 0, $cdna_coding_start - 1);

  return undef if(!$seq);

  return
    Bio::Seq->new( -id       => $self->display_id,
                   -moltype  => 'dna',
                   -alphabet => 'dna',
                   -seq      => $seq );
}


=head2 three_prime_utr

  Arg [1]    : none
  Arg [2]    : (optional) Bio::EnsEMBL::Translation  $translation
  Example    : my $three_prime  = $transcrpt->three_prime_utr
                 or warn "No five prime UTR";
  Description: Obtains a Bio::Seq object of the three prime UTR of this
               transcript.  If this transcript is a pseudogene
               (i.e. non-translating) or has no three prime UTR,
               undef is returned instead.
  Returntype : Bio::Seq or undef
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub three_prime_utr {
  my $self = shift;
  my $translation = shift;

  $translation ||= undef;

  my $cdna_coding_end = $self->cdna_coding_end($translation);

  return undef if(!$cdna_coding_end);

  my $seq = substr($self->spliced_seq, $cdna_coding_end);

  return undef if(!$seq);

  return
    Bio::Seq->new( -id       => $self->display_id,
                   -moltype  => 'dna',
                   -alphabet => 'dna',
                   -seq      => $seq );
}


=head2 translate

  Args       : (optional) $protein
  Example    : none
  Description: Return the peptide (plus eventual stop codon) for
               this transcript.  Does N-padding of non-phase
               matching exons.  It uses translateable_seq
               internally.  Returns undef if this Transcript does
               not have a translation (i.e. pseudogene).
  Returntype : Bio::Seq or undef
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub translate {
  my ($self, $protein) = @_;

  if ( !defined( $self->translation() ) ) { return undef }

  my $mrna = $self->translateable_seq($protein);

  # Alternative codon tables (such as the mitochondrial codon table)
  # can be specified for a sequence region via the seq_region_attrib
  # table.  A list of codon tables and their codes is at:
  # http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wprintgc?mode=c

  my $codon_table_id;
  my ( $complete5, $complete3 );
  if ( defined( $self->slice() ) ) {
    my $attrib;

    ($attrib) = @{ $self->slice()->get_all_Attributes('codon_table') };
    if ( defined($attrib) ) {
      $codon_table_id = $attrib->value();
    }

    ($attrib) = @{ $self->slice()->get_all_Attributes('complete5') };
    if ( defined($attrib) ) {
      $complete5 = $attrib->value();
    }

    ($attrib) = @{ $self->slice()->get_all_Attributes('complete3') };
    if ( defined($attrib) ) {
      $complete3 = $attrib->value();
    }
  }
  $codon_table_id ||= 1;    # default vertebrate codon table

  # Remove final stop codon from the mrna if it is present.  Produced
  # peptides will not have '*' at end.  If terminal stop codon is
  # desired call translatable_seq directly and produce a translation
  # from it.

  if ( CORE::length($mrna) % 3 == 0 ) {
    my $codon_table =
      Bio::Tools::CodonTable->new( -id => $codon_table_id );

    if ( $codon_table->is_ter_codon( substr( $mrna, -3, 3 ) ) ) {
      substr( $mrna, -3, 3, '' );
    }
  }

  if ( CORE::length($mrna) < 1 ) { return undef }

  my $display_id = $self->translation->display_id()
    || scalar( $self->translation() );

  my $peptide = Bio::Seq->new( -seq      => $mrna,
                               -moltype  => 'dna',
                               -alphabet => 'dna',
                               -id       => $display_id );

  my $translation =
    $peptide->translate( undef, undef, undef, $codon_table_id, undef,
                         undef, $complete5, $complete3 );

  if ( $self->edits_enabled() ) {
    $self->translation()->modify_translation($translation);
  }

  return $translation;
} ## end sub translate


1;

