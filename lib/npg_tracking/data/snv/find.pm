package npg_tracking::data::snv::find;

use Moose::Role;
use Carp;
use npg_tracking::util::abs_path qw(abs_path);

with qw/ npg_tracking::data::reference::find
         npg_tracking::data::bait::find
       /;

our $VERSION = '0';

Readonly::Scalar my $DEFAULT_SNV_BAIT_NAME => q{Standard};
Readonly::Scalar my $RNA_SNV_BAIT_NAME => q{Exome};

has 'snv_path' => ( isa        => q{Maybe[Str]},
                    is         => q{ro},
                    lazy_build => 1,
                    documentation => 'Path to the snv folder',
);
sub _build_snv_path {
  my $self = shift;

  my $path;
  my ($organism, $strain) = $self->parse_reference_genome($self->lims->reference_genome);
  if ($organism && $strain) {
    my $bait = $self->bait_name // $DEFAULT_SNV_BAIT_NAME;
    if ($self->lims->library_type && $self->lims->library_type =~ /(?:cD|R)NA/sxm) {
      $bait = $RNA_SNV_BAIT_NAME;
    }
    $bait =~ s/\ /_/msxg;
    $path = abs_path($self->snv_repository . "/$organism/default/$bait/$strain");
  }

  return $path;
}

has 'snv_file' => ( isa        => q{Maybe[Str]},
                    is         => q{ro},
                    lazy_build => 1,
                    documentation => 'Full absolute path of SNV file',
);
sub _build_snv_file {
   my $self = shift;

   my $snv_file;
   if ($self->snv_path) {
     my @snv_files = glob $self->snv_path . '/*.vcf.gz';
     if (scalar @snv_files > 1) {
       croak 'Too many vcf files in ' . $self->snv_path;
     }
     if (!@snv_files) {
        $self->messages->push('VCF files not found in ' . $self->snv_path);
     }
     $snv_file = $snv_files[0];
   } else {
     $self->messages->push('Failed to get svn_path');
   }

   return $snv_file;
}

1;
__END__

=head1 NAME

npg_tracking::data::snv::find

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

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jennifer Liddle

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Genome Research Limited

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
