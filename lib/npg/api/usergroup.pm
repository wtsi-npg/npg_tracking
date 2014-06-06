#########
# Author:        rmp
# Created:       2007-11-09
#
package npg::api::usergroup;
use strict;
use warnings;
use base qw(npg::api::base);
use Carp;
use npg::api::user;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_usergroup groupname is_public description);
}

sub users {
  my $self  = shift;
  my $users = $self->read->getElementsByTagName('users')->[0];

  return [map {
    $self->new_from_xml('npg::api::user', $_);
  } $users->getElementsByTagName('user')];
}

1;

__END__

=head1 NAME

npg::api::usergroup

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for

 my @aFields = npg::api::user->fields();
 my @aFields = $oUser->fields();

=head2 id_usergroup - ID for this group

=head2 groupname - name of this group

=head2 is_public - subscribable status of this group

=head2 description - short description of this group

=head2 users - arrayref of npg::api::users belonging to this group

 my $arUsers = $oUserGroup->users();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::api::base

=item Carp

=item npg::api::usergroup

=back

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
