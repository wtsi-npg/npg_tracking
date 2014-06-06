#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::api::annotation;
use strict;
use warnings;
use base qw(npg::api::base);
use Carp;
use English qw(-no_match_vars);
use npg::api::user;

our $VERSION = '0';

#########
# we'll handle 'attachment' ourselves
# so don't autogenerate an accessor for it
#
__PACKAGE__->mk_accessors(grep { $_ ne 'attachment' } fields());

sub fields {
  return qw(id_annotation id_user date comment attachment_name attachment);
}

sub large_fields {
  return qw(attachment);
}

sub init {
  my $self = shift;
  if(ref $self->{'attachment'}) {
    local $RS = undef;
    my $fh    = $self->{'attachment'};
    $self->{'attachment'} = <$fh>;
  }
  return;
}

sub attachment {
  my ($self, $blob) = @_;

  if($blob) {
    $self->{'attachment'} = $blob;

  } elsif(!defined $self->{'attachment'} &&
    $self->attachment_name() &&
    $self->id_annotation()) {
    #########
    # If we've no attachment cached
    # but we do have an attachment name
    # and we've been assigned an id so presumably exist in the database
    #
    my $util       = $self->util();
    my ($obj_type) = (ref $self) =~ /([^:]+)$/smx;
    my $obj_pk     = $self->primary_key();
    my $obj_pk_val = $self->{$obj_pk};
    my $obj_uri    = sprintf '%s/%s/%s;read_attachment', $util->base_uri(), $obj_type, $obj_pk_val;
    $self->{'attachment'} = $util->get($obj_uri, []);

  } elsif(ref $self->{'attachment'}) {
    #########
    # attachment is a file handle on a local file
    # read it in and cache it (though it may be big)
    #
    local $RS = undef;
    my $fh    = $self->{'attachment'};
    $self->{'attachment'} = <$fh>;
  }

  return $self->{'attachment'};
}

sub create {
  my ($self, @args) = @_;
  eval {
    $self->check_user($self->username());
  } or do {
    croak $self->username() . ' does not have permission to create an annotation. Please email seq-help if you feel that you should be able to do this';
  };
  return $self->SUPER::create(@args);
}

sub check_user {
    my ( $self, $username ) = @_;

    my $user = npg::api::user->new( { util => $self->util,
                                      username => $username,
                                  } );

    if (!$user->id_user()) { return 0; }

    my $valid_groups = {
         q{admin}      => 1,
         q{annotators} => 1,
         q{engineers}  => 1,
         q{loaders}    => 1,
       };

    foreach my $group ( @{ $user->usergroups() } ) {
        if ($valid_groups->{$group->groupname()}) { return 1; }
    }

    return 0;
}

1;
__END__

=head1 NAME

npg::api::annotation - Annotation base-class, an interface onto npg.annotation

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - constructor inherited from npg::api::base

  Takes optional util for overriding the service base_uri.

  my $oAnnotation = npg::api::annotation->new();

  my $oAnnotation = npg::api::annotation->new({
    'id_annotation' => $iIdAnnotation,
    'util'          => $oUtil,
  });

  my $oAnnotation = npg::api::annotation->new({
    'id_run'  => $iIdRun,
    'comment' => $sComment,
   #'id_user', 'date' and 'id_annotation' are omitted for creation.
  });
  $oAnnotation->create();

=head2 init - additional handling to deal with 'attachment' filehandles

  $oAnnotation->init();

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::api::<pkg>->fields();

=head2 large_fields - accessors for large/lazy fields

  my @aLargeFields = $oPkg->large_fields();

=head2 id_annotation - Get/set the ID of this annotation

  my $iIdAnnotation = $oAnnotation->id_annotation();
  $oAnnotation->id_annotation($iIdAnnotation);

=head2 attachment - Get/set an attachment on this annotation

  my $sAttachmentBlob = $oAnnotation->attachment();
  $oAnnotation->attachment($fh);
  $oAnnotation->attachment($sAttachmentBlob);

=head2 attachment_name - Get/set attachment name on this annotation

  my $sAttachmentName = $oAnnotation->attachment_name();
  $oAnnotation->attachment_name($sAttachmentName);

=head2 id_user - Get/set the ID of the user writing / who wrote this annotation

  my $iIdUser = $oAnnotation->id_user();
  $oAnnotation->id_user($iIdUser);

=head2 date - When this annotation was written

  my $sDate = $oAnnotation->date();
  $oAnnotation->date($sDate);

=head2 comment - The comment on this annotation

  my $sComment = $oAnnotation->comment();
  $oAnnotation->comment($sComment);

=head2 create - wrapper for check_user, croak if user has no permission to annotate.

=head2 check_user - check that a valid user name has been supplied and their user group

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
