#############
# Created By: Jennifer Liddle (js10)
# Created On: 2014-02-25

package npg_tracking::data::snv::find;

use strict;
use warnings;
use Moose::Role;
use Carp;
use Cwd 'abs_path';

our $VERSION = '0';

with qw/ npg_tracking::data::reference::find 
         npg_tracking::data::bait::find
/;

has 'snv_path'     => ( isa => q{Maybe[Str]}, is => q{ro}, lazy_build => 1,
                                 documentation => 'Path to the snv folder',);

sub _build_snv_path {
    my $self = shift;
    my ($organism, $strain) = $self->_parse_reference_genome($self->lims->reference_genome);
    if ($organism && $strain) {
        my $bait = $self->bait_name;
        $bait ||= 'Standard';
        $bait =~ s/\ /_/msxg;
        return abs_path($self->snv_repository . "/$organism/default/$bait/$strain");
    }
    return;
}

has 'snv_file' => ( isa => q{Maybe[Str]}, is => q{ro}, lazy_build => 1, documentation => 'full name of SNV file',);

sub _build_snv_file {
   my $self = shift;
   my @snv_files;
  if ($self->snv_path) { @snv_files = glob $self->snv_path . '/*.vcf.gz'; }
   if (scalar @snv_files > 1) { croak 'Too many vcf files in ' . $self->snv_path; }

   if (scalar @snv_files == 0) {
       my ($organism, $strain) = $self->_parse_reference_genome($self->lims->reference_genome);
      if (-d $self->snv_repository . "/$organism") {
         $self->messages->push('Directory ' . $self->snv_repository . "/$organism exists, but no VCF files found");
      }
      return;
   }
   return $snv_files[0];
}


1;
__END__

=head1 NAME

npg_tracking::data::snv::find

=head1 VERSION

=head1 SYNOPSIS

  package MyPackage;
  use Moose;
  with qw{npg_tracking::data::snv::find};


=head1 DESCRIPTION

A Moose role for finding the location of VCF files.

=head1 SUBROUTINES/METHODS

=head2 snv_name

=head2 snv_path

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

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
