package npg_tracking::data::primer_panel::find;

use strict;
use warnings;
use Moose::Role;
use Carp;
use Readonly;
use File::Spec::Functions qw(catdir);

use npg_tracking::util::abs_path qw(abs_path);

with qw/ npg_tracking::data::reference::find
         npg_tracking::data::common /;

our $VERSION = '0';

Readonly::Scalar our $FORM        => q[default];
Readonly::Scalar our $PP_NAME     => 0;
Readonly::Scalar our $PP_VERSION  => 1;

has 'primer_panel' => ( isa           => q{Maybe[Str]},
                        is            => q{ro},
                        lazy          => 1,
                        builder       => '_build_primer_panel',
                        documentation => 'The primer panel optionally including version',);

sub _build_primer_panel {
  my $self = shift;
  return $self->lims->gbs_plex_name;
}

has 'primer_panel_name' => ( isa           => q{Maybe[Str]},
                             is            => q{ro},
                             lazy          => 1,
                             builder       => '_build_primer_panel_name',
                             documentation => 'The primer panel name',);

sub _build_primer_panel_name {
  my $self = shift;
  my $name;
  if($self->primer_panel) {
    my @n = split /\//smx, $self->primer_panel;
    $name = $n[$PP_NAME];
  }
  return $name;
}

has 'primer_panel_version' => ( isa           => q{Maybe[Str]},
                                is            => q{ro},
                                lazy          => 1,
                                builder       => '_build_primer_panel_version',
                                documentation => 'The primer panel version',);

sub _build_primer_panel_version {
  my $self = shift;
  my $version;
  if($self->primer_panel) {
    my @v = split /\//smx, $self->primer_panel;
    $version = defined $v[$PP_VERSION] ? $v[$PP_VERSION] : $FORM;
  }
  return $version;
}

has 'primer_panel_path'=> ( isa           => q{Maybe[Str]},
                            is            => q{ro},
                            lazy          => 1,
                            builder       => q{_build_primer_panel_path},
                            documentation => q{Path to the primer panel folder},);

sub _build_primer_panel_path {
  my ( $self ) = @_;

  my $primer_panel_name = $self->primer_panel_name;
  if ($primer_panel_name) {
    # trim all white space around the name and replace spaces with underscores
    $primer_panel_name =~ s/\A(\s)+//smx;
    $primer_panel_name =~ s/(\s)+\z//smx;
    $primer_panel_name =~ s/ /_/gsm;
  }
  else {
    $self->messages->push('Primer panel name not available.');
    return;
  }

  my ($organism, $strain) =
      $self->parse_reference_genome($self->lims->reference_genome);

  my $path = catdir
      ($self->primer_panel_repository, $primer_panel_name,
       $self->primer_panel_version, $organism, $strain);

  if (!-d $path) {
    $self->messages->push('Primer panel directory ' . $path . ' does not exist');
    return;
  }
  return abs_path($path);
}


has 'primer_panel_bed_file' =>
    (isa           => q{Maybe[Str]},
     is            => q{ro},
     lazy          => 1,
     builder       => q{_build_primer_panel_bed_file},
     documentation => 'Full path to primer panel bed file',
    );

sub _build_primer_panel_bed_file {
  my $self = shift;
  return $self->find_file($self->primer_panel_path, q[], 'bed');
}


1;
__END__

=head1 NAME

npg_tracking::data::primer_panel::find

=head1 VERSION

=head1 SYNOPSIS

  package MyPackage;
  use Moose;
  with qw{npg_tracking::data::primer_panel::find};

=head1 DESCRIPTION

A Moose role for finding the location of primer panel related files.

=head1 SUBROUTINES/METHODS

=head2 primer_panel_name

Note gbs_plex_name is an alias for primer_panel.

=head2 primer_panel_path

=head2 primer_panel_bed_file

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

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020 GRL 

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

