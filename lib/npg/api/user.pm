#########
# Author:        rmp
# Created:       2007-11-09
#
package npg::api::user;
use strict;
use warnings;
use base qw(npg::api::base);
use Carp;
use npg::api::usergroup;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_user username);
}

sub usergroups {
  my $self       = shift;
  my $usergroups = $self->read->getElementsByTagName('usergroups')->[0];

  return [map {
    $self->new_from_xml('npg::api::usergroup', $_);
  } $usergroups->getElementsByTagName('usergroup')];
}

1;

__END__

=head1 NAME

npg::api::user

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for

 my @aFields = npg::api::user->fields();
 my @aFields = $oUser->fields();

=head2 id_user - ID for this user

 my $iIdUser = $oUser->id_user();

=head2 username - user name for this user

 my $sUserName = $oUser->username();

=head2 usergroups - arrayref of npg::api::usergroups of which this user is a member

 my $arUserGroups = $oUser->usergroups();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
base
npg::api::base
Carp
npg::api::usergroup

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
