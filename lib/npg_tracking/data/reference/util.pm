package npg_tracking::data::reference::util;

use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;
use Exporter qw(import);

our @EXPORT_OK = qw(parse_reference_genome_name);

our $VERSION = '0';

sub parse_reference_genome_name {
  my $reference_genome = shift;

  $reference_genome or croak 'Reference genome name is not defined';

  my ($organism, $strain, $tversion, $analysis);

  $organism = '(?<organism>\S+)\s+';
  $strain = '(?<strain>\S+)';
  $tversion = '(?:\s+\+\s+(?<tversion>\S+))?';
  $analysis = '(?:\s+[[](?<analysis>\S+)[]])?';
  $reference_genome  =~ qr{$organism [(] $strain $tversion [)] $analysis}smx;
  $organism = $LAST_PAREN_MATCH{'organism'};
  $strain = $LAST_PAREN_MATCH{'strain'};
  $tversion = $LAST_PAREN_MATCH{'tversion'};
  $analysis = $LAST_PAREN_MATCH{'analysis'};

  if ($organism && $strain) {
    my @array = ($organism, $strain);
    if ($tversion || $analysis) {
      push @array, $tversion, $analysis;
    }
    return @array;
  }

  return; # To be compatible with the existing code, it is essential to return
          # an undefined value rather than an empty array.
}

1;

__END__

=head1 NAME

npg_tracking::data::reference::util

=head1 SYNOPSIS

=head1 DESCRIPTION

A collection of simple utility function in support of reference finder.

=head1 SUBROUTINES/METHODS

=head2 parse_reference_genome_name

Parses LIMs notation for reference genome, returns a list containing
an organism, strain (genome version) and, optionally, a transcriptome
version and/or a word indicating the type of analysis to be run.

Returns an undefined value if the input does not conform to the expected
pattern. Errors if the input string is undefined or empty.

  use npg_tracking::data::reference::util qw(parse_reference_genome_name);

  parse_reference_genome_name(q[]); # errors
  parse_reference_genome_name(); # errors

  my $name = 'Homo_sapiens (1000Genomes_hs37d5)';
  my @a = parse_reference_genome_name($name);
  print join q[, ], @a; # prints Homo_sapiens, 1000Genomes_hs37d5
  
  # 'ensembl_release_75' defines the transcriptom to use
  # 'star' defines an aligher to use
  $name = 'Homo_sapiens (1000Genomes_hs37d5 + ensembl_release_75) [star]';
  parse_reference_genome_name($name);
  print join q[, ], @a;
  # prints Homo_sapiens, 1000Genomes_hs37d5, ensembl_release_75, star

  $name = 'Homo_sapiens 1000Genomes_hs37d5'
  @a = parse_reference_genome_name($name); # no error, @a is undefined

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2024 Genome Research Ltd.

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
