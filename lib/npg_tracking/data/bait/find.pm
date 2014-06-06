#############
# Created By: Jennifer Liddle (js10)
# Created On: 2012-04-23

package npg_tracking::data::bait::find;

use strict;
use warnings;
use Moose::Role;
use Carp;
use File::Spec::Functions qw(catdir);
use Readonly;

with qw/ npg_tracking::data::reference::find /;

our $VERSION = '0';

Readonly::Scalar my $STRAIN_ARRAY_INDEX => 1;

has 'bait_name'     => ( isa => q{Maybe[Str]}, is => q{ro}, lazy_build => 1,
                        documentation => 'Bate name',);
sub _build_bait_name {
  my $self = shift;
  return $self->lims->bait_name;
}

has 'bait_path'     => ( isa => q{Maybe[Str]}, is => q{ro}, lazy_build => 1,
                                 documentation => 'Path to the bait folder',);
sub _build_bait_path {
  my ( $self ) = @_;
  my $bait_name = $self->bait_name;
  if ($bait_name) {
    # trim all white space around the name
    $bait_name =~ s/\A(\s)+//smx;
    $bait_name =~ s/(\s)+\z//smx;
  }
  if (!$bait_name) {
    $self->messages->push('Bait name not available.');
    return;
  }
  $bait_name =~ s/ /_/gsm;     # replace spaces with underscores
  my @refs = @{$self->refs};
  if (!@refs) {
    $self->messages->push('No reference found');
    return;
  }
  if (scalar @refs > 1) {
    ##no critic (ProhibitParensWithBuiltins)
    croak 'Multiple references returned: ' . join(q[ ], @refs);
    ##use critic
  }
  my $reference = $refs[0];
  my $repository = $self->ref_repository;
  $reference =~ s/.*$repository//smx;   # remove ref repository path
  my @a = split /\//smx,$reference;
  while (!$a[0]) {
    shift @a;
  }

  my $bpath = catdir($self->bait_repository, $bait_name, $a[$STRAIN_ARRAY_INDEX]);
  if (!-d $bpath) {
    $self->messages->push('Bait directory ' . $bpath . ' does not exist');
    return;
  }
  return $bpath;
}

has 'bait_intervals_path'   => ( isa => 'Maybe[Str]', is => 'ro', lazy_build => 1, writer => '_set_bait_intervals_path',);
sub _build_bait_intervals_path
{
  my $self = shift;
  return $self->_intervals_paths ? $self->_intervals_paths->[0] : undef;
}

has 'target_intervals_path' => ( isa => 'Maybe[Str]', is => 'ro', lazy_build => 1, writer => '_set_target_intervals_path',);
sub _build_target_intervals_path
{
  my $self = shift;
  return $self->_intervals_paths ? $self->_intervals_paths->[1] : undef;
}

has '_intervals_paths' => ( isa => 'ArrayRef', is => 'ro', lazy_build => 1,);
sub _build__intervals_paths {
  my $self = shift;
  my @files = ();
  if ($self->bait_path) {
    @files = glob $self->bait_path . '/*.interval_list';
    if (scalar @files != 2) {
      croak 'Wrong number of files in ' . $self->bait_path;
    }
    @files = sort @files;
    my $crt = $files[0];
    if ($crt !~ /CTR\.interval_list$/xms) {
      croak 'No CTR interval list';
    }

    my $ptr = $files[1];
    if ($ptr !~ /PTR\.interval_list$/xms) {
      croak 'No PTR interval list';
    }
  }
  return \@files;
}

1;
__END__

=head1 NAME

npg_tracking::data::bait::find

=head1 VERSION

=head1 SYNOPSIS

  package MyPackage;
  use Moose;
  with qw{npg_tracking::data::bait::find};

=head1 DESCRIPTION

A Moose role for finding the location of bait and target intervals files.

=head1 SUBROUTINES/METHODS

=head2 bait_name

=head2 bait_path

=head2 bait_intervals_path

=head2 target_intervals_path

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item Readonly

=item File::Spec::Functions

=item npg_tracking::data::reference::find

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jennifer Liddle

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 GRL by Jennifer Liddle (js10@sanger.ac.uk)

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
