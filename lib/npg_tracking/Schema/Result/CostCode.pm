package npg_tracking::Schema::Result::CostCode;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

npg_tracking::Schema::Result::CostCode

=cut

__PACKAGE__->table("cost_code");

=head1 ACCESSORS

=head2 id_cost_code

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 cost_code

  data_type: 'varchar'
  is_nullable: 0
  size: 45

=head2 id_cost_group

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_cost_code",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "cost_code",
  { data_type => "varchar", is_nullable => 0, size => 45 },
  "id_cost_group",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key("id_cost_code");
__PACKAGE__->add_unique_constraint("cost_code_UNIQUE", ["cost_code"]);

=head1 RELATIONS

=head2 cost_group

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::CostGroup>

=cut

__PACKAGE__->belongs_to(
  "cost_group",
  "npg_tracking::Schema::Result::CostGroup",
  { id_cost_group => "id_cost_group" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.06001 @ 2011-08-16 10:39:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+iHuUYIksBXKoTFdE5+I3w


# You can replace this text with custom content, and it will be preserved on regeneration
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: srpipe $
# Created:       2010-04-08
# Last Modified: $Date: 2011-08-30 09:14:49 +0100 (Tue, 30 Aug 2011) $
# Id:            $Id: CostCode.pm 14071 2011-08-30 08:14:49Z srpipe $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/CostCode.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14071 $ =~ /(\d+)/mxs; $r; };

1;
