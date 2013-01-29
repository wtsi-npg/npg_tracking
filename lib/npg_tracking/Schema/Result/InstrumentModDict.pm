package npg_tracking::Schema::Result::InstrumentModDict;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

npg_tracking::Schema::Result::InstrumentModDict

=cut

__PACKAGE__->table("instrument_mod_dict");

=head1 ACCESSORS

=head2 id_instrument_mod_dict

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'char'
  default_value: (empty string)
  is_nullable: 0
  size: 128

=head2 revision

  data_type: 'char'
  is_nullable: 1
  size: 64

=cut

__PACKAGE__->add_columns(
  "id_instrument_mod_dict",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "description",
  { data_type => "char", default_value => "", is_nullable => 0, size => 128 },
  "revision",
  { data_type => "char", is_nullable => 1, size => 64 },
);
__PACKAGE__->set_primary_key("id_instrument_mod_dict");

=head1 RELATIONS

=head2 instrument_mods

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentMod>

=cut

__PACKAGE__->has_many(
  "instrument_mods",
  "npg_tracking::Schema::Result::InstrumentMod",
  {
    "foreign.id_instrument_mod_dict" => "self.id_instrument_mod_dict",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.06001 @ 2010-09-07 09:30:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:q5EVl+wBUpIeTovpvrQS6A
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: jo3 $
# Created:       2010-04-08
# Last Modified: $Date: 2010-09-13 18:21:28 +0100 (Mon, 13 Sep 2010) $
# Id:            $Id: InstrumentModDict.pm 10867 2010-09-13 17:21:28Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/InstrumentModDict.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 10867 $ =~ /(\d+)/mxs; $r; };

1;

