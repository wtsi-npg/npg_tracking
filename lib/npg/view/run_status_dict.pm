#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::view::run_status_dict;
use base qw(npg::view);
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars);

our $VERSION = '0';

sub new {
  my ($class, @args) = @_;
  my $self  = $class->SUPER::new(@args);
  my $model = $self->model();
  my $idrsd = $model->id_run_status_dict();

  if($idrsd && $idrsd !~ /^\d+$/smx) {
    $model->description($model->id_run_status_dict());
    $model->id_run_status_dict(0);
    $model->init();
  }

  return $self;
}

sub render {
  my ($self, @args) = @_;
  my $aspect = $self->aspect() || q();

  if($aspect eq 'read_xml') {
    $self->read_xml();
    return q[];
  }

  return $self->SUPER::render(@args);
}

sub read_xml {
  my $self  = shift;
  my $model = $self->model();

  $self->read();

  print "Content-type: text/xml\n\n" or croak $OS_ERROR;

  $self->process_template('run_status_dict_read_header_xml.tt2');

  for my $row (@{$model->runs()}) {
    $self->process_template('run_list_row_xml.tt2', {run=>$row});
  }

  $self->process_template('run_status_dict_read_footer_xml.tt2');

  #########
  # flush and close
  #
  $self->output_finished(1);

  return 1;
}

1;

__END__

=head1 NAME

npg::view::run_status_dict - view handling for run_status_dicts

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - extended support for loading npg::model::run_status_dicts by description as well as id

=head2 render - header handling of read_xml response

=head2 read_xml - streamed handling of read_xml response

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item npg::view

=item strict

=item warnings

=item Carp

=item English

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
