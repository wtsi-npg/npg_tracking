#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::view::run_annotation;
use base qw(npg::view::annotation);
use strict;
use warnings;
use File::Type;
use English qw(-no_match_vars);
use Carp;
use npg::model::run_annotation;

our $VERSION = '0';

sub authorised {
  my $self = shift;
  my $util   = $self->util();
  my $action = $self->action();
  my $aspect = $self->aspect();
  my $requestor = $util->requestor();

  if ( $aspect eq 'create_multiple_run_annotations'
      &&
     ( $requestor->is_member_of('loaders') || $requestor->is_member_of('annotators') ) ) {
    return 1;
  }

  return $self->SUPER::authorised();
}

sub add_ajax {
  my $self  = shift;
  my $cgi   = $self->util->cgi();
  my $model = $self->model();
  $model->{id_run} = $cgi->param('id_run');
  return;
}

sub create_multiple_run_annotations {
  my ( $self ) = @_;
  my $model = $self->model();

  $model->create();

  return;
}

1;

__END__

=head1 NAME

npg::view::run_annotation - view handling for run_annotations

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised

Check authorisation specific to this view, before handing off to base

=head2 add_ajax

set up id_run from CGI block

=head2 create_multiple_run_annotations

create the same annotation on multiple runs and instruments

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item npg::view::annotation

=item npg::model::run_annotation

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
