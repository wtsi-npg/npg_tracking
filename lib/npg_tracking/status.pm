package npg_tracking::status;

use Moose;
use MooseX::StrictConstructor;
use MooseX::Storage;
use DateTime;
use DateTime::Format::Strptime;
use DateTime::TimeZone;
use File::Spec;
use File::Slurp;
use Carp;

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

has q{timestamp} => (
                   isa       => q{Str},
                   is        => 'ro',
                   required  => 0,
                   predicate => 'has_timestamp',
                   default   => sub { DateTime->now(
                         time_zone => DateTime::TimeZone->new(name => q[local])
                                                   )->strftime(_timestamp_format()) },
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

sub _timestamp_format {
  return '%d/%m/%Y %H:%M:%S';
}

sub timestamp_obj {
  my $self = shift;
  return DateTime::Format::Strptime->new(
    pattern  => _timestamp_format(),
    on_error => 'croak',
  )->parse_datetime($self->timestamp);
}

sub to_string {
  my $self = shift;
  ##no critic (CodeLayout::ProhibitParensWithBuiltins)
  return sprintf('Object %s status:"%s", id_run:"%i", lanes:"%s", date:"%s"',
              __PACKAGE__,
              $self->status,
              $self->id_run,
              @{$self->lanes} ? join(q[ ], @{$self->lanes}) : q[none],
              $self->has_timestamp ? $self->timestamp : q[none]
         );
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

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_tracking::status

=head1 SYNOPSIS

=head1 DESCRIPTION

 Serializable to json object for run and lane statuses

 my $s = npg_tracking::Status->new(id_run => 1, status => 'some status', dir_out => 'mydir');
 $s->freeze();

 $s = npg_tracking::Status->new(id_run => 1, lanes => [1, 3], status => 'some status', dir_out => 'mydir');
 $s->freeze();

=head1 SUBROUTINES/METHODS

=head2 id_run

 Run identifier, required attribute.

=head2 lanes

 An optional array of lane numbers attribute.

=head2 status

 String representing the status to save, a required attribute.

=head2 filename

 Suggested filename for serializing this object.

=head2 timestamp

 String timestamp representation, an optional attribute.

=head2 timestamp_obj

 DateTime object timestamp representation

=head2 to_string

 String representation of the object that does not trigger
 Moose lazy builders.

=head2 from_file

 Reads a file, given as an attribute, into a string and tries to instantiate
 an npg_tracking::status object from this string.

 my $obj = npg_tracking::status->from_file($path);

=head2 to_file

 Writes serialized object ($self) to a file. The file is created in a directory
 given as an attribute or, if not passed, in the current directory. Filename returned
 by the filename() method of the object is used. Returns the path of the file created.
 
 my $path = $status_obj->to_file('mydir');
 my $path = $status_obj->to_file();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item MooseX::Storage

=item DateTime

=item DateTime::TimeZone

=item DateTime::Format::Strptime

=item File::Spec

=item File::Slurp

=item Carp

=item npg_tracking::glossary::run

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Limitation: does not validate the status against the status dictionaries.

=head1 AUTHOR

Kate Taylor E<lt>kt6@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Limited

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
