package npg_tracking::Schema::Time;

use strict;
use warnings;
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

1;
