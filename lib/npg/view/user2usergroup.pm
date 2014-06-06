#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::view::user2usergroup;
use strict;
use warnings;
use base qw(npg::view);
use English qw(-no_match_vars);
use Carp;
use npg::model::usergroup;

our $VERSION = '0';

sub authorised {
  my ($self, @args) = @_;
  my $model         = $self->model();
  my $requestor     = $self->util->requestor();
  my $action        = $self->action();
  my $aspect        = $self->aspect();
  my $req_id_user   = $requestor->id_user();
  my $mod_id_user   = $model->id_user();

  if($action eq 'create' && $req_id_user) {
    my $public = npg::model::user->new({
                  util     => $self->util(),
                  username => 'public',
               });
    if(defined $req_id_user &&
       $req_id_user != $public->id_user()) {
      #########
      # You can only create memberships if you're not public
      #
      return 1;
    }
  }

  if($req_id_user && $mod_id_user &&
     $req_id_user == $mod_id_user) {
    #########
    # You can only update or delete memberships if they're yours
    #
    if($action =~ /^update|delete$/smx) {
      return 1;
    }
  }

  return $self->SUPER::authorised(@args);
}

sub create {
  my ($self, @args)   = @_;
  my $util            = $self->util();
  my $cgi             = $util->cgi();
  my $model           = $self->model();
  $model->{'id_user'} = $util->requestor->id_user(); # enforce id_user for logged in user

  my $id_usergroup = $cgi->param('id_usergroup');

  if(!$id_usergroup) {
    croak q(No group specified);
  }

  my $usergroup = npg::model::usergroup->new({
                util         => $util,
                id_usergroup => $id_usergroup,
               });
  if(!$usergroup->is_public()) {
    croak $usergroup->groupname() . q( is not open for subscription);
  }
  return $self->SUPER::create(@args);
}

sub delete { ## no critic (ProhibitBuiltinHomonyms)
  my ($self, @args) = @_;
  my $model = $self->model();
  #########
  # cache usergroup so we can display what's been unsubscribed-from
  #
  $model->usergroup();
  return $self->SUPER::delete(@args);
}

1;

__END__

=head1 NAME

npg::view::user2usergroup

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised - check the requestor is accessing their own page (on 'create')

 my $bAuthorised = $oView->authorised();

=head2 create - checks that the subscription request is for a public group

=head2 delete - small amount of pre-deletion caching for display purposes

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::view

=item English

=item Carp

=item npg::model::usergroup

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
