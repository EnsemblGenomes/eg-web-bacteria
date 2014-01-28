package EnsEMBL::Web::Object::Location;

use strict;
use warnings;
no warnings 'uninitialized';

sub centrepoint      {
    return ( $_[0]->Obj->{'seq_region_end'} + $_[0]->Obj->{'seq_region_start'} ) / 2  if ($_[0]->Obj->{'seq_region_end'} >= $_[0]->Obj->{'seq_region_start'});
    my $cp = $_[0]->Obj->{'seq_region_start'} + ($_[0]->Obj->{'seq_region_end'} + $_[0]->Obj->{'seq_region_length'} - $_[0]->Obj->{'seq_region_start'})/2;

    if($cp > $_[0]->Obj->{'seq_region_length'}) {
	$cp = $cp - $_[0]->Obj->{'seq_region_length'} + 1;
    }
    return $cp;
}

sub length           {
    return   $_[0]->Obj->{'seq_region_end'} - $_[0]->Obj->{'seq_region_start'} + 1  if ($_[0]->Obj->{'seq_region_end'} >= $_[0]->Obj->{'seq_region_start'});
    return   $_[0]->Obj->{'seq_region_end'} + $_[0]->Obj->{'seq_region_length'} - $_[0]->Obj->{'seq_region_start'} + 1  if ($_[0]->Obj->{'seq_region_end'} <  $_[0]->Obj->{'seq_region_start'});
}



1;
