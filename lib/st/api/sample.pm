#########
# Author:        rmp
# Created:       2007-03-28
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/st/api/sample.pm, r 16477

package st::api::sample;

use base qw(st::api::base);
use strict;
use warnings;
use Carp;
use Data::Dumper;

__PACKAGE__->mk_accessors(fields());

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16477 $ =~ /(\d+)/smx; $r; };

sub _parse_taxon_id {
    my ($self, $taxon_id) = @_;
    # sometimes taxon ids are floats ending with .0; it's a result of uploading data from
    # Excel spreadsheets without checking the type. Safe to extract the integer part.
    if ($taxon_id) {
        my ($int_taxon_id) = $taxon_id =~ /^(\d+)\.0$/sxm;
        if ($int_taxon_id) {
	   carp q[Sample ] . $self->id . qq[: taxon id is a float $taxon_id];
           return $int_taxon_id;
        }
    }
    return $taxon_id;
}

sub live {
    my $self = shift;
    return $self->live_url()  . q{/samples};
}

sub dev {
    my $self = shift;
    return $self->dev_url()   . q{/samples};
}

sub fields { return qw( id name gc-content organism scientific-rationale concentration consent_withdrawn ); }

sub consent_withdrawn {
    my $self = shift;
    $self->parse();
    my $consent_withdrawn = $self->get( q(consent_withdrawn) );
    return $consent_withdrawn && $consent_withdrawn eq q{true};
}

sub description {
    my $self = shift;
    $self->parse();
    return $self->get(q[Sample Description])->[0];
}

sub organism {
    my $self = shift;
    $self->parse();
    my $result = $self->get(q(organism));
    return ref $result ? $result->[0] : $result
}

sub taxon_id {
    my $self = shift;
    $self->parse();
    return $self->_parse_taxon_id($self->get(q[TAXON ID])->[0]);
}

sub common_name {
    my $self = shift;
    $self->parse();
    return $self->get(q[Common Name])->[0];
}

sub public_name {
    my $self = shift;
    $self->parse();
    return $self->get(q[Public Name])->[0];
}

sub accession_number {
    my ( $self ) = @_;
    my $a_n = $self->get( 'ENA Sample Accession Number' ) || [];
    return $a_n->[0];
}

sub strain {
    my $self = shift;
    $self->parse();
    return $self->get(q[Strain])->[0];
}

sub reference_genome {
    my $self = shift;
    $self->parse();
    return ($self->get(q[Sample reference genome])||[])->[0] || $self->get(q[Reference Genome])->[0];
}

sub contains_nonconsented_human {
    my ( $self ) = @_;
    return $self->study()->contains_nonconsented_human();
}
*contains_unconsented_human = \&contains_nonconsented_human; #Backward compat

1;
__END__

=head1 NAME

st::api::sample - an interface to sample lims

=head1 VERSION

$Revision: 16477 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - fields in this package

    These all have default get/set accessors.

    my @aFields = $oSample->fields();
    my @aFields = <pkg>->fields();

=head2 dev - development service URL

    my $sDevURL = $oSample->dev();

=head2 live - live service URL

    my $sLiveURL = $oSample->live();

=head2 organism - convenience method for ->get('Organism');

    my $sOrganism = $oSample->organism();

=head2 strain - returns strain property

    my $strain = $oSample->strain();

=head2 common_name - returns common_name property

    my $common_name = $oSample->common_name();

=head2 public_name - returns public_name property

    my $public_name = $oSample->public_name();

=head2 accession_number

returns the accession_number should it have been provided

    my $sAccessionNumber = $oSample->accession_number();

=head2 taxon_id - returns taxon_id property

    my $taxon_id = $oSample->taxon_id();

=head2 reference_genome - string indictating the reference sequence which should be used for alignments

  my $refernceString = $oStudy->reference_genome();

=head2 gc_content - return the 'GQ content' field for the sample

    my  $GC_content = $oSample->gc_content();

=head2 rationale - return the sample's 'Scientific Rationale' field

    my $sci_rationale = $oSample->rationale();

=head2 concentration - return the sample's 'Concentration' field

    my $conc = $oSample->concentration();

=head2 priority - the 'Priority' field for the workflow_sample

    my $priority - $oWorkflowSample->priority();

=head2 study - st::api::study for this sample's study_id

    my $oStudy = $oSample->study();

=head2 contains_nonconsented_human - return the value for the study that this sample is from

  my $bContainsNonconsentedHuman = $oSample->contains_nonconsented_human();

=head2 contains_unconsented_human - (Backward compat) return the value for the study that this sample is from

  my $bContainsUnconsentedHuman = $oSample->contains_unconsented_human();

=head2 consent_withdrawn - boolean value indicating whether consent has been withdrawn for a sample containing human DNA

=head2 description - sample description

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item st::api::base

=item strict

=item warnings

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett

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
