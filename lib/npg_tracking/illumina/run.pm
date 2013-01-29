#############
# $Id: run.pm 16549 2013-01-23 16:49:39Z mg8 $
# Created By: dj3
# Last Maintained By: $Author: mg8 $
# Created On: 2011-09-12
# Last Changed On: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/illumina/run.pm $

package npg_tracking::illumina::run;

use strict;
use warnings;
use Moose::Role;
use Carp qw(croak );

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16549 $ =~ /(\d+)/mxs; $r; };


##############
# public methods

has q{tracking_run}     => ( isa => q{npg_tracking::Schema::Result::Run}, is => q{ro}, lazy_build => 1,
                                 documentation => 'NPG tracking DBIC object for a run',);

#############
# builders

sub _build_tracking_run {
  my ( $self ) = @_;

  if ( $self->can(q(npg_tracking_schema)) and  $self->npg_tracking_schema() ) {

    if ( !$self->can(q(id_run)) || !$self->id_run() ) {
      croak q{Need id_run to obtain NPG tracking database run information};
    }

    return $self->npg_tracking_schema()->resultset(q(Run))->find($self->id_run());
  }

  croak q{Need NPG tracking schema to get a run object from it};
}

1;
__END__

=head1 NAME

npg_tracking::illumina::run

=head1 VERSION

$Revision: 16549 $

=head1 SYNOPSIS

=head1 DESCRIPTION

Provides and NPG tracking Run object given an id_run and a NPG tracking schema.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: mg8 $

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 David K. Jackson (david.jackson@sanger.ac.uk)

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
