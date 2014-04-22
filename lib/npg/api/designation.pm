#########
# Author:        rmp
# Created:       2009-01-29
#
package npg::api::designation;
use strict;
use warnings;
use base qw(npg::api::base);

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_designation description);
}


1;
__END__

=head1 NAME

npg::api::designation - Designation base-class, an interface onto npg.designation

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - constructor inherited from npg::api::base

  Takes optional util for overriding the service base_uri.

  my $oDesignation = npg::api::designation->new();

  my $oDesignation = npg::api::designation->new({
    'id_designation' => $iIdDesignation,
    'util'          => $oUtil,
  });

  my $oDesignation = npg::api::designation->new({
    'id_run'  => $iIdRun,
    'comment' => $sComment,
   #'id_user', 'date' and 'id_designation' are omitted for creation.
  });
  $oDesignation->create();

=head2 init - additional handling to deal with 'attachment' filehandles

  $oDesignation->init();

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::api::<pkg>->fields();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

npg::api::base

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
