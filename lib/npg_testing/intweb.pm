#########
# Author:        mg8
#

package npg_testing::intweb;

use strict;
use warnings;
use Carp;
use English qw{-no_match_vars};
use Exporter;
use LWP::UserAgent;
use HTTP::Request::Common;
use npg::api::util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 8316 $ =~ /(\d+)/mxs; $r; };

=head1 NAME

npg_testing::intweb

=head1 VERSION

$Revision: 7844 $

=head1 SYNOPSIS

=head1 DESCRIPTION

A collection of functions to test the availability of internal Sanger sites

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar our $LWP_TIMEOUT       => 60;
Readonly::Scalar our $MAX_NUM_ATTEMPTS  => 2;

## no critic (ProhibitExplicitISA)
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(npg_is_accessible);

sub _attempt_request {
    my ($request, $ua) = @_;

    my $response;
    eval {
        $response = $ua->request($request);
        1;
    } or do {
        carp $EVAL_ERROR;
        return 0;
    };
    if ($response->is_success) {
        return 1;
    } else {
        carp $response->status_line();
    }
    return 0;
}

=head2 npg_is_accessible

Tests whether it is possible to access NPG home page

=cut
sub npg_is_accessible {
    my $url = shift;

    $url ||= $npg::api::util::LIVE_BASE_URI;
    my $request =  GET $url;
    my $ua = LWP::UserAgent->new();
    $ua->agent("npg_testing::intweb $VERSION");
    $ua->timeout($LWP_TIMEOUT);
    $ua->env_proxy();

    my $count = 0;
    my $result = 0;
    while ($count < $MAX_NUM_ATTEMPTS && !$result) {
        $result = _attempt_request($request, $ua);
        $count++;
    }
    return $result;
}

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item warnings

=item strict

=item Carp

=item English

=item Exporter

=item LWP::UserAgent

=item HTTP::Request::Common

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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

