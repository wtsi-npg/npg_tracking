package npg_tracking::heron::upload::run;

use strict;

use Carp;
use List::MoreUtils qw(any);
use Moose;
use MooseX::StrictConstructor;

our $VERSION = '0';

# COG-UK instrument make controlled vocabulary, see@
#
# https://docs.covid19.climb.ac.uk/metadata
#
our $ILLUMINA = qw(ILLUMINA);
our $ONT      = qw(OXFORD_NANOPORE);
our $PACBIO   = qw(PACIFIC_BIOSCIENCES);

has 'name' =>
    (isa           => 'Str',
     is            => 'ro',
     required      => 1,
     documentation => 'The COG-UK compliant run name',);

has 'instrument_make' =>
    (isa           => 'Str',
     is            => 'ro',
     required      => 1,
     documentation => 'The COG-UK compliant instrument make (controlled vocabulary)',);

has 'instrument_model' =>
    (isa           => 'Str',
     is            => 'ro',
     required      => 1,
     documentation => 'The COG-UK compliant instrument model',);

=head2 BUILD

Validates constructor arguments for correctness. See
https://docs.covid19.climb.ac.uk/metadata

=cut

sub BUILD {
   my ($self, $args) = @_;

   $args->{name}             or croak 'An empty name was supplied';
   $args->{instrument_make}  or croak 'An empty instrument_make was supplied';
   $args->{instrument_model} or croak 'An empty instrument_model was supplied';

   my $make = $args->{instrument_make};
   if (not any { $make eq $_ } ($ILLUMINA, $ONT, $PACBIO)) {
      croak "Invalid instrument make '$make'";
   }

   return 1;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=head1 NAME

npg_tracking::heron::upload::run

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Represents an instrument run to be uploaded to the COG-UK endpoint
described at at https://docs.covid19.climb.ac.uk/metadata.

Instances will validate their constructor arguments and raise an error
if any are invalid according to the description above.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Keith James <kdj@sanger.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020, Genome Research Limited. All Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the Perl Artistic License or the GNU General
Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
