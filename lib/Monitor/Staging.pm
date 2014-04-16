#########
# Author:        jo3
# Created:       2010-04-28

package Monitor::Staging;

use Moose;
with 'npg_tracking::illumina::run::folder::location';    # For @STAGING_AREAS
with 'Monitor::Roles::Schema';

use Monitor::RunFolder;

use Carp;
use English qw(-no_match_vars);
use MooseX::StrictConstructor;

use npg_tracking::illumina::run::folder::validation;


our $VERSION = '0';


has known_areas => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [ @npg_tracking::illumina::run::folder::location::STAGING_AREAS ] },
);


sub validate_areas {
    my ( $self, @arguments ) = @_;

    carp 'Empty argument list' if !@arguments;
    my $known_areas = $self->known_areas();

    my %check;
    foreach (@arguments) {
        my $area = $_;


        if (m/^ \d+ $/msx) {

            if ( !defined $known_areas->[ $_ + 0 ] ) {
                carp "Parameter out of bounds: $_";
                next;
            }

            $area = $known_areas->[$_];
        }


        if ( !-d $area ) {
            carp "Staging directory not found: $area";
            next;
        }

        carp "$area specified twice" if $check{$area};

        $check{$area}++;
    }

    my @validated = sort { $a cmp $b } keys %check;

    return @validated;
}


sub find_live_incoming {
    my ( $self, $staging_area ) = @_;

    croak 'Top level staging path required' if !$staging_area;
    croak "$staging_area not a directory"   if !-d $staging_area;

    my %path_for;

    foreach my $run_dir ( glob $staging_area . q{/{IL,HS}*/incoming/*} ) {

        next if !-d $run_dir;


        my $check = Monitor::RunFolder->new( runfolder_path => $run_dir );
        my $run_folder = $check->run_folder();

        my $validate = npg_tracking::illumina::run::folder::validation->
                            new( run_folder => $run_folder );

        next if !$validate->check($run_folder);

        $path_for{ $check->id_run() } = $run_dir;
    }


    # Remove any folders belonging to cancelled runs.
    my $run_status_rs = $self->schema->resultset('RunStatus')->search(
        {
            'run_status_dict.description' => 'run cancelled',
            'me.id_run '                  => { '-in' => [ keys %path_for ] },
            'me.iscurrent'                => 1,
        },
        {
            join => 'run_status_dict',
        }
    );

    while ( my $run_status_row = $run_status_rs->next() ) {
        my $cancelled_run_id = $run_status_row->id_run();

        if ( defined $path_for{$cancelled_run_id} ) {
             ( delete $path_for{$cancelled_run_id} ); }
    }

    return values %path_for;
}



no Moose;
__PACKAGE__->meta->make_immutable();
1;


__END__


=head1 NAME

Monitor::Staging - interrogate the staging area of an Illumina
short read sequencer.

=head1 VERSION


=head1 SYNOPSIS

    C<<use Monitor::Staging;
       my $stage_poll = Monitor::Staging->new();>>


=head1 DESCRIPTION

This class gets various bits of information from the staging area for a short
read sequencer (GA-II and HiSeq).

=head1 SUBROUTINES/METHODS

=head2 validate_areas

Check if the parameters passed to the method are valid staging areas. They
may be passed as absolute paths or as integer indices of some (hard-coded)
external array.

=head2 find_live_incoming

Take a staging area path as a required argument and return a list of all run
directories (no tests or repeats) found in incoming folders below it. I.e.
they match /staging_area/machine/incoming/run_folder


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
