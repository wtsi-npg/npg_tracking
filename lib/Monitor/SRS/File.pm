#########
# Author:        jo3
# Created:       2010-06-09

package Monitor::SRS::File;

use Moose;
use Carp;
use IO::All;
use MooseX::StrictConstructor;
use Perl6::Slurp;

our $VERSION = '0';

has [ 'run_folder', 'runfolder_path' ] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

with 'npg_tracking::illumina::run::long_info'
    => { -excludes => ['_fetch_recipe', '_fetch_runinfo'] };


sub _fetch_recipe {
    my ($self) = @_;

    my $runfolder_path = $self->runfolder_path();

    my @recipes;
    if ( $runfolder_path =~ m{^ ftp:// }imsx ) {

        foreach ( io($runfolder_path)->all() ) {

            # This is a recognised bug in Perl::Critic
            ## no critic (RegularExpressions::ProhibitCaptureWithoutTest)
            next if $_ !~ m{ \s+ ( Recipe \S* [.] xml ) }msx;
            push @recipes, "$runfolder_path/$1";

            ## use critic
        }

    }
    else {
        @recipes = glob $runfolder_path . '/Recipe*.xml';
    }

    croak 'No recipe file found' if scalar @recipes < 1;
    croak 'Multiple recipe files found: ' . join q(,), @recipes
        if scalar @recipes > 1;

    my $recipe_contents;
    if ( $recipes[0] =~ m{^ ftp:// }imsx ) {
        $recipe_contents = io( $recipes[0] )->slurp();

    }
    else {
        $recipe_contents = slurp $recipes[0];
    }

    return $recipe_contents;
}

sub _fetch_runinfo {
    my ($self) = @_;
    return io($self->runfolder_path().'/RunInfo.xml')->slurp;
}

no Moose;
__PACKAGE__->meta->make_immutable();
1;


__END__


=head1 NAME

Monitor::SRS::File - methods to read recipe files and other files.

=head1 VERSION


=head1 SYNOPSIS

    C<<use Monitor::SRS::File;
       my $file_obj = Monitor::SRS::File->new(
                        'run_folder'     => $folder_name,
                        'runfolder_path' => $folder_path,
        );
        eval { $file_obj->_fetch_recipe(); 1; ] or croak;
        printf "Exp cyc: %d\nIndex?: %d\nIndex Len: %d\nPaired?: %d\n",
                $file_obj->expected_cycle_count(),
                $file_obj->is_indexed(),
                $file_obj->index_length(),
                $file_obj->is_paired_read();>>

=head1 DESCRIPTION

A class to find and parse GA-II run files, config files, recipes etc,
agnostically from whether they are on the ftp site or on staging.

=head1 SUBROUTINES/METHODS

=head2 _fetch_recipe

Look for a single recipe file in the run folder. Croak if more than one, or if
no, recipe file is found.

This method over-rides the method of the same name in the Moose role
npg_tracking::illumina::run::long_info but the caller can make use of other methods
provided by that role. (See L</"SYNOPSIS">.)

=head2 _fetch_runinfo

Return the contents of the file RunInfo.xml at the runfolder path.

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
