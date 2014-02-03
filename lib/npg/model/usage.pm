#########
# Author:        rmp
# Maintainer:    $Author: gq1 $
# Created:       2008-04-21
# Last Modified: $Date: 2010-05-04 15:28:42 +0100 (Tue, 04 May 2010) $
# Id:            $Id: usage.pm 9207 2010-05-04 14:28:42Z gq1 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg/model/usage.pm $
#
package npg::model::usage;
use strict;
use warnings;
use base qw(npg::model);
use npg::model::instrument;
use Readonly;

Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 9207 $ =~ /(\d+)/smx; $r; };
Readonly::Scalar our $FUDGE_FACTOR => 12_000_000_000_000; # 12 Gbytes per PE lane (most common case)

sub current_repositories {
  my $self = shift;
  my $instrument = npg::model::instrument->new({
                                              util => $self->util(),
                                              });
  my $repositories = {};

  for my $i (@{$instrument->current_instruments()}) {
    my $r = $i->current_run();
    if(!$r) {
      next;
    }

    if($r->current_run_status->run_status_dict->description() =~ /archived|qc|discarded/smx) {
      next;
    }

    my $is_paired = $r->is_paired() || 0;

    for my $rl (@{$r->run_lanes()}) {
      my $p = $rl->project();
      if(!$p) {
        next;
      }

      my $proj_dir = $p->projectname();
      my $repo_dir = $p->repository_directory();
      my ($repo)   = $repo_dir =~ /(.*)$proj_dir/smx;
      if(!$repo) {
        next;
      }

      $repositories->{$repo} += $FUDGE_FACTOR*($is_paired+1);
    }
  }

  return [map { {
                 name     => $_,
                 required => $repositories->{$_},
              } } sort keys %{$repositories}];
}

1;
__END__

=head1 NAME

npg::model::usage

=head1 VERSION

$LastChangedRevision: 9207 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 current_repositories

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::model

=item npg::model::instrument

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: Roger M Pettett$

=head1 LICENSE AND COPYRIGHT

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
