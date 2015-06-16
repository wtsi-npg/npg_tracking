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
  my $run_status;
  try {
    $run_folder_npg = $self->tracking_run()->folder_name();
    $run_status = $self->tracking_run()->current_run_status_description();
  } catch {
    carp $_;
  };

  my $match = 1;

  if ($run_folder_npg) {
    if( $run_folder ne $run_folder_npg ){
      carp "Run folder '$run_folder' does not match '$run_folder_npg' from NPG";
      $match = 0;
    }
  } else {
    if (!$run_status) {
      carp 'Neither run folder name nor run status is available';
      $match = 0;
    } else {
      if ($run_status ne 'run pending') {
        carp "No run folder name for run with status '$run_status'";
        $match = 0;
      }
    }
  }

  return $match;
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
