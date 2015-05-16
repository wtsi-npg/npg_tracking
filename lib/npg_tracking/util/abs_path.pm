#############
# Created By: David K. Jackson
# Created On: 16 May 2015

package npg_tracking::util::abs_path;
use strict;
use warnings;
use Cwd;
use Exporter qw(import);
use npg_tracking::util::config qw/get_config/;

our @EXPORT_OK = qw(abs_path network_abs_path);

our $VERSION = '0';

my $config = get_config()->{'abs_path'}||{};
my ($pattern, $replacement) = @{$config}{qw(pattern replacement)};
if(not defined $replacement){ $replacement=q(); }
sub abs_path {
  my @a = @_;
  my $path = Cwd::abs_path @a;
  if(defined $pattern) {
    $path =~ s{$pattern}{$replacement}smgx;
  }
  return $path
}

*network_abs_path = \&abs_path;

1;
__END__

=head1 NAME

npg_tracking::util::abs_path

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Works like module Cwd's abs_path but then applies a substitution.

=head1 SUBROUTINES/METHODS

=head2 abs_path

  use npg_tracking::util::abs_path qw(abs_path);
  my $path = abs_path(q(/some/path));

=head2 network_abs_path

Alias of abs_path
 
=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

Applies substitution using "pattern" and "replacement" from "abs_path" section of npg_tracking config

=head1 DEPENDENCIES

=over

=item Cwd

=item Exporter

=item npg_tracking::util::config

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL, by David K. Jackson

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
