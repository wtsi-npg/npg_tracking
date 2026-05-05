#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use Carp qw(croak);

main();
exit 0;

sub main {
        my $q = CGI->new;

        my $default_uri = 'https://' . $ENV{HTTP_HOST} . '/perl/npg';
        my $previous_url = $q->cookie('previous_url')
                           || $default_uri . $q->param('return_to')
                           || $default_uri;

        perform_post_oidc_login_actions($q, $previous_url);

        return;
}

sub clear_cookie {
        my ($q, $name) = @_;

        return $q->cookie(
                -name    => $name,
                -value   => q{},
                -expires => '-1d',
                -path    => q{/},
                -secure  => 0,
        );
}

sub perform_post_oidc_login_actions {
        my ($q, $previous_url) = @_;

        if (!$ENV{'REMOTE_USER'}) {
                print $q->header(-status => '401 Unauthorized')
                        or croak 'Authentication required';
                exit;
        }

        print $q->redirect(
                -uri    => $previous_url,
                -cookie => [clear_cookie($q, 'previous_url')]
        ) or croak 'Failed to send redirect header.';
        return;
}
