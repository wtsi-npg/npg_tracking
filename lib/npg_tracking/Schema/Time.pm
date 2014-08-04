package npg_tracking::Schema::Time;

use DateTime;
use DateTime::TimeZone;
use Moose::Role;

our $VERSION = '0';

sub get_time_now {
  return DateTime->now(time_zone=> DateTime::TimeZone->new(name => q[local]));
}

sub get_difference_seconds {
  my ($self, $this, $that) = @_;
  return $this->subtract_datetime_absolute( $that )->delta_seconds;
}

no Moose::Role;
1;
__END__

=head1 NAME

npg_tracking::Schema::Time

=head1 SYNOPSIS

=head1 DESCRIPTION

 A Moose role containing helper functions for dealing with dates.

=head1 SUBROUTINES/METHODS

=head2 get_time_now

 Returns a DateTime object for current time. Time is local.

 my $new = $row->get_time_now();

=head2 get_difference_seconds

 Takes two TimeDate objects as arguments, returns difference in seconds
 between time represented by teh first and the second object.

 my $delta_seconds = $row->get_difference_seconds($this, $that);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item DateTime

=item DateTime::TimeZone

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Limited

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
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
