package npg_tracking::illumina::run::folder::validation;

use Moose;
use Carp;
use Try::Tiny;

use npg_tracking::Schema;

with qw{
  npg_tracking::illumina::run::short_info
  npg_tracking::illumina::run
};

our $VERSION = '0';

has npg_tracking_schema => (
  is         => 'ro',
  isa        => 'npg_tracking::Schema',
  lazy_build => 1,
);
sub _build_npg_tracking_schema {
  my ($self) = @_;
  return npg_tracking::Schema->connect();
}

sub check{
  my $self = shift;

  my $run_folder = $self->run_folder();
  my $run_folder_npg;
  my $run_row;

  try {
    $run_row        = $self->tracking_run();
    $run_folder_npg = $self->tracking_run()->folder_name();
  } catch {
    carp $_;
  };

  my $match = 0;

  if ($run_folder_npg) {
    if( $run_folder eq $run_folder_npg ){
      $match = 1;
    } else {
      warn "Run folder '$run_folder' does not match '$run_folder_npg' from NPG\n";
    }
  } else {
    if ($run_row) {
      my $expected = $self->_expected_name();
      warn "Expected run folder name: $expected\n";
      $match = $run_folder eq $expected;
    }
  }

  return $match;
}

sub _expected_name {
  my $self = shift;

  my $date = $self->tracking_run()->loading_date();

  return sprintf '%s_%s_%s%s',
    $date ? substr($date->ymd(q[]), 2) : q[000000],
    $self->tracking_run()->name,
    $self->tracking_run()->is_tag_set('fc_slotB') ? 'B' : 'A',
    $self->tracking_run()->flowcell_id() ? q[_] . $self->tracking_run()->flowcell_id() : q[];
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_tracking::illumina::run::folder::validation

=head1 VERSION

=head1 SYNOPSIS

$validation = npg_tracking::illumina::run::folder::validation->new( run_folder => $run_folder, );
$validation->check();

=head1 DESCRIPTION

Given a run folder name, checks this is genuine or not against the tracking database

=head1 SUBROUTINES/METHODS

=head2 check

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item Try::Tiny

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL, by Guoying Qi

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
