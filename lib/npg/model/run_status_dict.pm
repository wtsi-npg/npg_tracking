package npg::model::run_status_dict;

use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::run_status;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_all();

sub fields {
  return qw(id_run_status_dict description temporal_index);
}

sub init {
  my $self = shift;

  if($self->{description} &&
     !$self->{id_run_status_dict}) {
    my $query = q(SELECT id_run_status_dict
                  FROM   run_status_dict
                  WHERE  description = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->description());

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{id_run_status_dict} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub run_status_dicts_sorted {
  my ( $self ) = @_;

  my $pkg = __PACKAGE__;
  my $query = q(SELECT id_run_status_dict, description, temporal_index FROM ) .
                  $pkg->table().
                  q( WHERE iscurrent = 1
                  ORDER BY temporal_index);

  return $self->gen_getarray($pkg, $query);
}

1;
__END__

=head1 NAME

npg::model::run_status_dict

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init - support load-by-description

  $oRunStatusDict->init();

  e.g.
  my $oRSD = npg::model::run_status_dict->new({
      'util'        => $oUtil,
      'description' => 'pending',
  });

  print $oRSD->id_run_status_dict();

=head2 run_status_dicts - Arrayref of npg::model::run_status_dicts

  my $arRunStatusDicts = $oRunStatusDict->run_status_dicts();

=head2 run_status_dicts_sorted

Use instead of generated run_status_dicts to get a temporal ordered, current list

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Roger Pettett

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2006-2012,2013,2014,2025 Genome Research Ltd.

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
