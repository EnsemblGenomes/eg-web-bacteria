package EnsEMBL::Web::Document::Element::Meta;

sub init {
  my $self = shift;
  $self->add('description', 'Ensembl Bacteria is a genome-centric portal for bacterial species of scientific interest');
  $self->add('keywords', 'Ensembl, Ensembl Genomes, genome, genome browser, comparative genomics, variation, SNPs, EST, mRNA, rna-Seq, orthologs, paralogs, synteny, assembly, genes, transcripts, translations, proteins, Escherichia coli, E.coli, Bacillus subtillis, B. subtilis, archaea, bacteria');
  $self->add('google-site-verification', 'tC5CRODhAwiBEeIZY_EP_k7AaLGupandW7e1v3_s8ak');
}

1;
