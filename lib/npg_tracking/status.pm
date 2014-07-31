#############
# Created By: kt6
# Created On: 2014-05-28
#

package npg_tracking::status;

use Moose;
use MooseX::StrictConstructor;
use MooseX::Storage;
use DateTime;
use JSON::Any;

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
                   isa      => q{Str},
                   is       => 'ro',
                   required => 0,
                   default  => sub { DateTime->now()->strftime(timestamp_format()) },
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

sub timestamp_format {
  return '%Y/%m/%d %H:%M:%S';
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_tracking::status

=head1 AUTHOR

Kate Taylor

=head1 SYNOPSIS

=head1 DESCRIPTION

 Serializable to json object for run and lane statuses

 my $s = npg_pipeline::Status->new(id_run => 1, status => 'some status', dir_out => 'mydir');
 $s->freeze();

 $s = npg_pipeline::Status->new(id_run => 1, lanes => [1, 3], status => 'some status', dir_out => 'mydir');
 $s->freeze();

=head1 SUBROUTINES/METHODS

=head2 id_run - run identifier

=head2 lanes - an optional array of lane numbers

=head2 status - status to save

=head2 filename - suggested filename for serializing this object

=head2 timestamp - timestamp

=head2 timestamp_format - format string for timestamp

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item MooseX::Storage

=item POSIX

=item npg_tracking::glossary::run

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Does not validate the status against the status dictionaries

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Limited

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
