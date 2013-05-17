#########
# Author:        jo3
# Maintainer:    $Author: jo3 $
# Created:       2010-04-28
# Last Modified: $Date: 2010-10-20 18:14:06 +0100 (Wed, 20 Oct 2010) $
# Id:            $Id: InstrumentStatus.pm 11416 2010-10-20 17:14:06Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/Monitor/Cbot/InstrumentStatus.pm $
#

package Monitor::Cbot::InstrumentStatus;

use Moose;
extends 'Monitor::Cbot';

use namespace::autoclean;
use XML::LibXML;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 11416 $ =~ /(\d+)/smx; $r; };


has '_url' => (
    reader     => 'url',
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

has '_latest_status' => (
    accessor   => 'latest_status',
    is         => 'rw',
    isa        => 'XML::LibXML::Document',
    predicate  => 'has_latest_status',
);

foreach my $attr
    (qw( instrument_name machine_name type instrument_state run_state ))
{
    has q{_} . $attr => (
        reader     => $attr,
        is         => 'ro',
        isa        => 'Str',
        lazy_build => 1,
    );
}

has '_percent_complete' => (
    reader     => 'percent_complete',
    is         => 'ro',
    isa        => 'Maybe[Int]',
    lazy_build => 1,
);

has '_is_enabled' => (
    reader     => 'is_enabled',
    is         => 'ro',
    isa        => 'Maybe[Bool]',
    lazy_build => 1,
);


sub _build__url {
    my ($self) = @_;

    return q{http://} . $self->host_name() . q{/InstrumentStatus};
}

sub _build__instrument_name {
    my ($self) = @_;

    $self->has_latest_status() || $self->current_status();
    my $content = $self->get_element_content( $self->latest_status(),
                                              'InstrumentName' );

    return $content;
}

sub _build__instrument_state {
    my ($self) = @_;

    $self->has_latest_status() || $self->current_status();
    my $content = $self->get_element_content( $self->latest_status(),
                                              'InstrumentState' );

    return $content;
}

sub _build__type {
    my ($self) = @_;

    $self->has_latest_status() || $self->current_status();
    my $content = $self->get_element_content( $self->latest_status(),
                                              'Type' );

    return $content;
}

sub _build__is_enabled {
    my ($self) = @_;

    $self->has_latest_status() || $self->current_status();
    my $content = $self->get_element_content( $self->latest_status(),
                                              'IsEnabled' );

    # This is dependent on the XML spec not changing - same as the whole
    # library.
    my $is_enabled = ( $content =~ m/^ true $/imsx ) ? 1 : 0;

    return $is_enabled;
}

sub _build__machine_name {
    my ($self) = @_;

    $self->has_latest_status() || $self->current_status();
    my $content = $self->get_element_content( $self->latest_status(),
                                              'MachineName' );

    return $content;
}

sub _build__percent_complete {
    my ($self) = @_;

    $self->has_latest_status() || $self->current_status();
    my $content = $self->get_element_content( $self->latest_status(),
                                              'PercentComplete' );

    ( $content eq q{} ) && ( $content = undef );

    return $content;
}

sub _build__run_state {
    my ($self) = @_;

    $self->has_latest_status() || $self->current_status();
    my $content = $self->get_element_content( $self->latest_status(),
                                              'RunState' );

    return $content;
}

sub current_status {
    my ($self) = @_;

    my $response = $self->_fetch( $self->url() );

    my $xml = XML::LibXML->load_xml( string => $response->decoded_content() );
    $self->latest_status($xml);

    return $xml;
}

no Moose;

__PACKAGE__->meta->make_immutable();


1;

__END__


=head1 NAME

Monitor::Cbot::InstrumentStatus

=head1 VERSION

$Revision: 11416 $

=head1 SYNOPSIS

    C<<use Monitor::Cbot::InstrumentStatus;
       my $query      = Monitor::Cbot::InstrumentStatus->new_with_options();
       my $status_xml = $query->current_status();>>

=head1 DESCRIPTION

This class retrieves the XML for a Cbot's instrument status page and returns
it, or returns elements of it, to the caller.

=head1 SUBROUTINES/METHODS

=head2 current_status

Return the instrument status report as an XML::LibXML::Document object.
Currently the first child node is labelled RunStatus, not InstrumentStatus.

=head1 _build__url

Construct the url for the instrument status report based on the instrument
name.

=head1 _build_instrument_name

Extract the instrument name entry from the xml and return it.

=head1 _build__instrument_state

Extract the instrument state entry from the xml and return it.

=head1 _build__type

Extract the build type entry from the xml and return it.

=head1 _build__is_enabled

Extract the 'is enabled' entry from the xml and return it.

=head1 _build__machine_name

Extract the machine name entry from the xml and return it.

=head1 _build__percent_complete

Extract the percent complete entry from the xml and return it.

=head1 _build__run_state

Extract the run state entry from the xml and return it.


=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

I don't know how stable the format of the reports are. This code can change at
any time.

=head1 AUTHOR

John O'Brien, E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (C) 2010 GRL, by John O'Brien

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

=cut
