#############
# Created By: Jillian Durham (jillian)
# Created On: 2014-03-20

package npg_tracking::data::transcriptome::find;

use Moose::Role;
use Carp;
use Cwd 'abs_path';
use Readonly;

with qw/ npg_tracking::data::reference::find /;

our $VERSION = '0';


has '_organism_dir' => ( isa => q{Maybe[Str]},
                         is => q{ro},
                         lazy_build => 1,
                       );

sub _build__organism_dir {
  my $self = shift;
  my ($organism, $strain) = $self->_parse_reference_genome($self->lims->reference_genome);
  if ($organism){
    return($self->transcriptome_repository . "/$organism");
  }
  $self->messages->push('No organism found');
  return;
}


has '_version_dir' => ( isa => q{Maybe[Str]},
                         is => q{ro},
                         lazy_build => 1,
                       );

sub _build__version_dir {
  my $self = shift;

  my ($organism, $strain, $transcriptome_version) = $self->_parse_reference_genome($self->lims->reference_genome);
  if ($organism && $strain){
      if ($transcriptome_version){
          return($self->_organism_dir . "/$transcriptome_version/$strain/");
      }
      $self->messages->push('Not returning transcriptome directory as version not given ' . $self->lims->reference_genome);
  }
 return;
}

has 'gtf_path'     => ( isa => q{Maybe[Str]},
                        is => q{ro},
                        lazy_build => 1,
                        documentation => 'Path to the transcriptome GTF (GFF2) folder',);

sub _build_gtf_path {
  my $self = shift;
  ## symbolic link to default resolved with abs_path
  if ($self->_version_dir){
      return abs_path($self->_version_dir . '/gtf');
  }
  return;
}

has 'gtf_file' => ( isa => q{Maybe[Str]},
                    is => q{ro},
                    lazy_build => 1,
                    documentation => 'full name of GTF file',);

sub _build_gtf_file {
  my $self = shift;
  my @gtf_files;
  if ($self->gtf_path) { @gtf_files = glob $self->gtf_path . '/*.gtf'; }
  if (scalar @gtf_files > 1) { croak 'More than 1 gtf file in ' . $self->gtf_path; }

  if (scalar @gtf_files == 0) {
    if ($self->_organism_dir && -d $self->_organism_dir) {
      $self->messages->push('Directory ' . $self->_organism_dir . ' exists, but GTF file not found');
    }
    return;
  }
  return $gtf_files[0];
}

#transcriptomes/Homo_sapiens/ensembl_75_transcriptome/1000Genomes_hs37d5/tophat2/
has 'transcriptome_index_path' => ( isa => q{Maybe[Str]},
                                    is => q{ro},
                                    lazy_build => 1,
                                    documentation => 'Path to the tophat2 (bowtie2) indices folder',
                                  );

sub _build_transcriptome_index_path {
  my $self = shift;
  if ( $self->_version_dir){
     return abs_path($self->_version_dir . '/tophat2');
  }
  return;
}

#e.g. 1000Genomes_hs37d5.known (from 1000Genomes_hs37d5.known.1.bt2, 1000Genomes_hs37d5.known.2.bt2 ...)
has 'transcriptome_index_name' => ( isa => q{Maybe[Str]},
                                    is => q{ro},
                                    lazy_build => 1,
                                    documentation => 'Full path + prefix of files in the tophat2 (bowtie2) indices folder',
                                   );

sub _build_transcriptome_index_name {
  my $self = shift;
  my @indices;
  if ($self->transcriptome_index_path){ @indices = glob $self->transcriptome_index_path . '/*.bt2'}

  if (scalar @indices == 0){
    if ($self->_organism_dir && -d $self->_organism_dir) {
      $self->messages->push('Directory ' . $self->_organism_dir . ' exists, but GTF file not found');
    }
    return;
  }

  ##return up to prefix (remove everything after 'known')
  my $index_prefix = $indices[0];
  $index_prefix =~ s/known(\S+)$/known/smxi;
  return $index_prefix;
}


1;
__END__

=head1 NAME

npg_tracking::data::transcriptome::find

=head1 VERSION

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

=item Cwd

=item Readonly

=item npg_tracking::data::reference::find

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jillian Durham

=head1 LICENSE AND COPYRIGHT

Copyright (C) GRL by 2014 Jillian Durham (jillian@sanger.ac.uk)

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
