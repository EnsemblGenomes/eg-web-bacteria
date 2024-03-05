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
