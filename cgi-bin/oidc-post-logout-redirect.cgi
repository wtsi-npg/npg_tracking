#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use Carp qw(croak);

main();
exit 0;

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

sub main() {
        my $q = CGI->new;

        my $previous_url = $q->cookie('previous_url')
                            || 'https://' . $ENV{HTTP_HOST} . '/perl/npg';

        my %cookies;
        foreach my $pair (split /;\s*/xsm, $ENV{HTTP_COOKIE}) {
             my ($name, $value) = split /=/xsm, $pair, 2;
             if (defined $name) {
               $cookies{$name} = $value;
             }
        }

        my @expired;

        push @expired, $q->cookie(
            -name    => 'previous_url',
            -value   => q{},
            -expires => '-1d',
            -path    => q{/},
            -secure  => 0,
        );

        foreach my $name (keys %cookies) {
           if ($name =~ /^npg_oidc_session_/xsm) {
              push @expired, $q->cookie(
                 -name     => $name,
                 -value    => q{},
                 -expires  => '-1d',
                 -path     => q{/},
                 -secure   => 1,
                 -httponly => 1,
                 -domain   => '.sanger.ac.uk',
              );
           }
        }

        print $q->header(-type   => 'text/html',
                         -cookie => clear_cookie($q, 'previous_url'),
        ) or croak 'Failed to send redirect header.';

        print $q->redirect(-uri => $previous_url,
                           -cookie => \@expired,
                          ) or croak 'Failed to send redirect header.';
        return;
}
