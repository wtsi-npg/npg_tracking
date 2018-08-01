package npg_tracking::data::geno_refset::find;

use Moose::Role;
use Carp;
use Readonly;
use English qw(-no_match_vars);
use File::Spec::Functions qw(catdir);

use npg_tracking::util::abs_path qw(abs_path);

with qw/ npg_tracking::data::reference::find
         npg_tracking::data::common /;

our $VERSION = '0';

Readonly::Scalar my $STRAIN_INDEX => 1;
Readonly::Scalar my $STUDY => q[study];

has 'geno_refset_name' => ( isa           => q{Maybe[Str]},
                            is            => q{ro},
                            lazy          => 1,
                            builder       => '_build_geno_refset_name',
                            documentation => 'The geno refset name',);

sub _build_geno_refset_name {
  my $self = shift;
  if(!$self->lims->study_id){
    croak q[Study id is not defined];
  }
  return $STUDY . $self->lims->study_id;
}


has 'geno_refset_path'=> ( isa           => q{Maybe[Str]},
                           is            => q{ro},
                           lazy          => 1,
                           builder       => q{_build_geno_refset_path},
                           documentation => q{Path to the geno refset folder},);

sub _build_geno_refset_path {
  my ( $self ) = @_;

  if (!$self->geno_refset_name) {
    $self->messages->push('Geno refset name not available.');
    return;
  }

  my @refs = @{$self->refs};
  if (!@refs) {
    $self->messages->push('No reference found');
    return;
  }
  if (scalar @refs > 1) {
    $self->messages->push('Multiple references returned: ' . join q[ ], @refs );
    return;
  }
  my $reference  = $refs[0];
  my $repository = $self->ref_repository;
  $reference =~ s/.*$repository//smx;   # remove ref repository path
  my @a = split /\//smx,$reference;
  while (!$a[0]) {
    shift @a;
  }

  my $ppath = catdir($self->geno_refset_repository, $self->geno_refset_name, $a[$STRAIN_INDEX]);
  if (!-d $ppath) {
    $self->messages->push('Geno refset directory ' . $ppath . ' does not exist');
    return;
  }
  return abs_path($ppath);
}


has 'geno_refset_annotation_path' => ( isa        => q{Maybe[Str]},
                                       is         => q{ro},
                                       lazy       => 1,
                                       builder    => q{_build_geno_refset_annotation_path},);

sub _build_geno_refset_annotation_path {
  my $self = shift;
  return $self->find_file($self->geno_refset_path,q{bcftools}, q{annotation.vcf});
}


has 'geno_refset_info_path' => ( isa        => q{Maybe[Str]},
                                 is         => q{ro},
                                 lazy       => 1,
                                 builder    => q{_build_geno_refset_info_path},);

sub _build_geno_refset_info_path {
  my $self = shift;
  return $self->find_file($self->geno_refset_path,q{bcftools}, q{info.json});
}


has 'geno_refset_ploidy_path' => ( isa        => q{Maybe[Str]},
                                   is         => q{ro},
                                   lazy       => 1,
                                   builder    => q{_build_geno_refset_ploidy_path},);

sub _build_geno_refset_ploidy_path {
  my $self = shift;
  return $self->find_file($self->geno_refset_path, q{bcftools}, q{ploidy});
}


has 'geno_refset_bcfdb_path' => ( isa        => q{Maybe[Str]},
                                  is         => q{ro},
                                  lazy       => 1,
                                  builder    => q{_build_geno_refset_bcfdb_path},
                                  documentation => 'Indexed bcf database file',);

sub _build_geno_refset_bcfdb_path {
  my $self = shift;
  my $bcfdb;
  if ($self->find_file($self->geno_refset_path,q{bcfdb}, q{csi})){
    $bcfdb = $self->find_file($self->geno_refset_path,q{bcfdb}, q{bcf});
  }
  return $bcfdb;
}


no Moose::Role;

1;
__END__

=head1 NAME

npg_tracking::data::geno_refset::find

=head1 VERSION

=head1 SYNOPSIS

  package MyPackage;
  use Moose;
  with qw{npg_tracking::data::geno_refset::find};

=head1 DESCRIPTION

A Moose role for finding the location of gbs plex related files.

=head1 SUBROUTINES/METHODS

=head2 geno_refset_name

=head2 geno_refset_path

=head2 geno_refset_annotation_path

=head2 geno_refset_info_path

=head2 geno_refset_ploidy_path

=head2 geno_refset_bcfdb_path

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item Readonly

=item File::Spec::Functions

=item npg_tracking::util::abs_path

=item npg_tracking::data::reference::find

=item npg_tracking::data::common

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL 

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
