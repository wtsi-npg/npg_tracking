#########
# Created by:       kt6
# Created on:       1 April 2014

package npg_tracking::util::build;

use strict;
use warnings;
use Carp;
use English qw(-no_match_vars);
use base 'Module::Build';

our $VERSION = '0';

##no critic (NamingConventions::Capitalization)

=head2 git_tag

 Returns values for a version based on git tag.
 Relies on scripts/gitver script being present.

=cut

sub git_tag {
  my $version;
  my $gitver = qq[/software/npg/src/npg_tracking/scripts/gitver];
  if (!-e $gitver) {
    carp "$gitver script not found";
    $version = q[unknown];
  }
  if (!-x $gitver) {
    carp "$gitver script is not executable";
    $version = q[unknown];
  }
  if (!$version) {
    ##no critic (InputOutput::ProhibitBacktickOperators)
    $version = `$gitver`;
    $version =~ s/\s$//smxg;
  }
  return $version;
}

=head2 ACTION_code

=cut

sub ACTION_code {
  my $self = shift;
  $self->SUPER::ACTION_code;

  my @dirs  = (q[./blib/lib], q[./blib/script]);
  for my $path (@dirs){
    opendir DIR, $path or next;   # skip dirs we can't read
    while (my $file = readdir DIR) {
      my $full_path = join q[/], $path, $file;
      if ($file eq q[.] or $file eq q[..]) { next; } # skip dot files
      if ( -d $full_path ) {
        push @dirs, $full_path; # add dir to list
      }
    }
    closedir DIR;
  }

  my @modules;
  foreach my $dir (@dirs) {
    opendir DIR, $dir or croak qq[Cannot read $dir: $ERRNO];
    while (my $file = readdir DIR) {
      if (-f "$dir/$file") {
        push @modules, $dir . q[/] . $file;
      }
    }
    closedir DIR;
  }

  my $gitver = $self->git_tag();
  warn "Changing version of all modules and scripts to $gitver\n";

  foreach my $module (@modules) {
    if ($self->verbose || $self->invoked_action() eq q[fakeinstall]) {
      warn "Changing version of $module to $gitver\n";
    }
    my $backup = '.original';
    local $INPLACE_EDIT = $backup;
    local @ARGV = ($module);
    while (<>) {
      ##no critic (RegularExpressions::RequireExtendedFormatting RegularExpressions::RequireLineBoundaryMatching)
      ##no critic (RegularExpressions::RequireDotMatchAnything RegularExpressions::ProhibitUnusedCapture)
      s/(\$VERSION\s*=\s*)('?\S+'?)\s*;/${1}'$gitver';/;
      s/head1 VERSION$/head1  VERSION\n\n$gitver/;
      print or croak 'Cannot print';
    }
    unlink "$module$backup";
  }
  return;
}
1;

=head1 NAME 

 npg_tracking::util::build

=head1 VERSION

=head1 SYNOPSIS
 
 # in your Build.PL
 use npg_tracking::util::Build
 # then use npg_tracking::util::Build as you would normally use Module::Build

=head1 DESCRIPTION

 This module extends method of the Module::Build module. It uses gitver script
 provided in scripts in this package to get the git tag bases expression for
 the version and assigns this version to a $VERSION variable in all modules and scripts.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Module::Build

=item English

=item base

=back

=head1 NAME

=head1 BUGS AND LIMITATIONS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

=head1 AUTHOR

Kate Taylor, E<lt>kt6@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 GRL, by Kate Taylor

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

=cut
