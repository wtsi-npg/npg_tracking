package npg_tracking::illumina::run::folder;

use Moose::Role;
use File::Spec::Functions qw/catdir/;

our $VERSION = '0';

with 'npg_tracking::runfolder::folder';

sub runfolder_path_is_valid {
  my ($self, $path) = @_;

  return -d $path && -d catdir($path, q{Data});
}

1;

__END__

=head1 NAME

npg_tracking::illumina::run::folder

=head1 SYNOPSIS

  package MyPackage;
  use Moose;

  with 'npg_tracking::illumina::run::folder';

=head1 DESCRIPTION

Illumina-specific wrapper around the shared runfolder path and location role.
The shared implementation and its historical documentation now live in
C<npg_tracking::runfolder::folder>; this package preserves the longstanding
Illumina role name and its Illumina-specific runfolder detector.

=head1 SUBROUTINES/METHODS

=head2 runfolder_path_is_valid

Illumina-specific check for a runfolder root.

=head1 BUGS AND LIMITATIONS

=head1 DEPENDENCIES

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

=head1 AUTHOR

=over

=item Andy Brown

=item Marina Gourtovaia

=item Martin Pollard

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013,2014,2015,2018,2019,2020,2023,2024,2026 Genome Research Ltd.

=cut
