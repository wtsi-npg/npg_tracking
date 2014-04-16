#########
# Author:        rmp
# Created:       2008-02-22
#
package st::api::event;
use base qw(st::api::base);
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;
use HTTP::Request;
require XML::Generator; # use() pollutes with AUTOLOAD

__PACKAGE__->mk_accessors(fields());

our $VERSION = '0';

sub live {
    my $self = shift;
    return $self->live_url()  . q{/events};
}

sub dev {
    my $self = shift;
    return $self->dev_url()   . q{/events};
}

sub fields {
    return qw( message
               eventful_type
               eventful_id
               family
               identifier
               location
               key );
}

sub create {
  my ($self) = @_;
  my $ua     = $self->util->useragent();
  my $xg     = XML::Generator->new();
  my $ent    = $self->entity_name();
  my $xml    = q(<?xml version='1.0'?>).
  $xg->$ent(map  { $xg->$_($self->$_()) }
  grep { defined $self->$_() }
  $self->fields());

  push @{ $ua->requests_redirectable }, 'POST';

  my $response = $ua->post(
         $self->service(),
         'Content_Type'   => 'application/xml',
         'Content_Length' => length $xml,
         'Content'        => $xml,
         'Accept'         => 'text/xml',
        );
  if (!$response->is_success()) {
    croak q{Unable to update Sample Tracking: } . $response->status_line();
  }
  return 1;
}

1;
__END__

=head1 NAME

st::api::event - an interface to Sample Tracking events

=head1 VERSION

=head1 SYNOPSIS

 use strict;
 use warnings;
 use st::api::event;

 my $event = st::api::event->new({
   message       => 'a message',
   eventful_id   => 123,
   eventful_type => 'type',
   family        => 'update',
 });

 $event->create();

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - fields in this package

  These all have default get/set accessors.

  my @aFields = $oEvent->fields();
  my @aFields = st::api::event->fields();

=head2 dev - development service URL

  my $sDevURL = $oEvents->dev();

=head2 live - live service URL

  my $sLiveURL = $oEvents->live();

=head2 create - post event data to sample tracking

  $oEvent->create();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head2 strict

=head2 warnings

=head2 base

=head2 Carp

=head2 English

=head2 XML::Generator

=head2 HTTP::Request

=head2 st::api::base

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

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
