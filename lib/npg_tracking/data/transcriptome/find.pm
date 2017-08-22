package npg_tracking::data::transcriptome::find;

use Moose::Role;
use Carp;
use npg_tracking::util::abs_path qw(abs_path);

Readonly::Scalar our $ALIGNER => q[tophat2];
Readonly::Scalar our $QUANTIFIER => q[salmon];

with qw/ npg_tracking::data::reference::find /;

our $VERSION = '0';

sub _find_path {
    my $self = shift;
    ## symbolic link to default resolved with abs_path
    if ($self->_version_dir){
        return abs_path($self->_version_dir . q[/] . $self->_subfolder);
    }
    return;
}

sub _find_file {
    my $self = shift;
    my @files;
    my $file_type = $self->_file_type;
    my $path = $self->_find_path;
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
    if ($self->analysis eq $ALIGNER) {
        ## return up to prefix (remove everything after 'known')
        $index_name =~ s/known(\S+)$/known/smxi;
    } elsif ($self->analysis eq $QUANTIFIER) {
        ## nothing to do for salmon as it requires only the folder
        ## name so transcriptome_index_path should be used instead
        return;
    }
    return $index_name;
}

has '_file_type' => (isa      => q{Maybe[Str]},
                     is       => q{ro},
                     required => 0,
                     writer   => q{_set_file_type},);

has '_subfolder' => (isa      => q{Maybe[Str]},
                     is       => q{ro},
                     required => 0,
                     writer   => q{_set_subfolder},);

has '_index_name_ext' => (isa      => q{Str},
                          is       => q{ro},
                          required => 0,
                          lazy     => 1,
                          builder  => q{_build_index_name_ext},);

sub _build_index_name_ext {
    my $self = shift;
    my $ext = $self->analysis eq $ALIGNER ? q[bt2] :
              $self->analysis eq $QUANTIFIER ? q[json] : return;
    return $ext;
}

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
    $self->_set_subfolder('fasta');
    return $self->_find_path;
}

has 'fasta_file' => (isa           => q{Maybe[Str]},
                     is            => q{ro},
                     lazy          => 1,
                     builder       => q{_build_fasta_file},
                     documentation => 'Full name of transcriptome fasta file',
                    );

sub _build_fasta_file {
  my $self = shift;
  $self->_set_subfolder('fasta');
  $self->_set_file_type('fa');
  return $self->_find_file;
}

has 'rnaseqc_gtf_path'  => ( isa           => q{Maybe[Str]},
                             is            => q{ro},
                             lazy_build    => 1,
                             documentation => 'Path to the transcriptome GTF (GFF2) folder used by RNA-SeQC',);

sub _build_rnaseqc_gtf_path {
  my $self = shift;
  $self->_set_subfolder('RNA-SeQC');
  return $self->_find_path;
}

has 'rnaseqc_gtf_file' => ( isa           => q{Maybe[Str]},
                            is            => q{ro},
                            lazy_build    => 1,
                            documentation => 'Full name of GTF file used by RNA-SeQC',);

sub _build_rnaseqc_gtf_file {
  my $self = shift;
  $self->_set_subfolder('RNA-SeQC');
  $self->_set_file_type('gtf');
  return $self->_find_file;
}

has 'gtf_path'     => ( isa           => q{Maybe[Str]},
                        is            => q{ro},
                        lazy_build    => 1,
                        documentation => 'Path to the transcriptome GTF (GFF2) folder',);

sub _build_gtf_path {
  my $self = shift;
  $self->_set_subfolder('gtf');
  return $self->_find_path;
}

has 'gtf_file' => ( isa           => q{Maybe[Str]},
                    is            => q{ro},
                    lazy_build    => 1,
                    documentation => 'Full name of GTF file',);

sub _build_gtf_file {
  my $self = shift;
  $self->_set_subfolder('gtf');
  $self->_set_file_type('gtf');
  return $self->_find_file;
}

#transcriptomes/Homo_sapiens/ensembl_75_transcriptome/1000Genomes_hs37d5/{tophat2,salmon}/
has 'transcriptome_index_path' => ( isa           => q{Maybe[Str]},
                                    is            => q{ro},
                                    lazy_build    => 1,
                                    documentation => 'Path to the aligner indices subfolder',
                                  );

sub _build_transcriptome_index_path {
  my $self = shift;
  $self->_set_subfolder($self->analysis);
  return $self->_find_path;
}

#e.g. 1000Genomes_hs37d5.known (from 1000Genomes_hs37d5.known.1.bt2, 1000Genomes_hs37d5.known.2.bt2 ...)
has 'transcriptome_index_name' => ( isa           => q{Maybe[Str]},
                                    is            => q{ro},
                                    lazy_build    => 1,
                                    documentation => 'Full path + prefix of files in the tophat2 (bowtie2) indices folder',
                                   );

sub _build_transcriptome_index_name {
  my $self = shift;
  my (@indices, $index_ext);
  $index_ext = $self->_index_name_ext // return;
  if ($self->transcriptome_index_path) {
    @indices = glob $self->transcriptome_index_path . q[/*.] . $index_ext;
  }
  if (scalar @indices == 0){
    if ($self->_organism_dir && -d $self->_organism_dir) {
      $self->messages->push('Directory ' . $self->_organism_dir . ' exists, but index files not found');
    }
    return;
  }
  return $self->_process_index_name($indices[0]);
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

These are the gtf file and the tophat2 index file prefix (including paths).

Documentation on GTF (GFF version2) format http://www.ensembl.org/info/website/upload/gff.html

=head1 SUBROUTINES/METHODS

=head2 gtf_path
 
 Path to the transcriptome GTF (GFF2) folder

=head2 gtf_file
 
 Full name of GTF file

=head2 rnaseqc_gtf_path
  
 Path to the transcriptome GTF (GFF2) folder used by RNA-SeQC

=head2 rnaseqc_gtf_file

 Full name of GTF file used by RNA-SeQC

=head2 transcriptome_index_name

 Full path plus prefix of files in the tophat2 (bowtie2) indices folder

=head2 transcriptome_index_path

 Path to the tophat2 (bowtie2) indices folder

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

Jillian Durham

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
