use strict;
use warnings;

package Bio::EnsEMBL::Funcgen::DBSQL::SetFeatureAdaptor;
 

sub fetch_all_by_Slice_FeatureType {
    my ($self, $slice, $type, $logic_name) = @_;

    $self->db->is_stored_and_valid('Bio::EnsEMBL::Funcgen::FeatureType', $type);

    my $ft_id = $type->dbID();

  my $constraint = $self->_main_table->[1].".feature_set_id = fs.feature_set_id AND ".
      "fs.feature_type_id = '$ft_id'";

    $constraint = $self->_logic_name_to_constraint($constraint, $logic_name);

    return $self->fetch_all_by_Slice_constraint($slice, $constraint);
}

sub fetch_all_by_Slice_FeatureSets {
    my ($self, $slice, $fsets, $logic_name) = @_;

  my $constraint = $self->_main_table->[1].'.feature_set_id '.
      $self->_generate_feature_set_id_clause($fsets);

  #could have individual logic_names for each annotated feature here?
    $constraint = $self->_logic_name_to_constraint($constraint, $logic_name);

    return $self->fetch_all_by_Slice_constraint($slice, $constraint);
}


sub fetch_all_by_Slice_constraint {
  my ($self, $slice, $constraint) = @_;
	
# Circular staff: should be handled in BaseFeatureAdaptor

  if($slice->start() >  $slice->end()) {
     my $sl1= Bio::EnsEMBL::Slice->new(-COORD_SYSTEM      => $slice->coord_system(),
                                    -SEQ_REGION_NAME    => $slice->seq_region_name(),
                                    -SEQ_REGION_LENGTH  => $slice->seq_region_length(),
                                    -START              => $slice->start(),
                                    -END                => $slice->seq_region_length(),
                                    -STRAND             => $slice->strand(),
				       -ADAPTOR            => $slice->adaptor());

     my $sl2= Bio::EnsEMBL::Slice->new(-COORD_SYSTEM      => $slice->coord_system(),
                                    -SEQ_REGION_NAME    => $slice->seq_region_name(),
                                    -SEQ_REGION_LENGTH  => $slice->seq_region_length(),
                                    -START              => 1,
                                    -END                => $slice->end(),
                                    -STRAND             => $slice->strand(),
				       -ADAPTOR            => $slice->adaptor());

     my (@arr, @arr1, @arr2);
     @arr1 =  @{$self->SUPER::fetch_all_by_Slice_constraint($sl1, $constraint)};
     @arr2 =  @{$self->SUPER::fetch_all_by_Slice_constraint($sl2, $constraint)};
     push @arr, @arr1, @arr2;
     return \@arr;
 } else {
     return $self->SUPER::fetch_all_by_Slice_constraint($slice, $constraint);
 }

}


1;
