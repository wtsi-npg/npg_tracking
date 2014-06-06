#############
# Created By: ajb
# Created On: 2011-01-06

package npg::email::event;
use strict;
use warnings;
use Carp;
use English qw{-no_match_vars};
use Readonly;
use Module::PluginFinder;

our $VERSION = '0';

=head1 NAME

npg::email::event

=head1 VERSION

=head1 SYNOPSIS

  use npg:email::event

  my $oNotify = npg:email::event->new(
    {
      event_row                => $job,
      schema_connection        => $schema,
      email_templates_location => $solexa_templates,
      log_file_path            => '/path/to/log/dir',
      log_file_name            => 'my_log_file.log',
    }
  );

=head1 DESCRIPTION

This class on construction returns back an object of the type of class expected for the event
information given, or if there is not an appropriate event type for mailing, undef

The api for all objects should be the same, and the methods to use are listed below.

=head1 SUBROUTINES/METHODS

=head2 new

Pass in the parameters as above. Returns an object of the appropriate type, or undef

undef is returned, so that you can handle not having an object as you choose.

Note: whilst this factory class is not a Moose object, the returned object may well be

=head2 run

  $oNotify->run();

This method will go off and run the notification methods required for the type of event/entity
you have specified

=cut

sub new {
  my ( $class, $data ) = @_;
  $data ||= {};
  my $wanted_object;

  if ( ! $data->{event_row} && ( ! $data->{entity_type} || ! $data->{event_type} ) ) {
    return;
  }

  $data->{entity_type} ||= q{};
  $data->{event_type}  ||= q{};

  eval {
    $wanted_object = Module::PluginFinder->new(
      search_path => 'npg::email::event',
      filter => sub {
        my ($filter_class, $imported_data) = @_;
        $filter_class->understands($imported_data)
      }
    )->construct( $data, $data );
  } or do {
    carp $EVAL_ERROR;
    undef $wanted_object;
  };
  return $wanted_object;
}


1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Carp

=item English -no_match_vars

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown (ajb@sanger.ac.uk)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
