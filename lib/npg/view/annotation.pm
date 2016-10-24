#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::view::annotation;
use base qw(npg::view);
use strict;
use warnings;
use File::Type;
use English qw(-no_match_vars);
use Carp;

our $VERSION = '0';

sub new {
  my ($class, @args) = @_;
  my $self   = $class->SUPER::new(@args);
  my $aspect = $self->aspect() || q();

  if($aspect eq 'read_attachment_xml') {
    $aspect = 'read_attachment';
    $self->aspect($aspect);
  }

  if($aspect eq 'read_attachment') {
    my $data = $self->model->annotation->attachment() || q();
    my $ft   = File::Type->new();
    $self->{'content_type'} = $ft->checktype_contents($data);
  }

  return $self;
}

sub decor {
  my $self   = shift;
  my $aspect = $self->aspect() || q();

  if($aspect eq 'read_attachment') {
    return 0;
  }

  return $self->SUPER::decor();
}

sub authorised {
  my $self   = shift;
  my $util   = $self->util();
  my $aspect = $self->aspect() || q[];
  my $action = $self->action();
  my $requestor = $util->requestor();

  if (($action eq 'create' || $action eq 'read') &&
      ($requestor->is_member_of('annotators') ||
       $requestor->is_member_of('engineers') ||
       $requestor->is_member_of('loaders') || $requestor->is_member_of('manual_qc')
     )) {
    return 1;
  }

  return $self->SUPER::authorised();
}

sub render {
  my ($self, @args) = @_;
  my $aspect = $self->aspect() || q();

  if($aspect eq 'read_attachment') {
    return $self->model->annotation->attachment();
  }

  return $self->SUPER::render(@args);
}

sub create {
  my $self      = shift;
  my $model     = $self->model();
  my $util      = $self->util();
  my $cgi       = $util->cgi();
  my $requestor = $util->requestor();

  if($requestor->username() eq 'pipeline') {
    my $username       = $cgi->param('username');
    my $pipe_requestor = npg::model::user->new({
            util     => $util,
            username => $username,
                 });
    $model->annotation->id_user($pipe_requestor->id_user());

  } else {
    $model->annotation->id_user($util->requestor->id_user());
  }

  $model->annotation->comment($cgi->param('comment'));

  if($cgi->param('attachment')) {
    my $fh    = $cgi->param('attachment');
    local $RS = undef;
    $model->annotation->attachment(<$fh>);
    $model->annotation->attachment_name($cgi->param('attachment_name')||"$fh");
  }

  return $self->SUPER::create();
}

1;

__END__

=head1 NAME

npg::view::annotation - view superclass for handling various types of X_annotations

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised - handling for 'pipeline' group access to annotation creation

=head2 create - set up requestor's id_user

=head2 decor - additional handling for read_attachment

=head2 new - additional handling for read_attachment

=head2 render - additional handling for read_attachment

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item npg::view

=item strict

=item warnings

=item File::Type

=item English

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
