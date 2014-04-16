#########
# Author:        jo3
# Created:       2010-04-28
#

package Monitor::Cbot::RunList;

use Moose;
extends 'Monitor::Cbot';

use namespace::autoclean;
use XML::LibXML;
our $VERSION = '0';


has '_url' => (
    reader     => 'url',
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

has '_latest_run_list' => (
    accessor   => 'latest_run_list',
    is         => 'rw',
    isa        => 'ArrayRef[XML::LibXML::Element]',
    predicate  => 'has_latest_run_list',
);


sub _build__url {
    my ($self) = @_;
    return q{http://} . $self->host_name() . q{/GetRunList};
}

sub current_run_list {
    my ($self) = @_;

    my $response = $self->_fetch( $self->url() );

    # nillable attributes have appeared in the XML (26/05/2010) that breaks
    # this code. Will need to be fixed if we want to use the run list info.
    my $xml = XML::LibXML->load_xml( string => $response->decoded_content() );
    $self->latest_run_list( [ $xml->getElementsByTagName('RunInformation') ] );

    return $xml;
}

no Moose;
__PACKAGE__->meta->make_immutable();


1;


__END__


=head1 NAME

Monitor::Cbot::RunList - methods and to retrieve and parse Cbot RunList.xml

=head1 VERSION


=head1 SYNOPSIS
    C<<use Monitor::Cbot::RunList;
       my $rl = Monitor::Cbot::RunList->new( cbot_name => $dummy_cbot, );
       my $run_list_xml = $rl->current_run_list();>>

=head1 DESCRIPTION

    This class retrieves the XML for a Cbot's run list and returns it to the
    caller.

=head1 SUBROUTINES/METHODS

=head2 current_run_list

    Return the instrument's current GetRunList report as an
    XML::LibXML::Document object. I don't know how long individual runs are
    stored here.

=head1 _build_url

    Construct the url for the run list based on the instrument name.

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
