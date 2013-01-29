#########
# Author:        jo3
# Maintainer:    $Author: mg8 $
# Created:       2010-04-28
# Last Modified: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# Id:            $Id: SRS.pm 16549 2013-01-23 16:49:39Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/Monitor/SRS.pm $

package Monitor::SRS;

use Moose;
extends 'Monitor::Instrument';

use Carp;
use MooseX::StrictConstructor;
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16549 $ =~ /(\d+)/smx; $r; };


sub validate_run_folder {
    my ( $self, $folder_name ) = @_;

    # Let 'npg_tracking::illumina::run::folder::validation->new' worry about missing args.

    my $validation =
        npg_tracking::illumina::run::folder::validation->new( run_folder => $folder_name );

    return $validation->check();
}


sub is_rta {
    my ( $self, $run_path ) = @_;

    croak 'Run folder not supplied' if !$run_path;

    my $rta_test = io( "$run_path/Data/" )->all();
    return if !$rta_test;

    $self->update_latest_contact();

    return scalar @{ [ $rta_test =~ m/Intensities/gmsx ] };
}


no Moose;
__PACKAGE__->meta->make_immutable();
1;


__END__


=head1 NAME

Monitor::SRS - base class for Illumina short read sequencer specific
modules.

=head1 VERSION

$Revision: 16549 $

=head1 SYNOPSIS

    C<use Moose;
    extends 'Monitor::SRS';>


=head1 DESCRIPTION

This is the superclass for Monitor::SRS classes.

=head1 SUBROUTINES/METHODS

=head2 validate_run_folder

Check that a run folder name is of an allowed format. Croaks if no run folder
name is supplied.

=head2 is_rta

Test a required runpath argument for the presence of directories/files that
show it is an rta run folder.

=head1 CONFIGURATION AND ENVIRONMENT


=head1 INCOMPATIBILITIES


=head1 BUGS AND LIMITATIONS


=head1 AUTHOR

John O'Brien, E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (C) 2010 GRL, by John O'Brien

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
