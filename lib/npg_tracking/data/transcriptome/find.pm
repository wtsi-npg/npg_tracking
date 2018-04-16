package npg_tracking::data::transcriptome::find;

use Moose::Role;
use Carp;
use npg_tracking::util::abs_path qw(abs_path);

Readonly::Scalar our $DEFAULT_ANALYSIS => q[tophat2];
Readonly::Hash our %ANALYSES => ('tophat2' => { 'ext'  => 'bt2' },
                                 'salmon'  => { 'ext'  => 'json' },);

with qw/ npg_tracking::data::reference::find /;

our $VERSION = '0';

has 'analysis' => (default  => $DEFAULT_ANALYSIS,
                   is       => 'ro',
                   required => 0,
                  );

has '_organism_dir' => ( isa        => q{Maybe[Str]},
                         is         => q{ro},
                         lazy_build => 1,
                       );

sub _build__organism_dir {
  my $self = shift;
  my ($organism, $strain) = $self->parse_reference_genome($self->lims->reference_genome);
  if ($organism){
    return $self->transcriptome_repository . "/$organism";
  }
  $self->messages->push('No organism found');
  return;
}

has '_version_dir' => ( isa        => q{Maybe[Str]},
                        is         => q{ro},
                        lazy_build => 1,
                      );

sub _build__version_dir {
  my $self = shift;

  my ($organism, $strain, $transcriptome_version) = $self->parse_reference_genome($self->lims->reference_genome);
  if ($organism && $strain){
    if ($transcriptome_version){
      return $self->_organism_dir . "/$transcriptome_version/$strain/";
    }
    $self->messages->push('Not returning transcriptome directory as version not given ' . $self->lims->reference_genome);
  }
  return;
}

has 'fasta_path' => (isa           => q{Maybe[Str]},
                     is            => q{ro},
                     lazy          => 1,
                     builder       => q{_build_fasta_path},
                     documentation => 'Path to transcriptome fasta folder',
                    );

sub _build_fasta_path {
    my $self = shift;
    return $self->_find_path('fasta');
}

has 'fasta_file' => (isa           => q{Maybe[Str]},
                     is            => q{ro},
                     lazy          => 1,
                     builder       => q{_build_fasta_file},
                     documentation => 'Full name of transcriptome fasta file',
                    );

sub _build_fasta_file {
  my $self = shift;
  return $self->_find_file('fasta', '{fa,fasta}');
}

has 'rnaseqc_gtf_path'  => ( isa           => q{Maybe[Str]},
                             is            => q{ro},
                             lazy_build    => 1,
                             documentation => 'Path to the transcriptome GTF (GFF2) folder used by RNA-SeQC',);

sub _build_rnaseqc_gtf_path {
  my $self = shift;
  return $self->_find_path('RNA-SeQC');
}

has 'rnaseqc_gtf_file' => ( isa           => q{Maybe[Str]},
                            is            => q{ro},
                            lazy_build    => 1,
                            documentation => 'Full name of GTF file used by RNA-SeQC',);

sub _build_rnaseqc_gtf_file {
  my $self = shift;
  return $self->_find_file('RNA-SeQC', 'gtf');
}

has 'gtf_path'     => ( isa           => q{Maybe[Str]},
                        is            => q{ro},
                        lazy_build    => 1,
                        documentation => 'Path to the transcriptome GTF (GFF2) folder',);

sub _build_gtf_path {
  my $self = shift;
  return $self->_find_path('gtf');
}

has 'gtf_file' => ( isa           => q{Maybe[Str]},
                    is            => q{ro},
                    lazy_build    => 1,
                    documentation => 'Full name of GTF file',);

sub _build_gtf_file {
  my $self = shift;
  return $self->_find_file('gtf', 'gtf');
}

has 'globin_path' => (isa           => q{Maybe[Str]},
                     is            => q{ro},
                     lazy          => 1,
                     builder       => q{_build_globin_path},
                     documentation => 'Path to directory of file with list of globin genes',
                    );

sub _build_globin_path {
    my $self = shift;
    return $self->_find_path('globin');
}

has 'globin_file' => (isa           => q{Maybe[Str]},
                     is            => q{ro},
                     lazy          => 1,
                     builder       => q{_build_globin_file},
                     documentation => 'Full name of transcriptome fasta file',
                    );

sub _build_globin_file {
  my $self = shift;
  return $self->_find_file('globin', 'csv');
}

#transcriptomes/Homo_sapiens/ensembl_75_transcriptome/1000Genomes_hs37d5/{tophat2,salmon}/
has 'transcriptome_index_path' => ( isa           => q{Maybe[Str]},
                                    is            => q{ro},
                                    lazy_build    => 1,
                                    documentation => 'Path to the aligner indices subfolder',
                                  );

sub _build_transcriptome_index_path {
  my $self = shift;
  my $subfolder = $self->analysis;
  return $self->_find_path($subfolder);
}

#e.g. 1000Genomes_hs37d5.known (from 1000Genomes_hs37d5.known.1.bt2, 1000Genomes_hs37d5.known.2.bt2 ...)
has 'transcriptome_index_name' => ( isa           => q{Maybe[Str]},
                                    is            => q{ro},
                                    lazy_build    => 1,
                                    documentation => 'Full path + prefix of files in the aligner or other analysis indices folder',
                                   );

sub _build_transcriptome_index_name {
  my $self = shift;
  my (@indices, $index_ext);
  $index_ext = $ANALYSES{$self->analysis}->{'ext'} // return;
  if ($self->transcriptome_index_path) {
    @indices = glob $self->transcriptome_index_path . q[/*.] . $index_ext;
  }
  if (scalar @indices == 0){
    if ($self->_organism_dir && -d $self->_organism_dir) {
      $self->messages->push('Directory ' . $self->_organism_dir . ' exists, but index files not found (' . $self->analysis . ')');
    }
    return;
  }
  return $self->_process_index_name($indices[0]);
}

sub _find_path {
    my ($self, $subfolder) = @_;
    ## symbolic link to default resolved with abs_path
    if ($self->_version_dir){
        return abs_path($self->_version_dir . q[/] . $subfolder);
    }
    return;
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
        if ($self->_organism_dir && -d $self->_organism_dir) {
            $self->messages->push(q[Directory ] . $self->_organism_dir . q[ exists, but *.] . $file_type . q[ file(s) not found]);
        }
        return;
    }
    return $files[0];
}

sub _process_index_name {
    my ($self, $index_name) = @_;
    if ($self->analysis eq q[tophat2]) {
        ## return up to prefix (remove everything after 'known')
        $index_name =~ s/known(\S+)$/known/smxi;
    } elsif ($self->analysis eq q[salmon]) {
        ## nothing to do for salmon as it requires only the folder
        ## name so transcriptome_index_path should be used instead
        return;
    }
    return $index_name;
}

1;
__END__

=head1 NAME

npg_tracking::data::transcriptome::find

=head1 SYNOPSIS

  package MyPackage;
  use Moose;
  with qw{npg_tracking::data::transcriptome::find};

=head1 DESCRIPTION

A Moose role for finding the location of transcriptome files.

These include files such as gtf or transcriptome fasta and the index file (prefix or path)

of a number of aligners and other analysis tools. Documentation on GTF (GFF version2) format

http://www.ensembl.org/info/website/upload/gff.html

=head1 SUBROUTINES/METHODS

=head2 analysis

 An optional attribute used to find the path and files of transcriptome indices

=head2 fasta_path

 Path to the transcriptome fasta folder

=head2 fasta_file

Full path to the transcriptome file in fasta format

=head2 gtf_path
 
 Path to the transcriptome GTF (GFF2) folder

=head2 gtf_file
 
 Full name of GTF file

=head2 rnaseqc_gtf_path
  
 Path to the transcriptome GTF (GFF2) folder used by RNA-SeQC

=head2 rnaseqc_gtf_file

 Full name of GTF file used by RNA-SeQC

=head2 transcriptome_index_name

 Full path plus prefix of files in the aligner or other analysis indices folder

=head2 transcriptome_index_path

 Path to the aligner or other analysis indices folder

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

Jillian Durham and Ruben Bautista

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

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
