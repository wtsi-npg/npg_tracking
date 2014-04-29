#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::api::run_annotation;
use strict;
use warnings;
use base qw(npg::api::annotation);
use Carp;

our $VERSION = '0';

#########
# most accessors are handled by the annotation superclass
#
__PACKAGE__->mk_accessors(qw(id_run_annotation id_run username));

sub fields {
  return qw(id_run_annotation id_annotation id_user date comment attachment_name attachment id_run username);
}

1;
__END__

=head1 NAME

npg::api::run_annotation - An interface onto npg.run_annotation + annotation

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - Constructor inherited from npg::api::base

  Takes optional util for overriding the service base_uri.

  my $oRunAnnotation = npg::api::run_annotation->new();

  my $oRunAnnotation = npg::api::run_annotation->new({
    'id_annotation' => $iIdAnnotation,
    'util'          => $oUtil,
  });

  my $oRunAnnotation = npg::api::run_annotation->new({
    'id_run'  => $iIdRun,
    'comment' => $sComment,
   #'id_user', 'date' and 'id_annotation' are omitted for creation.
  });
  $oRunAnnotation->create();

  #########
  # to attach files by filehandle
  #
  open my $fh, q(<), q(/path/to/gerald_output.pdf);
  my $oRunAnnotation = npg::api::run_annotation->new({
    'id_run'          => $iIdRun,
    'comment'         => $sComment,
    'attachment_name' => 'gerald_output.pdf',
    'attachment'      => $fh,
  });
  $oRunAnnotation->create();
  close $fh;

  #########
  # to attach files by blob
  #
  my $oRunAnnotation = npg::api::run_annotation->new({
    'id_run'          => $iIdRun,
    'comment'         => $sComment,
    'attachment_name' => 'gerald_output.pdf',
    'attachment'      => $sLargeFileBlob,
  });
  $oRunAnnotation->create();

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::api::<pkg>->fields();

=head2 id_annotation - Get/set the id of this annotation

  my $iIdAnnotation = $oRunAnnotation->id_annotation();
  $oRunAnnotation->id_annotation($iIdAnnotation);

=head2 id_user - Get/set the id of the user writing / who wrote this annotation

  my $iIdUser = $oRunAnnotation->id_user();
  $oRunAnnotation->id_user($iIdUser);

=head2 date - When this annotation was written

  my $sDate = $oRunAnnotation->date();
  $oRunAnnotation->date($sDate);

=head2 comment - The comment on this annotation

  my $sComment = $oRunAnnotation->comment();
  $oRunAnnotation->comment($sComment);

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
