package npg_tracking::data::common;

use Moose::Role;
use Carp;
use File::Spec::Functions qw(catdir);

use npg_tracking::util::abs_path qw(abs_path);

our $VERSION = '0';


sub find_file {
  my ($self, $data_dir, $subfolder, $file_type) = @_;

  if (! $file_type ){
    croak q[File type is not defined];
  }

  my $file;
  if ($data_dir) {
    my $dir = ( $data_dir && $subfolder ) ?
        catdir($data_dir, $subfolder) : $data_dir;

    my @files;
    if (-d $dir) {
      @files = glob $dir . q[/*.] . $file_type;
    }

    if (scalar @files > 1) {
      croak qq[More than one $file_type file in $dir];
    }
    elsif (scalar @files == 0) {
      $self->messages->push(qq[File of type $file_type not found under $dir]);
    }
    else{
      $file = abs_path($files[0]);
    }
  }
  return $file;
}

no Moose::Role;

1;
__END__

=head1 NAME

npg_tracking::data::common

=head1 SYNOPSIS

=head1 DESCRIPTION

Moose role. Common functions for repository types.

=head1 SUBROUTINES/METHODS

=head2 find_file

 Given a data directory, sub-dir and file extension find the single matching file.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item File::Spec::Functions

=item npg_tracking::util::abs_path

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

