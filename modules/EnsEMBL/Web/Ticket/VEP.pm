=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Ticket::VEP;

use strict;
use warnings;


sub init_from_user_input {
  ## Abstract method implementation
  my $self      = shift;
  my $hub       = $self->hub;
  my $species   = $hub->param('species');
  my $file      = EnsEMBL::Web::File::Tools->new('hub' => $hub, 'tool' => 'VEP', 'empty' => 1);
  my $method    = first { $hub->param($_) } qw(file url userdata text);

  # if no data entered
  throw exception('InputError', 'No input data has been entered') unless $method;

  my ($file_name, $file_path, $description);

  # if input is one of the existing files
  if ($method eq 'userdata') {

    my $session_data = $hub->session->get_data('type' => 'upload', 'code' => $hub->param('userdata'));
    $description  = 'user data';

    $file->init('file' => $session_data->{'file'});

  # if new file, url or text, upload it to a temporary file location
  } else {

    $description = $hub->param('name') || ($method eq 'text' ? 'pasted data' : ($method eq 'url' ? 'data from URL' : sprintf("%s", $hub->param('file'))));

    ## NB: no need to init the file object, as upload method will do this
    my $error = $file->upload('type' => 'no_attach');
    throw exception('InputError', $error) if $error;

    $file_name = $file->write_name;
  }

  # finalise input file path and description
  $file_path    = $file->absolute_write_path;
  $description  = "VEP analysis of $description in $species";
  $file_name    = "$file_name.txt" if $file_name !~ /\./ && -T $file_path;
  $file_name    = $file_name =~ s/.*\///r;

  # detect file format
  my $detected_format;
  try {
    first { m/^[^\#]/ && ($detected_format = detect_format($_)) } file_get_contents($file_path); #  @{$file->read_lines->{'content'}};
  } catch {
    throw exception('InputError', sprintf(q(The input format is invalid or not recognised. Please <a href="%s" rel="external">click here</a> to find out about accepted data formats.), VEP_FORMAT_DOC), {'message_is_html' => 1});
  };

  ## Update session with detected format
  my $session_data = $hub->session->get_data('code' => $file->code);
  $session_data->{'format'} = $detected_format;
  $hub->session->set_data(%$session_data);

  my $job_data = { map { my @val = $hub->param($_); $_ => @val > 1 ? \@val : $val[0] } grep { $_ !~ /^text/ && $_ ne 'file' } $hub->param };

  # check required
  if(my $required_string = $job_data->{required_params}) {
    my $fd = $self->object->get_form_details();

    for(split(';', $required_string)) {
      my ($main, @dependents) = split /\=|\,/;

      if($job_data->{$main} && $job_data->{$main} eq $main) {

        foreach my $dep(@dependents) {
          throw exception(
            'InputError',
            sprintf(
              'No value has been entered for the field "%s"',
              defined($fd->{$dep}) ? ($fd->{$dep}->{label} || $dep) : $dep
            )
          ) unless defined($job_data->{$dep});
        }
      }
    }
  }

  $job_data->{'species'}    = $species;
  $job_data->{'input_file'} = $file_name;
  $job_data->{'format'}     = $detected_format;

  $self->add_job(EnsEMBL::Web::Job::VEP->new($self, {
    'job_desc'    => $description,
    'species'     => $species,
## EG - Assembly can be empty for Bacteria    
     'assembly'    => $hub->species_defs->get_config($species, 'ASSEMBLY_VERSION') || '',
## EG
    'job_data'    => $job_data
  }, {
    $file_name    => {'location' => $file_path}
  }));
}

1;
