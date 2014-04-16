#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::annotation;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use POSIX qw(strftime);
use npg::model::user;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_all();
__PACKAGE__->has_a('user');

sub fields {
  return qw(id_annotation
            id_user
            date
            comment
            attachment_name
            attachment);
}

sub create {
  my $self = shift;

  $self->{date} = strftime q(%Y-%m-%d %H:%M:%S), localtime;

  if ( ! $self->id_user() ) {
    $self->id_user( $self->util()->requestor()->id_user() );
  }

  if ( ! defined $self->comment() ) {
    $self->comment( ( $self->util()->cgi()->param( 'comment' ) || q{} ) );
  }

  return $self->SUPER::create();
}

1;
__END__

=head1 NAME

npg::model::annotation

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 annotations - arrayref of all npg::model::annotations

  my $arAnnotations = $oAnnotation->annotations();

=head2 user - npg::model::user who made this annotation

  my $oUser = $oAnnotation->user();

=head2 create - date handling for annotation creation

  $oAnnotation->create() or croak 'failed to create';

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

=item npg::model::user

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett
Copyright (C) 2010 GRL, by John O'Brien

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
