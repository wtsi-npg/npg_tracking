package npg_tracking::data::gbs_plex::find;

use strict;
use warnings;
use Moose::Role;
use Carp;
use Readonly;
use File::Spec::Functions qw(catdir catfile);

use npg_tracking::util::abs_path qw(abs_path);

with qw/ npg_tracking::data::reference::find 
         npg_tracking::data::common / => {
  -excludes    => [qw(refs)]
};

our $VERSION = '0';

Readonly::Scalar our $STRAIN  => q[default];
Readonly::Scalar our $SUBSET  => q[all];

has 'gbs_plex_name' => ( isa           => q{Maybe[Str]},
                         is            => q{ro},
                         lazy          => 1,
                         builder       => '_build_gbs_plex_name',
                         documentation => 'The gbs plex name',);

sub _build_gbs_plex_name {
  my $self = shift;
  return $self->lims->gbs_plex_name;
}


has 'gbs_plex_path'=> ( isa           => q{Maybe[Str]},
                        is            => q{ro},
                        lazy          => 1,
                        builder       => q{_build_gbs_plex_path},
                        documentation => q{Path to the gbs plex folder},);

sub _build_gbs_plex_path {
  my ( $self ) = @_;
  my $plex_name = $self->gbs_plex_name;
  if ($plex_name) {
    # trim all white space around the name
    $plex_name =~ s/\A(\s)+//smx;
    $plex_name =~ s/(\s)+\z//smx;
  }

  my $ppath;
  if (!$plex_name) {
    $self->messages->push('Plex name not available.');
  }else{
    $plex_name =~ s/ /_/gsm; # replace spaces with underscores

    my $path = catdir($self->gbs_plex_repository, $plex_name, $STRAIN, $SUBSET);

    if (!-d $path) {
       $self->messages->push('Plex directory ' . $path . ' does not exist');
    }
    $ppath = abs_path($path)
  }

  return $ppath;
}


has 'gbs_plex_annotation_path' => ( isa        => q{Maybe[Str]},
                                    is         => q{ro},
                                    lazy       => 1,
                                    builder    => q{_build_gbs_plex_annotation_path},);

sub _build_gbs_plex_annotation_path {
  my $self = shift;
  return $self->find_file($self->gbs_plex_path, q{bcftools}, q{annotation.vcf});
}


has 'gbs_plex_info_path' => ( isa        => q{Maybe[Str]},
                              is         => q{ro},
                              lazy       => 1,
                              builder    => q{_build_gbs_plex_info_path},);

sub _build_gbs_plex_info_path {
  my $self = shift;
  return $self->find_file($self->gbs_plex_path, q{bcftools}, q{info.json});
}


has 'gbs_plex_ploidy_path' => ( isa        => q{Maybe[Str]},
                                is         => q{ro},
                                lazy       => 1,
                                builder    => q{_build_gbs_plex_ploidy_path},);

sub _build_gbs_plex_ploidy_path {
  my $self = shift;
  return $self->find_file($self->gbs_plex_path, q{bcftools}, q{ploidy});
}


has 'gbs_plex_bed_path' => ( isa        => q{Maybe[Str]},
                             is         => q{ro},
                             lazy       => 1,
                             builder    => q{_build_gbs_plex_bed_path},);

sub _build_gbs_plex_bed_path {
  my $self = shift;
  return $self->find_file($self->gbs_plex_path, q{bcftools}, q{primer.bed});
}


sub refs {
  my $self = shift;

  my @refs = ();

  if (! $self->gbs_plex_name) {
    return \@refs;
  }

  if (! $self->gbs_plex_path) {
    return \@refs;
  }

  # check that the directory for the chosen aligner exists
  my $dir = catdir($self->gbs_plex_path, $self->aligner);
  if (!-e $dir) {
    croak sprintf 'Binary %s reference for %s does not exist; path tried %s',
        $self->aligner, $self->gbs_plex_name, $dir;
  }

  # read the fasta directory and get the file name with the reference
  my $path = catfile($dir, $self->ref_file_prefix($self->gbs_plex_path));

  if ($path) {
    push @refs, _abs_ref_path($path);
  }

  return \@refs;
}


1;
__END__

=head1 NAME

npg_tracking::data::gbs_plex::find

=head1 VERSION

=head1 SYNOPSIS

  package MyPackage;
  use Moose;
  with qw{npg_tracking::data::gbs_plex::find};

=head1 DESCRIPTION

A Moose role for finding the location of gbs plex related files.

=head1 SUBROUTINES/METHODS

=head2 gbs_plex_name

=head2 gbs_plex_path

=head2 gbs_plex_annotation_path

=head2 gbs_plex_info_path

=head2 gbs_plex_ploidy_path

=head2 refs

A reference to a list of gbs plex reference paths although only ever 1 - this is to 
be consistent with reference::find. If no reference found, an empty list is returned.
Examine the messages attribute after calling this function.

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
