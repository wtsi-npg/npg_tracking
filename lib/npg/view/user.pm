#########
# Author:        rmp
# Created:       2007-11-09
#
package npg::view::user;
use strict;
use warnings;
use base qw(npg::view);
use npg::model::usergroup;
use Carp;
use Digest::SHA qw(sha256_hex);;

our $VERSION = '0';

sub new {
  my ($class, @args) = @_;
  my $self  = $class->SUPER::new(@args);
  my $model = $self->model();
  my $id    = $model->id_user();

  if($id && $id !~ /^\d+$/smx) {
    $model->username($id);
    $model->id_user(0);
    $model->init();
  }

  return $self;
}

sub authorised {
  my $self   = shift;
  my $util   = $self->util();
  my $action = $self->action();
  my $aspect = $self->aspect() || q[];

  #########
  # Allow a user to update his or her rfid_tag
  #
  if( $action eq 'update' &&
      $util->cgi->param( q{rfid_tag} ) ) {
    return 1;
  }

  return $self->SUPER::authorised();
}

sub read { ## no critic (ProhibitBuiltinHomonyms)
  my ($self, @args) = @_;
  my $model = $self->model();
  my $util  = $self->util();

  my $all_public = npg::model::usergroup->new({
                 util => $util,
                })->public_usergroups();
  my $member_of = $model->usergroups();
  my @not_in = ();
  for my $group (@{$all_public}) {
    if(!scalar grep { my $id_ug = $_->id_usergroup(); $id_ug && $id_ug == $group->id_usergroup() } @{$member_of}) {
      push @not_in, $group;
    }
  }
  if(scalar @not_in) {
    $model->{'public_usergroups'} = \@not_in;
  }

  return $self->SUPER::read(@args);
}

sub update {
  my ( $self ) = @_;
  my $cgi = $self->util->cgi();

  my $rfid_tag = $cgi->param( q{rfid_tag} );
  chomp $rfid_tag;
  if ( ! $rfid_tag ) {
    return $self->SUPER::update();
  }

  my $model = $self->model();

  # use the hash key here, since we don't want to make a call out to the
  # database and modify the sha in the column - bad things would happen!
  $model->{rfid} = sha256_hex( $rfid_tag );
  $model->update();
  return 1;
}

sub list_rfid_check_ajax {
  my ( $self ) = @_;

  my $cgi = $self->util->cgi();

  my $rfid_tag = $cgi->param( q{rfid_tag} );

  chomp $rfid_tag;

  $self->{model} = npg::model::user->new({
      util => $self->util(),
      rfid => $rfid_tag,
    });

  $self->model->read();

  return 1;
}



1;

__END__

=head1 NAME

npg::view::user

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - handling for users-by-user name

=head2 list - trap for unauthenticated clients

=head2 read - additional handling for filtering out already-subscribed groups from available ones

=head2 authorised

provide an authorisation when updating a user with an rfid

=head2 update

update method to help when updating the rfid, since we need to sha64hex it

=head2 list_rfid_check_ajax

enable an ajax call to be made, which will check if the person checking in with their rfid is a loader

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item npg::view

=item npg::model::usergroup

=item Carp

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
