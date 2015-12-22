package st::api::lims::ml_warehouse_auto;

use Moose;
use MooseX::StrictConstructor;
use Carp;

extends qw/ st::api::lims::ml_warehouse /;
with 'WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell' => {'autonomous' => 1};

our $VERSION = '0';

=head1 NAME

st::api::lims::ml_warehouse_auto

=head1 SYNOPSIS

  use st::api::lims;
  my $l = st::api::lims->new( id_run      => 18488,
                              position    => 1,
                              tag_index   => 1,
                              driver_type => q(ml_warehouse_auto)
  );

=head1 DESCRIPTION

"Autonomous" implementation of the ml_warehouse driver for st::api::lims
class. LIMs data are retrieved from the warehouse defined in
WTSI::DNAP::Warehouse::Schema. Look up using id_run via the warehouse's
products metrics table will be attempted (this may be convenient but not
always appropriate).

=head1 SUBROUTINES/METHODS

=head2 flowcell_barcode

=head2 id_flowcell_lims

=head2 id_run

=head2 position

Position, optional attribute.

=head2 tag_index

Tag index, optional attribute

=head2 iseq_flowcell

DBIx result set for the iseq_flowcell table

=head2 mlwh_schema

WTSI::DNAP::Warehouse::Schema connection

=head2 query_resultset

Inherited from WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell.
Modified to raise error when no records for the LIMs object are
retrieved.

=head2 children

=head2 spiked_phix_tag_index

 Read-only integer accessor, not possible to set from the constructor.
 Defined for a lane and all tags, including tag zero

=head2 to_string

Human friendly description of the object

=cut

no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item Carp

=item npg_tracking::util::types

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::tag

=item npg_tracking::glossary::flowcell

=item st::api::lims

=item st::api::lims::ml_warehouse

=item WTSI::DNAP::Warehouse::Schema

=item WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson E<lt>David.Jackson@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Ltd.

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
