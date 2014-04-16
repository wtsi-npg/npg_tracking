#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::view::error;
use strict;
use warnings;
use base qw(ClearPress::view::error);
use English qw(-no_match_vars);
use Template;
use Carp;
use MIME::Lite;
use npg::model::usergroup;
use DateTime;

our $VERSION = '0';

__PACKAGE__->mk_accessors('access');

sub render {
  my $self   = shift;
  my $errstr = q{Error: } . ( $self->errstr() || q{-} );
  my $aspect = $self->aspect();

  print {*STDERR}   qq[Serving error:\nerrstr:     ]
                  . @{[ $self->errstr() || q[undef] ]}
                  . qq[\nEVAL_ERROR: ]
                  . @{[ $EVAL_ERROR || q[undef] ]}
                  . qq[\nTemplate:   ]
                  . @{[ Template->error() || q[undef] ]}
                  . qq[\n]
    or croak 'unable to print error';

  if ($aspect eq 'add') {
    $errstr .= q(<br /><br />You do not have sufficient permissions to )
            .  q(perform this action. You may have forgotten to log in.)
            .  q(<br />Click <a href="https://enigma.sanger.ac.uk/sso/login">)
            .  q(here</a> to login or use the key icon.<br /><br />);
  }

  if(Template->error()) {
    $errstr .= q(Template Error: ) . Template->error();
  }

  if($EVAL_ERROR) {
    $errstr .= q(Eval Error: ) . $EVAL_ERROR;
  }
  $errstr    =~ s{\S+(npg.*?)$}{$1}smgx;
  if ($aspect ne 'add') {
   my $users = npg::model::usergroup->new({
      util => $self->util(),
      groupname => 'errors',
   })->users();

   if(@{$users}){

    my $to = [];
    foreach my $user (@{$users}) {
      my ( $username ) = $user->username() =~ /([a-z0-9_]+)/ixms;
      next if ! $username;
      next if $username ne $user->username();
      push @{$to}, $username . q{@} . q{sanger.ac.uk};
    }

    my $to_string = scalar @{ $to } ? join q{,}, @{$to} : q{};
    my $dev = $ENV{dev} || q(live);

    my $email_body = q{[} . DateTime->now() . q{]}
                   . $errstr
                   . qq{\n\nCheck the error logs to find out the problem.}
                   . qq{\n\nThe following user was logged in: }
                   . $self->util->requestor->username() . qq{\n\n};

    $email_body .= qq{**** CGI Params ****\n};

    my $cgi = $self->util->cgi();

    foreach my $param ( sort keys %{ $cgi->{param} } ) {
      $email_body .= qq{\t$param: } . $cgi->param($param) . qq{\n};
    }

    $email_body .= qq{**** Environment Variables ****\n};
    foreach my $env_var ( sort keys %ENV ) {
        $email_body .= "\t$env_var: " . ( $ENV{$env_var} || q{} ) . "\n";
    }


    my $msg = MIME::Lite->new(
          To      => $to_string,
          From    => q[srpipe@].q[sanger.ac.uk],
          Subject => (sprintf q(%s NPG Error), $dev),
          Type    => 'text/plain',
          Data    => $email_body,
         );
    eval {
      if ( $to_string ) {
        $msg->send();
      }
      1;
    } or do {
      carp "Error sending errstr mail: $EVAL_ERROR";
    };
    return   q(<h2>An Error Occurred</h2>)
           . $self->actions()
           . q(<div class="error_box">)
           . q(<h3>We have been alerted to this problem</h3><p>)
           . $errstr
           . q(</p></div>);
   }else{
    return   q(<h2>An Error Occurred</h2>)
           . $self->actions()
           . q(<div class="error_box">)
           . q(<h3>Should it reoccur please report the matter to <a href="mailto:seq-help@).q(sanger.ac.uk">seq-help@).q(sanger.ac.uk</a></h3><p>)
           . $errstr
           . q(</p></div>);
   }
  }

  return   q(<h2>An Error Occurred</h2>)
         . $self->actions()
         . q(<div class="error_box"><h3>Authentication Error</h3><p>)
         . $errstr
         . q(</p><p>If you feel that this is incorrect (i.e. you are already )
         . q(logged in), then please email <a href="mailto:seq-help">seq-help)
         . q(</a><br />requesting a change of group status for the function )
         . q(you are trying to perform.</p></div>);
}

1;

__END__

=head1 NAME

npg::view::error - subclass of npg::view for error-viewing purposes

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 access - Get/set accessor for an error string or aspect ($info) to display

  $oErrorView->access($info, $sErrorMessage);
  my $sErrorMessage = $oErrorView->access($info);

=head2 render - encapsulated HTML rather than a template, in case the template has caused the error

  my $sErrorOutput = $oErrorView->render();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item ClearPress::view::error

=item English

=item Template

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett

This file is part of NPG.

NPG is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/ .

=cut
