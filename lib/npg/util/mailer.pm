#############
# Created By: ajb
# Created On: 2009-06-15

package npg::util::mailer;
use strict;
use warnings;
use Carp;
use English qw{-no_match_vars};

use Class::Std;
use MIME::Lite;

our $VERSION = '0';

{
  ## no critic (ProhibitUnusedVariables)
  my %to_of       :ATTR( init_arg => q{to},       :get<to>,       :set<to>      );
  my %from_of     :ATTR( init_arg => q{from},     :get<from>,     :set<from>    );
  my %body_of     :ATTR( init_arg => q{body},     :get<body>,     :set<body>    );
  my %subject_of  :ATTR( init_arg => q{subject},  :get<subject>,  :set<subject> );
  ## use critic
  my %precendence_of  :ATTR( :get<precendence>, :set<precedence>  );
  my %type_of         :ATTR( :get<type>,        :set<type>        );
  my %cc_of           :ATTR( :get<cc>,          :set<cc>          );
  my %bcc_of          :ATTR( :get<bcc>,         :set<bcc>         );

  sub BUILD {
    my ($self, $ident, $arg_ref) = @_;
    $precendence_of{$ident} = $arg_ref->{precedence} || q{list};
    $type_of{$ident} = $arg_ref->{type} || q{text/plain};

    my $cc = $arg_ref->{cc} || q{};
    $cc =~ s/[ ]/,/xms;
    my @cc_temp = split /,/xms, $cc;
    $cc_of{$ident} = \@cc_temp;

    my $bcc = $arg_ref->{bcc} || q{};
    $bcc =~ s/[ ]/,/xms;
    my @bcc_temp = split /,/xms, $bcc;
    $bcc_of{$ident} = \@bcc_temp;

    return;
  }

  sub mail {
    my ($self) = @_;

    if (ref$self->get_to() ne 'ARRAY') {
      my $to = $self->get_to();
      $to =~ s/[ ]/,/xms;
      my @temp = split /,/xms, $to;
      $self->set_to(\@temp);
    }

    my $msg = MIME::Lite->new(
        To            => (join q(, ), @{$self->get_to()}),
        From          => $self->get_from(),
        Cc            => (join q(, ), @{$self->get_cc}),
        Bcc           => (join q(, ), @{$self->get_bcc}),
        Subject       => $self->get_subject(),
        Type          => $self->get_type(),
        Data          => $self->get_body(),
        'Precedence:' => $self->get_precendence(),
      );

    eval {
      $msg->send();
      1;
    } or do {
      croak "Error sending email : $EVAL_ERROR";
    };

    return 1;
  }
}

1;
__END__

=head1 NAME

  npg::util::mailer

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head2 mail

=head2 BUILD

=over

=item strict

=item warnings

=item Carp

=item English -no_match_vars

=item Class::Std

=item base

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 GRL by Andy Brown (ajb@sanger.ac.uk)

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
