package Monitor::Ultimagen::RunFolder;

use Moose;
use Carp;
use Readonly;
use File::Basename;
use File::Spec::Functions qw( catfile );
use DateTime;
use DateTime::Format::Strptime;
use Cwd qw( abs_path );
use Try::Tiny;
use XML::LibXML;

use npg_tracking::util::types;

use npg_tracking::Schema;

with qw[
  WTSI::DNAP::Utilities::Loggable
];

our $VERSION = '0';

# Pipeline Enums
Readonly::Scalar my $USERNAME => 'useq_pipeline';

# Run Enums
Readonly::Scalar my $RUN_UPLOADED_FILE => 'UploadCompleted.json';
Readonly::Scalar my $RUN_STATUS_MIRRORED => 'run mirrored';

Readonly::Scalar my $INSTRUMENT_NAME => 'V125';

=head1 NAME

Monitor::Ultimagen::RunFolder

=head1 VERSION

=head1 SYNOPSIS

C<<use Monitor::Ultimagen::RunFolder;
   my $run_folder = Monitor::Ultimagen::RunFolder->new(
     runfolder_path      => $run_folder,
     npg_tracking_schema => $schema
   )->process_run();>>

=head1 DESCRIPTION

Run monitor for an Ultimagen run folder.
 
=head1 SUBROUTINES/METHODS

=head2 runfolder_path

Directory path of the run folder.

=cut

has q{runfolder_path} => (
  isa           => q{NpgTrackingDirectory},
  is            => q{ro},
  required      => 1,
);

=head2 runfolder_glob

Parent directory of this run folder in the staging area.

=cut
has q{runfolder_glob}  => (
  isa             => q{Str},
  is              => q{ro},
  required        => 0,
  lazy_build      => 1,
);
sub _build_runfolder_glob {
  my $self = shift;
  return dirname(abs_path $self->runfolder_path);
}

=head2 npg_tracking_schema

Schema object for the tracking database connection.

=cut
has q{npg_tracking_schema}  => (
  isa        => 'npg_tracking::Schema',
  is         => q{ro},
  required   => 1,
);

=head2 tracking_run

<npg_tracking::Schema::Result::Run> object

The runs might have been registered already, in which case an existing record
is assigned to this attribute. Alternatively, a new run record is created and
assigned to this attribute.

An Ultimagen run is defined by the attributes ultimagen_runid,
id_instrument.

=cut
has q{tracking_run} => (
  isa           => q{npg_tracking::Schema::Result::Run},
  is            => q{ro},
  lazy          => 1,
  builder       => q{_build_tracking_run},
);
sub _build_tracking_run {
  my $self = shift;

  my $ultimagen_runid = $self->_get_ultimagen_run_attr('RunId');

  my $rs = $self->npg_tracking_schema->resultset('Run');
  my $run_row = $rs->find_with_attributes($ultimagen_runid, $INSTRUMENT_NAME);
  if ($run_row) {
    $self->info('Found run ' . $run_row->folder_name . ' with ID ' . $run_row->id_run);
    if ($run_row->folder_name ne $self->folder_name) {
      my $error = sprintf
        "Tracking run '%d - %s' has a different folder name from local folder '%s'",
        $run_row->flowcell_id, $run_row->folder_name, $self->folder_name;
      $self->logcroak($error);
    }
  } else {
    $self->info('Will create a new run for ' . $self->runfolder_path);
    my $data = {
      flowcell_id          => $ultimagen_runid,
      folder_name          => $self->folder_name,
      id_instrument        => $self->tracking_instrument()->id_instrument,
      folder_path_glob     => $self->runfolder_glob,
      team                 => 'SR',
      id_instrument_format => $self->tracking_instrument()->id_instrument_format,
      priority             => 1,
      is_paired            => 0,
      batch_id             => $self->_get_ultimagen_run_attr('Library_Pool')
    };

    my $transaction = sub {
      $run_row = $rs->create($data);
      $self->info('Created run ' . $run_row->folder_name . ' with ID ' . $run_row->id_run);

      my $runlane_rs = $run_row->result_source()->schema()->resultset('RunLane');
      $runlane_rs->create({id_run => $run_row->id_run, position => 1});
      $self->info("Created record for lane 1 of run_id " . $run_row->id_run);

      $run_row->update_run_status(
        'run in progress', $USERNAME, $self->date_created);
      $self->_set_tags();
    };
    $rs->result_source()->schema()->txn_do($transaction);
  }
  return $run_row;
}

=head2 tracking_instrument

C<npg_tracking::Schema::Result::Instrument> object representing an instrument
that performed the sequencing.

Error if the relevant database record does not exist.

=cut
has q{tracking_instrument} => (
  isa           => q{npg_tracking::Schema::Result::Instrument},
  is            => q{ro},
  lazy          => 1,
  builder       => q{_build_tracking_instrument},
);
sub _build_tracking_instrument {
  my $self = shift;
  my $rs = $self->npg_tracking_schema->resultset('Instrument');
  my $params = {
    external_name => $INSTRUMENT_NAME
  };
  my @instrument_rows = $rs->search($params)->all();

  my $instrument_count = scalar @instrument_rows;
  if ($instrument_count != 1) {
    $self->logcroak('No current or multiple instruments found in NPG tracking DB with name '
      . $INSTRUMENT_NAME);
  }

  my $instrument_row = $instrument_rows[0];
  $self->debug('Found instrument ' . $instrument_row->name());  
  return $instrument_row;
}

=head2 folder_name

Name of the runfolder directory.

=cut
has q{folder_name}    => (
  isa               => q{Str},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_folder_name {
  my $self = shift;
  return basename $self->runfolder_path;
}

=head2 date_created

The date when the run was created. Parsed out from the folder_name attribute.

=cut
has q{date_created} => (
  isa               => q{DateTime},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_date_created {
  my $self = shift;

  my ($date_string) = $self->folder_name =~ m/\d+-(\d+_\d+)\Z/ms;
  my $date;
  if ($date_string) {
    try {
      $date = DateTime::Format::Strptime->new(
        pattern=>'%Y%m%d_%H%M',
        strict=>1,
        on_error=>q[croak]
      )->parse_datetime($date_string);
    } catch {
      croak "date_created: failed to parse $date_string";
    };
  } else {
    croak 'Cannot extract run date from run folder name ' . $self->folder_name;
  }
  
  return $date;
}

has q{_library_info_root} => (
  isa               => q{XML::LibXML::Element},
  is                => q{ro},
  required          => 0,
  init_arg          => undef,
  lazy_build        => 1,
);
sub _build__library_info_root {
  my $self = shift;
  my @library_info = grep { /\d+_LibraryInfo/ } 
    ( glob catfile($self->runfolder_path, '*.xml') );
  if ( @library_info != 1 ) {
    croak '*_LibraryInfo.xml file is not found in run folder '
      . $self->runfolder_name . ' or multiple files found';
  }
  return XML::LibXML->load_xml(location => $library_info[0])->documentElement();
}

sub _get_ultimagen_run_attr {
  my ($self, $attr_name) = @_;
  
  $attr_name or croak 'Attribute name should be supplied';
  my $value = $self->_library_info_root()->getAttribute($attr_name);
  $value or croak "Empty value in $attr_name";

  return $value;
}

sub _set_tags {
  my ($self) = shift;
  my @tags = (
    'staging',
    'multiplex'
  );

  foreach my $tag ( @tags ) {
    $self->tracking_run()->set_tag($USERNAME, $tag);
    $self->info("$tag tag is set");
  }
}

=head2 process_run

Inspects the run folder. Creates a new  run record if does not exist.

The following run statuses are assigned:
- 'run in progress'   assigned when the run is created
- 'run mirrored'      assigned all run data is copied from the instrument
                      to the staging run folder

=cut
sub process_run {
  my $self = shift;
  my $run_row = $self->tracking_run();
  my $current_run_status_obj = $run_row->current_run_status;
  my $run_uploaded_path = catfile($self->runfolder_path, $RUN_UPLOADED_FILE);
  
  my $current_status_description = $current_run_status_obj->description;
  $self->info("Current run status is '$current_status_description'");
  my $current_run_status_dict = $current_run_status_obj->run_status_dict;
  
  if ( $current_run_status_dict->compare_to_status_description($RUN_STATUS_MIRRORED) == -1 ) {			
    if ( -e $run_uploaded_path ) {
      my $date = DateTime->from_epoch(epoch => (stat  $run_uploaded_path)[9]);
      $run_row->update_run_status($RUN_STATUS_MIRRORED, $USERNAME, $date);
      $self->info("Assigned '$RUN_STATUS_MIRRORED' status. "
        . 'Run ' . $self->runfolder_path . ' is now completed');
    }
  }
}

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item Readonly

=item File::Basename

=item File::Spec::Functions

=item DateTime

=item DateTime::Format::Strptime

=item npg_tracking::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Marco M. Mosca

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 Genome Research Ltd.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
