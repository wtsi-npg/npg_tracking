#############
# Created By: ajb
# Created On: 2010-02-10

package npg::email;
use strict;
use warnings;
use Moose;
use Carp;
use English qw{-no_match_vars};
use Template;
use Readonly;
use npg::util::mailer;
use npg_tracking::Schema;

our $VERSION = '0';

Readonly::Scalar our $DEFAULT_RECIPIENT_HOST    => q{@}.q{sanger.ac.uk};
Readonly::Scalar our $DEFAULT_FROM              => q{srpipe}.$DEFAULT_RECIPIENT_HOST;
Readonly::Scalar our $DEFAULT_TEMPLATE_LOCATION => q{data/npg_tracking_email/templates};

=head1 NAME

npg::email

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 send_email

generic email send method

  eval {
    $oDerivedClass->send_email({
      to => $sTo, (May be an ArrayRef)
      from => $sFrom (Default will be provided),
      subject => $sSubject,
      body => $sBody,
      cc => $sCC, (May be an ArrayRef)
    })
  } or do {
    ... your error handling here ...
  };

=cut

sub send_email {
  my ($self, $arg_refs) = @_;

  eval {
    npg::util::mailer->new({
      to => $arg_refs->{to},
      from => $arg_refs->{from} || $DEFAULT_FROM,
      subject => $arg_refs->{subject},
      body => $arg_refs->{body},
      cc => $arg_refs->{cc},
    })->mail();
    1;
  } or do {
    my $error = $EVAL_ERROR;
    my @people = @{$arg_refs->{to}};
    push @people, @{$arg_refs->{cc}};
    my $people_as_string = join q[, ], @people;
    $people_as_string ||= q[UNKNOWN];
    croak qq{Failed to send '$arg_refs->{subject}' to $people_as_string \n\t$error};
  };

  return 1;
}

=head2 email_templates_location

The location of the email_templates for npg tracking emails

=cut

has q{email_templates_location} => ( isa => q{Str},
                                     is => q{ro},
                                     default => $DEFAULT_TEMPLATE_LOCATION,
                                     documentation => qq{location of email templates - Default $DEFAULT_TEMPLATE_LOCATION},
                                   );

=head2 email_templates_object

returns a Template object which knows where the email templates are located (from email_templates_location)

=cut

has q{email_templates_object} => (isa => q{Template}, is => q{ro}, lazy_build => 1, init_arg => undef);

sub _build_email_templates_object {
  my ($self) = @_;
  return Template->new({
        INCLUDE_PATH => [ $self->email_templates_location(), ],
        INTERPOLATE  => 1,
        OUTPUT => $self->email_body_store(),
    }) || die "$Template::ERROR\n";
}

=head2 next_email

returns the next generated email, removing it from the current emails list

=head2 all_emails

returns all current emails in the object

=cut

has q{email_body_store} => (
  traits => ['Array'],
  isa => q{ArrayRef[Str]},
  is => q{ro},
  init_arg => undef,
  lazy => 1,
  default => sub { return []; },
  handles => {
    all_emails => q{elements},
    next_email => q{shift},
  },
);

=head2 default_recipient_host

returns the default @x.y to be appended to any email recipients which do not already have this specified

=cut

has q{default_recipient_host} => (isa => q{Str},
                                  is => q{ro},
                                  default => $DEFAULT_RECIPIENT_HOST,
                                  documentation => q{the default @}.q{x.y to be appended to any email recipients which do not already have this specified - Default: } . $DEFAULT_RECIPIENT_HOST, );

=head2 schema_connection

Returns a valid schema connection for the npg_tracking database

  my $oConnection = $class->schema_connection();

This can be set on construction of the object.

=cut

has 'schema_connection' => ( isa => q{npg_tracking::Schema},
                             is => q{ro},
                             lazy_build => 1,
                           );
sub _build_schema_connection {
  my $self = shift;
  return npg_tracking::Schema->connect();
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English -no_match_vars

=item Readonly

=item Template

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown (ajb@sanger.ac.uk)

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
