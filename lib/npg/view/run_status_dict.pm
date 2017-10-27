package npg::view::run_status_dict;

use base qw(npg::view);
use strict;
use warnings;

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

1;

__END__

=head1 NAME

npg::view::run_status_dict - view handling for run_status_dicts

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - extended support for loading npg::model::run_status_dicts by description as well as id

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item npg::view

=item strict

=item warnings

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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
