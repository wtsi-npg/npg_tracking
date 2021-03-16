package npg::model::manufacturer;

use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_manufacturer
            name);
}

sub init {
  my $self = shift;

  if($self->{'name'} &&
     !$self->{'id_manufacturer'}) {
    my $query = q(SELECT id_manufacturer
                  FROM   manufacturer
                  WHERE  name = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->name());

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(scalar @{$ref}) {
      $self->{'id_manufacturer'} = $ref->[0]->[0];
    }
  }
  return 1;
}


1;
__END__

=head1 NAME

npg::model::manufacturer

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init - overridden base-class loader

  Allows instantiation by-name rather as well as id_manufacturer, e.g.
  my $mfct = npg::model::manufacturer->new({
                                            'util' => $util,
                                            'name' => 'Illumina',
                                           });

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::model

=item English

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008,2013,2014,2021 Genome Research Ltd.

This file is part of NPG.

NPG is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/ .

=cut
