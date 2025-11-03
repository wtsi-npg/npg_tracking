package npg_tracking::status;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;
use MooseX::Storage;
use File::Spec;
use File::Slurp;
use Carp;

use WTSI::DNAP::Utilities::Timestamp qw/create_current_timestamp
                                        parse_timestamp/;
use npg_tracking::util::types;

with Storage( 'traits' => ['OnlyWhenBuilt'],
              'format' => 'JSON',
              'io'     => 'File' );

with qw/ npg_tracking::glossary::run/;

our $VERSION = '0';

has q{lanes} => (
                   isa      => q{ArrayRef[NpgTrackingLaneNumber]},
                   is       => 'ro',
                   required => 0,
                   default  => sub {return []; },
                   documentation => q{an optional array of lane numbers},
);

has q{status} => (
                   isa      => q{Str},
                   is       => 'ro',
                   required => 1,
                   documentation => q{status for run or lane, may contain white spaces},
);

has q{username} => (
                   isa      => q{Str|Undef},
                   is       => 'ro',
                   required => 0,
                   documentation => q{username for the database record},
);

has q{timestamp} => (
                   isa       => q{Str},
                   is        => 'ro',
                   required  => 0,
                   predicate => 'has_timestamp',
                   default   => sub { create_current_timestamp() },
                   documentation => q{timestamp of the status change},
);

sub filename {
  my $self = shift;

  my $filename = $self->status();
  $filename =~ s{\s+}{-}gxms;
  for my $lane ( sort @{$self->lanes()} ) {
    $filename .= qq{_$lane};
  }
  $filename .= q{.json};

  return $filename;
}

sub to_string {
  my $self = shift;
  return sprintf
    'Object %s status:"%s", username:"%s", id_run:"%i", lanes:"%s", date:"%s"',
              __PACKAGE__,
              $self->status,
              $self->username ? $self->username : q[none],
              $self->id_run,
              @{$self->lanes} ? join(q[ ], @{$self->lanes}) : q[none],
              $self->has_timestamp ? $self->timestamp : q[none];
}

sub from_file {
  my ($package_name, $path) = @_;
  return $package_name->thaw(read_file($path));
}

sub to_file {
  my ($self, $dir) = @_;
  my $filename = $dir ? File::Spec->catfile($dir, $self->filename) : $self->filename;
  write_file($filename, $self->freeze());
  return $filename;
}

sub to_database {
  my ($self, $schema, $logger) = @_;

  $schema or croak 'Tracking database DBIx schema object is required';

  my $run_row = $schema->resultset('Run')->find($self->id_run);
  if (!$run_row) {
    croak sprintf 'Run id %i does not exist', $self->id_run;
  }

  my $date = parse_timestamp($self->timestamp);

  if ( !@{$self->lanes} ) {
    my $saved = $run_row->update_run_status($self->status, $self->username, $date);
    $logger and $logger->info(sprintf
      'Run status %ssaved to the database', $saved ? q[] : q[not ]);
  } else {
    my %run_lanes = map { $_->position => $_} $run_row->run_lanes->all();
    foreach my $pos (@{$self->lanes}) {
      if (!exists $run_lanes{$pos}) {
        croak sprintf 'Lane %i does not exist in run %i', $pos, $self->id_run;
      }
    }
    foreach my $pos (sort { $a <=> $b} @{$self->lanes}) {
      my $saved = $run_lanes{$pos}->update_status(
        $self->status, $self->username, $date);
      $logger and $logger->info(sprintf
        'Lane %i status %ssaved to the database', $pos, $saved ? q[] : q[not ]);
    }
  }

  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_tracking::status

=head1 SYNOPSIS

=head1 DESCRIPTION

 Serializable to the JSON format object for run and lane statuses.

 my $s = npg_tracking::Status->new(
  id_run => 1, status => 'some status', dir_out => 'mydir');
 $s->freeze();

 $s = npg_tracking::Status->new(
  id_run => 1, lanes => [1, 3], status => 'some status', dir_out => 'mydir');
 $s->freeze();

=head1 SUBROUTINES/METHODS

=head2 id_run

 Integer run identifier, an attribute, required.

=head2 lanes

 Array of lane numbers, an optional attribute.

=head2 status

 String representing the status to save, an attribute, required.

=head2 username

 Username for saving the status to the database. Can be explicitly set to an
 undefined value.

=head2 filename

 Suggested filename for serializing this object.

=head2 timestamp

 String timestamp representation, an optional attribute, will
 be built when object is serialized to a JSON string.

=head2 to_string

 String representation of the object that does not trigger
 Moose lazy builders.

=head2 from_file

 Reads a file, given as an attribute, into a string and tries to
 instantiate an npg_tracking::status object from this string.

 my $obj = npg_tracking::status->from_file($path);

=head2 to_file

 Writes to a file serialized to the JSON format object. The file is
 created in a directory given as an attribute or, if not passed, in
 the current directory. Filename generated by the filename() method
 of the object is used. Returns the path of the file created.
 
 my $path = $status_obj->to_file('mydir');
 my $path = $status_obj->to_file();

=head2 to_database

 Creates a run or lane status record in the tracking database for this object.
 The first argument is a DBIx schema object for the database. The second
 optional argument is a logger object. If set, will be used to log non-error
 messages.
 
 $status_obj->to_database($schema);
 $status_obj->to_database($schema, $logger);

 The original version of the code for this function was written for the status
 monitor daemon, see C<npg_tracking::monitor::status::_update_status>.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item MooseX::StrictConstructor

=item MooseX::Storage

=item File::Spec

=item File::Slurp

=item Readonly

=item Carp

=item WTSI::DNAP::Utilities::Timestamp

=item npg_tracking::glossary::run

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Limitation: does not validate the status against the database
status dictionaries.

=head1 AUTHOR

=over

=item Kate Taylor

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014,2016,2019,2021,2025 Genome Research Ltd.

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
