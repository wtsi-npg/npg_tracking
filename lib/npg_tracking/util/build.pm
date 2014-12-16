#########
# Created by:       kt6
# Created on:       1 April 2014

package npg_tracking::util::build;

use strict;
use warnings;
use File::Find;
use Carp;
use English qw(-no_match_vars);

use base 'Module::Build';

our $VERSION = '0';

my $gitver = git_tag();
##no critic (NamingConventions::Capitalization)

sub git_tag {
  ##no critic (InputOutput::ProhibitBacktickOperators)
  my $version = `git describe --always --dirty`|| q[unknown];
  ##use critic
  $version =~ s/\s$//smxg;
  $version=~s/\A(?![\d])/0.0-/smx;
  return $version;
}

sub ACTION_code {
  my $self = shift;
  $self->SUPER::ACTION_code;
  my @dirs = grep { -d $_ } qw(blib/lib blib/script);
  if (!@dirs) {
    return;
  }
  warn "Changing version of all modules and scripts to $gitver\n";
  find({'wanted' => \&_change_version, 'follow' => 0, 'no_chdir' => 1}, @dirs);
  return;
}

sub _change_version {
  my $module = $File::Find::name;
  if (-d $module) {
    return;
  }
  my $backup = '.original';
  local $INPLACE_EDIT = $backup;
  local @ARGV = ($module);
  while (<>) {
    ##no critic (RequireExtendedFormatting RequireLineBoundaryMatching)
    ##no critic (RequireDotMatchAnything ProhibitUnusedCapture)
    s/(\$VERSION\s*=\s*)('?\S+'?)\s*;/${1}'$gitver';/;
    s/head1 VERSION$/head1  VERSION\n\n$gitver/;
    print or croak 'Cannot print';
  }
  unlink "$module$backup";
  return;
}

1;
__END__

=head1 NAME 

 npg_tracking::util::build

=head1 SYNOPSIS
 
 # in your Build.PL
 use npg_tracking::util::build
 # then use npg_tracking::util::build as you would normally use Module::Build

=head1 DESCRIPTION

 This module extends Module::Build. It uses "git describe" command
 to get git tag as a base for the version. It extends the ACTION_code method of the
 parent to assign the value returned by its git_tag method to a $VERSION variable
 in all modules and scripts of the disctribution.

=head1 SUBROUTINES/METHODS

=head2 git_tag

=head2 ACTION_code

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Module::Build

=item File::Find

=item base

=item English

=back

=head1 NAME

=head1 BUGS AND LIMITATIONS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

=head1 AUTHOR

Kate Taylor, E<lt>kt6@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Limited

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
