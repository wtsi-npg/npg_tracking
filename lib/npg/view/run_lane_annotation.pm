#########
# Author:        ajb
# Created:       2007-03-28
#
package npg::view::run_lane_annotation;
use base qw(npg::view);
use strict;
use warnings;
use File::Type;
use English qw(-no_match_vars);
use Carp;
use npg::model::run_lane_annotation;

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
  my $aspect = $self->aspect() || q{};
  my $action = $self->action();
  my $requestor = $util->requestor();

  #########
  # Allow pipeline group access to the create_xml interface of run_annotation
  #
  if ($aspect eq 'create_xml' &&
     $requestor->is_member_of('pipeline')) {
    return 1;
  }

  if (($action eq 'create' || $action eq 'read') && ($requestor->is_member_of('annotators') || $requestor->is_member_of('engineers') || $requestor->is_member_of('loaders') || $requestor->is_member_of('manual_qc'))) {
    return 1;
  }

  return $self->SUPER::authorised();
}

sub add_ajax {
  my $self                = shift;
  my $cgi                 = $self->util->cgi();
  my $model               = $self->model();
  my $id_run_lane         = $cgi->param('id_run_lane');
  $model->{id_run_lane} = $id_run_lane;
  return;
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

  #########
  # setup to influence what is rendered in template
  #
  $model->{last_lane} = $cgi->param('last_lane');
  $model->{bad_lane} = $cgi->param('bad_lane');

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

npg::view::run_lane_annotation - view handling for run_lane_annotationes

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised - handling for 'pipeline' group access to annotation creation

=head2 create - set up requestor's id_user

=head2 decor - additional handling for read_attachment

=head2 new - additional handling for read_attachment

=head2 render - additional handling for read_attachment

=head2 add_ajax - handling to render AJAX form for submitting a run_lane_annotation

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

npg::view

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
