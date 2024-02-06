package npg_tracking::data::mapd::find;

use Moose::Role;
use Carp;
use Readonly;
use File::Spec;
use npg_tracking::util::abs_path qw(abs_path);

with qw/npg_tracking::data::reference::find/;

requires qw/read_length bin_size/;

our $VERSION = '0';

Readonly::Scalar my $MAPPABILITY_FILE => 'Combined_%s_%s_%s_%dbases_mappable_bins_GCperc_INPUT.txt';
Readonly::Scalar my $MAPPABILITY_BED_FILE => 'Combined_%s_%s_%s_%dbases_mappable_bins.bed';

has 'mappablebins_path' => (
    isa => 'Maybe[Str]',
    is => 'ro',
    lazy_build => 1,
);

has 'mappability_file' => (
    isa => 'Maybe[Str]',
    is => 'ro',
    lazy_build => 1,
);

has 'mappability_bed_file' => (
    isa => 'Maybe[Str]',
    is => 'ro',
    lazy_build => 1,
);

has 'chromosomes_path' => (
    isa => 'Maybe[Str]',
    is => 'ro',
    lazy_build => 1,
);

has 'chromosomes_file' => (
    isa => 'Maybe[Str]',
    is => 'ro',
    lazy_build => 1,
);

sub _build_mappablebins_path {
    my $self = shift;
    return $self->_find_path(q[MappableBINS]);
}

sub _build_chromosomes_path {
    my $self = shift;
    return $self->_find_path(q[chromosomes]);
}

sub _build_mappability_file {
    my $self = shift;
    return $self->_find_mappability_file(q[txt]);
}

sub _build_mappability_bed_file {
    my $self = shift;
    return $self->_find_mappability_file(q[bed]);
}

sub _build_chromosomes_file {
    my $self = shift;
    return $self->_find_file(q[chromosomes], q[txt]);
}

sub _find_path {
    my ($self, $dir_name) = @_;
    my $path;
    my ($organism, $strain) = $self->parse_reference_genome($self->lims->reference_genome);
    if ($organism && $strain) {
        $path = abs_path($self->custom_analysis_repository . "/mapd/$organism/$strain/$dir_name");
    }
    return $path;
}

sub _find_file {
    my ($self, $subfolder, $file_type) = @_;
    my $path = $self->_find_path($subfolder);
    my @files;
    if ($path) {
        @files = glob $path . q[/*.] . $file_type;
    }
    if (scalar @files > 1) {
        croak qq[More than one $file_type file in $path];
    }
    if (scalar @files == 0) {
        if ($subfolder && -d $subfolder) {
            $self->messages->push(qq[Directory $subfolder exists, but no such *.$file_type file exist]);
        }
        return;
    }
    return $files[0];
}

sub _find_mappability_file {
    my ($self, $file_type) = @_;
    my @files;
    my $mappablebins_path = $self->mappablebins_path;
    if ($mappablebins_path) {
        @files = glob $mappablebins_path . q[/*.] . $file_type;
    }
    if (scalar @files == 0) {
        $self->messages->push(q[Directory ]. $mappablebins_path.
                              q[ exists, but no such *.]. $file_type.
                              q[ file(s) exist]);
        return;
    }
    my $mappability_file;
    if ($file_type eq q[bed]) {
        $mappability_file = $MAPPABILITY_BED_FILE;
    } elsif ($file_type eq q[txt]) {
        $mappability_file = $MAPPABILITY_FILE;
    }
    my ($organism, $strain) = $self->parse_reference_genome($self->lims->reference_genome);
    if ($organism && $strain) {
        $mappability_file = sprintf $mappability_file,
                            $organism,  $strain, $self->bin_size, $self->read_length;
        $mappability_file = File::Spec->catfile($self->mappablebins_path, $mappability_file);
        if (! -e $mappability_file) {
            $self->messages->push(q[Mappability file ]. $mappability_file.
                                  q[ not found in ]. $mappablebins_path);
            return;
        }
    }
    return $mappability_file;
}

1;
__END__

=head1 NAME

npg_tracking::data::mapd::find

=head1 SYNOPSIS

  package MyPackage;
  use Moose;
  with qw{npg_tracking::data::mapd::find};


=head1 DESCRIPTION

A Moose role for finding the location of MAPD files.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Ruben Bautista

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 Genome Research Limited

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
