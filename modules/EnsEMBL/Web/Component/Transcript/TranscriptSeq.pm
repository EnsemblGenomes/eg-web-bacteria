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

# $Id: TranscriptSeq.pm,v 1.3 2010-11-11 14:17:55 it2 Exp $

package EnsEMBL::Web::Component::Transcript::TranscriptSeq;


sub get_sequence_data {
  my $self = shift;
  my ($object, $config) = @_;
  
  my $hub          = $self->hub;
  my $p            = $self->param('p') || 0;
  my $trans        = $object->Obj;
  my @exons        = @{$trans->get_all_Exons};
  my $trans_strand = $exons[0]->strand;
  my $start_phase  = $exons[0]->phase;
  my $start_pad    = $start_phase > 0 ? $start_phase : 0; # Determines if the transcript starts mid-codon

  my $translation = $trans->translation;
  unless (($translation->stable_id eq $p) || (!$p))  {
    if($trans->get_all_alternative_translations) {
      foreach my $atrans (@{$trans->get_all_alternative_translations}) {
        next if ($atrans->stable_id ne $p);
        $translation = $atrans;
        last;
      }
    }
  }

  my $cd_start     = $trans->cdna_coding_start($translation);
  my $cd_end       = $trans->cdna_coding_end($translation);
  my $mk           = {};
  my $seq;
  
  if ($trans->translation) {
    my $five_prime  = $trans->five_prime_utr($translation);
    my $three_prime = $trans->three_prime_utr($translation);
    
    $_ = $_ ? $_->seq : $_ for $five_prime, $three_prime;

    $seq = join '', $five_prime, $trans->translateable_seq($p), $three_prime;
  } else {
    $seq = $trans->seq->seq;
  }
      
  my $length = length $seq;
  
  my @sequence;
  my @markup;

  my @reference_seq = map {{ letter => $_ }} split //, $seq;
  my $variation_seq = { name => 'variation',   seq => [] };
  my $coding_seq    = { name => 'coding_seq',  seq => [] };
  my $protein_seq   = { name => 'translation', seq => [] };
  my @rna_seq; 

  if ($config->{'rna'}) {
    my @rna_notation = $object->rna_notation;
    
    if (@rna_notation) {
      @rna_seq = map {{ name => 'rna', seq => [ map {{ letter => $_ }} split //, $_ ] }} @rna_notation;
    } else {
      $config->{'rna'} = 0;
    }
  }
  
  if ($config->{'exons'}) {
    my $flip = 0;
    my $pos = $start_pad;
    
    foreach (@exons) {
      $pos += length $_->seq->seq;
      $flip = 1 - $flip;
      push @{$mk->{'exons'}->{$pos}->{'type'}}, $mk->{'exons'}->{$pos}->{'overlap'} ? 'exon2' : "exon$flip";
    }
  }  
  
  delete $mk->{$length}; # We get a key which is too big, causing an empty span to be printed later 
    
  $config->{'length'}    = $length;
  $config->{'numbering'} = [1];
  $config->{'seq_order'} = [ $config->{'species'} ];
  $config->{'slices'}    = [{ slice => $seq, name => $config->{'species'} }];
  
  for (0..$length-1) {
    # Set default vaules
    $variation_seq->{'seq'}->[$_]->{'letter'} = ' ';
    $coding_seq->{'seq'}->[$_]->{'letter'}    = $protein_seq->{'seq'}->[$_]->{'letter'} = '.';
    
    if ($_+1 >= $cd_start && $_+1 <= $cd_end) {         
      $coding_seq->{'seq'}->[$_]->{'letter'} = $reference_seq[$_]->{'letter'} if $config->{'coding_seq'};
    } elsif ($config->{'codons'}) {
      $mk->{'codons'}->{$_}->{'class'} = 'cu';
    }
  }
  
  $_ += $start_pad for $cd_start, $cd_end; # Shift values so that codons and variations appear in the right place
  
  my $can_translate = 0;
  
  eval {
    my $pep_obj    = $trans->translate($p);
    my $peptide    = $pep_obj->seq;
    my $flip       = 0;
    my $startphase = $translation->start_Exon->phase;
    my $s          = 0;
    
    $can_translate = 1;
    
    if ($startphase > 0) {
      $s = 3 - $startphase;
      $peptide = substr $peptide, 1;
    }
    
    for (my $i = $cd_start + $s - 1; $i + 2 <= $cd_end; $i += 3) {
      if ($config->{'codons'}) {
        $mk->{'codons'}->{$i}->{'class'} = $mk->{'codons'}->{$i+1}->{'class'} = $mk->{'codons'}->{$i+2}->{'class'} = "c$flip";
        
        $flip = 1 - $flip;
      }
      
      if ($config->{'translation'}) {        
        $protein_seq->{'seq'}->[$i]->{'letter'} = $protein_seq->{'seq'}->[$i+2]->{'letter'} = '-';
        $protein_seq->{'seq'}->[$i+1]->{'letter'} = substr($peptide, int(($i + 1 - $cd_start) / 3), 1) || ($i + 1 < $cd_end ? '*' : '.');
      }
    }
  };
  
  # If the transcript starts mid-codon, make the protein sequence show -X- at the start
  if ($config->{'translation'} && $start_pad) {
    my $pos     = scalar grep $protein_seq->{'seq'}->[$_]->{'letter'} eq '.', 0..2; # Find the number of . characters at the start
    my @partial = qw(- X -);
    
    $protein_seq->{'seq'}->[$pos]->{'letter'} = $partial[$pos] while $pos--; # Replace . with as much of -X- as fits in the space
  }
  
  if ($config->{'variation'}) {
    my $slice  = $trans->feature_Slice;
    my $filter = $self->param('population_filter');
    my %population_filter;
    
    if ($filter && $filter ne 'off') {
      %population_filter = map { $_->dbID => $_ }
        @{$slice->get_all_VariationFeatures_by_Population(
          $hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($filter), 
          $self->param('min_frequency')
        )};
    }
    
    foreach my $transcript_variation (@{$object->get_transcript_variations}) {
      my ($start, $end) = ($transcript_variation->cdna_start, $transcript_variation->cdna_end);
      
      next unless $start && $end;
      
      my $var  = $transcript_variation->variation_feature->transfer($slice);
      my $dbID = $var->dbID;
      
      next if keys %population_filter && !$population_filter{$dbID};
      
      my $variation_name    = $var->variation_name;
      my $alleles           = $var->allele_string;
      my $ambigcode         = $var->ambig_code || '*';
      my $pep_allele_string = $transcript_variation->pep_allele_string;
      my $amino_acid_pos    = $transcript_variation->translation_start * 3 + $cd_start - 4 - $start_pad;
      my $consequence_type  = join ' ', @{$transcript_variation->consequence_type};
      my $aa_change         = $consequence_type =~ /\b(NON_SYNONYMOUS_CODING|FRAMESHIFT_CODING|STOP_LOST|STOP_GAINED)\b/;
      my $type              = lc $transcript_variation->display_consequence;
      
      if ($var->strand == -1 && $trans_strand == -1) {
        $ambigcode =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
        $alleles   =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
      }
      
      # Variation is an insert if start > end
      ($start, $end) = ($end, $start) if $start > $end;
      
      ($_ += $start_pad)-- for $start, $end; # Adjust from start = 1 (slice coords) to start = 0 (sequence array)
      
      foreach ($start..$end) {
        $mk->{'variations'}->{$_}->{'alleles'}   .= ($mk->{'variations'}->{$_}->{'alleles'} ? ', ' : '') . $alleles;
        $mk->{'variations'}->{$_}->{'url_params'} = { v => $variation_name, vf => $dbID, vdb => 'variation' };
        $mk->{'variations'}->{$_}->{'transcript'} = 1;
        
        my $url = $mk->{'variations'}->{$_}->{'url_params'} ? $hub->url({ type => 'Variation', action => 'Summary', %{$mk->{'variations'}->{$_}->{'url_params'}} }) : '';
        
        $mk->{'variations'}->{$_}->{'type'} = $type;
        
        if ($config->{'translation'} && $aa_change) {
          $protein_seq->{'seq'}->[$amino_acid_pos]->{'letter'}     = 
          $protein_seq->{'seq'}->[$amino_acid_pos + 2]->{'letter'} = '=';
          
          foreach my $aa ($amino_acid_pos..$amino_acid_pos + 2) {
            $protein_seq->{'seq'}->[$aa]->{'class'}  = 'aa';
            $protein_seq->{'seq'}->[$aa]->{'title'} .= ', ' if $protein_seq->{'seq'}->[$aa]->{'title'};
            $protein_seq->{'seq'}->[$aa]->{'title'} .= $pep_allele_string;
          }
        }
        
        $mk->{'variations'}->{$_}->{'href'} ||= {
          type        => 'ZMenu',
          action      => 'TextSequence',
          factorytype => 'Location'
        };
        
        push @{$mk->{'variations'}->{$_}->{'href'}->{'v'}},  $variation_name;
        push @{$mk->{'variations'}->{$_}->{'href'}->{'vf'}}, $dbID;
        
        $variation_seq->{'seq'}->[$_]->{'letter'} = $url ? qq{<a href="$url" title="$variation_name">$ambigcode</a>} : $ambigcode;
        $variation_seq->{'seq'}->[$_]->{'url'}    = $url;
      }
    }
  }
  
  push @sequence, \@reference_seq;
  push @markup, $mk;

  my @seq_names = ( $config->{'species'} );
  for ($variation_seq, $coding_seq, $protein_seq, @rna_seq) {
    if ($config->{$_->{'name'}}) {
      if ($_->{'name'} eq 'variation') {
        unshift @sequence, $_->{'seq'};
        unshift @markup, {};
        unshift @{$config->{'numbering'}}, 0;
        unshift @{$config->{'seq_order'}}, $_->{'name'};
        unshift @{$config->{'slices'}}, { slice => join('', map $_->{'letter'}, @{$_->{'seq'}}), name => $_->{'name'} };
        unshift @seq_names,$_->{'name'};
      } else {
        push @sequence, $_->{'seq'};
        push @markup, {};
        push @{$config->{'numbering'}}, 1;
        push @{$config->{'seq_order'}}, $_->{'name'};
        push @{$config->{'slices'}}, { slice => join('', map $_->{'letter'}, @{$_->{'seq'}}), name => $_->{'name'} };
        push @seq_names,$_->{'name'};
      }
    }
  }
  
  # It's much easier to calculate the sequence with UTR, then lop off both ends than to do it without
  # If you don't include UTR from the begining, you run into problems with $cd_start and $cd_end being "wrong"
  # as well as transcript variation starts and ends. This way involves much less hassle.
  if (!$config->{'utr'}) {
    foreach (@sequence) {
      splice @$_, $cd_end;
      splice @$_, 0, $cd_start-1;
    }
    
    $length = scalar @{$sequence[0]};
    
    foreach my $mk (grep scalar keys %$_, @markup) {
      my $shifted;
      
      foreach my $type (keys %$mk) {
        my %tmp = map { $_-$cd_start+1 >= 0 && $_-$cd_start+1 < $length ? ($_-$cd_start+1 => $mk->{$type}->{$_}) : () } keys %{$mk->{$type}};
        $shifted->{$type} = \%tmp;
      }
      
      $mk = $shifted;
    }
  }
  
  # Used to set the initial sequence colour
  if ($config->{'exons'}) {
    $_->{'exons'}->{0}->{'type'} = [ 'exon0' ] for @markup;
  }
  
  return (\@sequence, \@markup, \@seq_names, $length);
}

1;
