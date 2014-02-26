#############
# Created By: Jennifer Liddle (js10)
# Last Maintained By: $Author: mg8 $
# Created On: 2014-02-25

package npg_tracking::data::snv::find;

use strict;
use warnings;
use Moose::Role;
use Carp;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16549 $ =~ /(\d+)/mxs; $r; };

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
        $bait =~ s/\ /_/msxg;
        $bait ||= 'Standard';
        return $self->snv_repository . "/$organism/default/$bait/$strain";
    }
    return;
}

has 'snv_file' => ( isa => q{Maybe[Str]}, is => q{ro}, lazy_build => 1, documentation => 'full name of SNV file',);

sub _build_snv_file {
	my $self = shift;
	my @snv_files = glob $self->snv_path . '/*.vcf.gz';
	if (scalar @snv_files > 0) { return $snv_files[0]; }
	return;
}

sub _parse_reference_genome {
  my ($self,$reference_genome) = @_;
  if ($reference_genome) {
    my @a = $reference_genome =~/ (\S+) \s+ [(] (\S+) [)] /smx;
    if (scalar @a >= 2 && $a[0] && $a[1]) {
      return @a;
    }
  }
  return;
}


1;
__END__

=head1 NAME

npg_tracking::data::snv::find

=head1 VERSION

$Revision: 16549 $

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

=item Readonly

=item File::Spec::Functions

=item npg_tracking::data::reference::find

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: mg8 $

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 Jennifer Liddle (js10@sanger.ac.uk)

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
