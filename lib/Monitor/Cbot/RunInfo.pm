#########
# Author:        jo3
# Maintainer:    $Author: jo3 $
# Created:       2010-04-28
# Last Modified: $Date: 2010-10-25 15:41:02 +0100 (Mon, 25 Oct 2010) $
# Id:            $Id: RunInfo.pm 11472 2010-10-25 14:41:02Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/Monitor/Cbot/RunInfo.pm $
#

package Monitor::Cbot::RunInfo;

use Moose;
extends 'Monitor::Cbot';

use namespace::autoclean;
use XML::LibXML;
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 11472 $ =~ /(\d+)/smx; $r; };


# A new element <Name/> has been added to the XML (26/5/2010) with an
# attribute, 'i:nil="true"', that breaks this code. Currently not used, will
# have to fix if we do use it.

has '_url' => (
    reader     => 'url',
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

has '_run_label' => (
    reader     => 'run_label',
    is         => 'ro',
    required   => 1,
);

has '_latest_run_info' => (
    accessor   => 'latest_run_info',
    is         => 'rw',
    isa        => 'XML::LibXML::Document',
    predicate  => 'has_latest_run_info',
);

foreach my $attr (qw( end_time    reagent_id protocol_name
                     user_name   run_result result_message
                     flowcell_id start_time experiment_type ))
{
    has q{_} . $attr => (
        reader     => $attr,
        is         => 'ro',
        isa        => 'Str',
        lazy_build => 1,
    );
}

sub _build__url {
    my ($self) = @_;
    return
        q{http://} . $self->host_name() . q{/RunInfo/} . $self->run_label();
}

sub _build__end_time {
    my ($self) = @_;

    $self->has_latest_run_info() || $self->current_run_info();
    my $content = $self->get_element_content( $self->latest_run_info(),
                                              'EndTime' );

    return $content;
}

sub _build__experiment_type {
    my ($self) = @_;

    $self->has_latest_run_info() || $self->current_run_info();
    my $content = $self->get_element_content( $self->latest_run_info(),
                                              'ExperimentType' );

    return $content;
}

sub _build__flowcell_id {
    my ($self) = @_;

    $self->has_latest_run_info() || $self->current_run_info();
    my $content = $self->get_element_content( $self->latest_run_info(),
                                              'FlowcellID' );

    return $content;
}

sub _build__protocol_name {
    my ($self) = @_;

    $self->has_latest_run_info() || $self->current_run_info();
    my $content = $self->get_element_content( $self->latest_run_info(),
                                              'ProtocolName' );

    return $content;
}

sub _build__reagent_id {
    my ($self) = @_;

    $self->has_latest_run_info() || $self->current_run_info();
    my $content = $self->get_element_content( $self->latest_run_info(),
                                              'ReagentId' );

    return $content;
}

sub _build__run_result {
    my ($self) = @_;

    $self->has_latest_run_info() || $self->current_run_info();
    my $content = $self->get_element_content( $self->latest_run_info(),
                                              'RunResult' );

    return $content;
}

sub _build__result_message {
    my ($self) = @_;

    $self->has_latest_run_info() || $self->current_run_info();
    my $content = $self->get_element_content( $self->latest_run_info(),
                                              'ResultMessage' );

    return $content;
}

sub _build__start_time {
    my ($self) = @_;

    $self->has_latest_run_info() || $self->current_run_info();
    my $content = $self->get_element_content( $self->latest_run_info(),
                                              'StartTime' );

    return $content;
}

sub _build__user_name {
    my ($self) = @_;

    $self->has_latest_run_info() || $self->current_run_info();
    my $content = $self->get_element_content( $self->latest_run_info(),
                                              'UserName' );

    return $content;
}

sub current_run_info {
    my ($self) = @_;

    my $response = $self->_fetch( $self->url() );
    my $xml = XML::LibXML->load_xml( string => $response->decoded_content() );

    $self->latest_run_info($xml);

    return $xml;
}

no Moose;
__PACKAGE__->meta->make_immutable();


1;


__END__


=head1 NAME

Monitor::Cbot::RunInfo

=head1 VERSION

$Revision: 11472 $

=head1 SYNOPSIS

    C<<use Monitor::Cbot::RunInfo;
       my $r_inf = Monitor::Cbot::RunInfo->new(
            cbot_name => $dummy_cbot,
            run_label => $dummy_label,
       );
       my $run_info_xml = $r_inf->current_run_info();>>

=head1 DESCRIPTION

    This class retrieves the XML for a Cbot's run info status page and returns
    it, or returns elements of it, to the caller.

=head1 SUBROUTINES/METHODS

=head2 current_run_info

    Return the instrument's current RunInfo report as an
    XML::LibXML::Document object. This method requires the run label as its
    only argument.

=head1 _build_url

    Construct the url for the run info report based on the instrument name and
    run label.

=head1 _build_end_time

    Extract the end time entry from the xml and return it.

=head1 _build_experiment_type

    Extract the experiment type entry from the xml and return it.

=head1 _build_flowcell_id

    Extract the flowcell id entry from the xml and return it.

=head1 _build_protocol_name

    Extract the protocol name entry from the xml and return it.

=head1 _build_reagent_id

    Extract the reagent id entry from the xml and return it.

=head1 _build_run_result

    Extract the run result entry from the xml and return it.

=head1 _build_result_message

    Extract the result message entry from the xml and return it.

=head1 _build_start_time

    Extract the start time entry from the xml and return it.

=head1 _build_user_name

    Extract the user name entry from the xml and return it.


=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

    I don't know how stable the format of the reports are. This code can
    change at any time.

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
