#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use Carp qw(croak);

main();
exit 0;

sub main {
        my $q = CGI->new;

        my $current_url = $ENV{'HTTP_REFERER'};
        my $username    = $ENV{'OIDC_CLAIM_preferred_username'} // 'not-defined';

        if ($username eq 'not-defined') {
                perform_user_login($q, $current_url);
        } else {
                perform_user_logout($q, $current_url);
        }
        return;
}

sub create_cookie {
        my ($q, $name, $value) = @_;
        return $q->cookie(
                -name    => $name,
                -value   => $value,
                -path    => q{/},
                -secure  => 0,
                -expires => '+1h',
        );
}

sub clear_cookie {
        my ($q, $name) = @_;

        return $q->cookie(
                -name    => $name,
                -value   => q{},
                -path    => q{/},
                -secure  => 0,
                -expires => '-1d',
        );
}

sub perform_user_login {
        my ($q, $url) = @_;

        print $q->redirect(
                -uri    => '/perl/oidc-post-login-actions.cgi',
                -cookie => create_cookie($q, 'previous_url', $url),
        ) or croak 'Failed to send redirect header.';
        return;
}

sub perform_user_logout {
        my ($q, $url) = @_;

        my $logout_redirect_uri = 'https://' . $ENV{HTTP_HOST}
                                  . '/perl/oidc-post-logout-redirect.cgi';
        print $q->redirect(
                -uri    => '/callback?logout=' . $logout_redirect_uri,
                -cookie => create_cookie($q, 'previous_url', $url)
        ) or croak 'Failed to send redirect header.';
        return;
}
