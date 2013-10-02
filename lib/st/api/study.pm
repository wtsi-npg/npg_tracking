#########
# Author:        gq1
# Created:       2010-04-29
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/branches/prerelease-42.0/lib/st/api/project.pm, r8603

package st::api::study;

use base qw(st::api::base);
use strict;
use warnings;
use List::MoreUtils qw/ uniq /;
use Readonly;

__PACKAGE__->mk_accessors(fields());

Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 8603 $ =~ /(\d+)/smx; $r; };

sub live {
    my $self = shift;
    return $self->live_url()  . q{/studies};
}

sub dev {
    my $self = shift;
    return $self->dev_url()   . q{/studies};
}

sub fields { return qw( id name ); }

sub separate_y_chromosome_data {
  my $self = shift;
  my $result = $self->get('Does this study require Y chromosome data to be separated from X and autosomal data before archival?') || [];
  $result = $result->[0] || q[];
  return $result=~/yes|true|1/smix;
}

sub contains_nonconsented_xahuman {
  my $self = shift;
  my $unconsented_xahuman = $self->get('Does this study require the removal of X chromosome and autosome sequence?') || [];
  $unconsented_xahuman = $unconsented_xahuman->[0] || q[];
  return lc($unconsented_xahuman) eq q(yes);
}

sub contains_nonconsented_human {
  my $self = shift;
  my $unconsented_human = $self->get('Does this study contain samples that are contaminated with human DNA which must be removed prior to analysis?') || [];
  $unconsented_human = $unconsented_human->[0] || q[];
  return lc($unconsented_human) eq q(yes);
}
*contains_unconsented_human = \&contains_nonconsented_human; #backward compat

sub _emails_within_tag {
  my ($self,$type)=@_;
  if(not defined $type){
    $type=q{};
  }
  my $ra=$self->{_emails}{$type};
  if ($ra){
    return $ra;
  }
  my $doc=$self->read();
  my @nl = ($doc);
  if ($type) {
    @nl = $doc->getElementsByTagName($type);
  }
  my $results=[];
  for my $n (@nl){
    for my $e ($n->getElementsByTagName(q(email))){
      my $email = $e->textContent();
      if($email){
        $email=~s/\a\s+//smx;
        $email=~s/\s+\z//smx;
	if($email){
          push @{$results},$email;
	}
      }
    }
  }
  @{$results} = uniq sort @{$results};
  $self->{_emails}{$type}=$results;
  return $results;
}

sub email_addresses {
  my $self = shift;
  return $self->_emails_within_tag();
}

sub email_addresses_of_managers {
  my $self = shift;
  return $self->_emails_within_tag(q{managers});
}

sub email_addresses_of_followers {
  my $self = shift;
  return $self->_emails_within_tag(q{followers});
}

sub email_addresses_of_owners {
  my $self = shift;
  return $self->_emails_within_tag(q{owners});
}

sub reference_genome {
    my $self = shift;
    $self->parse();
    return $self->get(q[Reference Genome])->[0];
}

sub alignments_in_bam {
    my $self = shift;
    my $r = $self->get('Alignments in BAM');
    if( !defined $r || $r->[0] !~ m/false/smix ) {
      return 1;
    }
    return;
}

sub accession_number {
  my ( $self ) = @_;
  my $a_n = $self->get('ENA Study Accession Number') || [];
  return $a_n->[0];
}

sub title {
  my ( $self ) = @_;
  my $title = $self->get('Title') || [];
  return $title->[0];
}

sub description {
  my ( $self )  = @_;
  my $e = $self->get(q{Study description});
  my $d;
  if (defined $e) {
    $d = $e->[0];
  }
  return $d ? $d : undef;
}

sub data_access_group {
  my ( $self ) = @_;
  my $group = $self->get('Data access group') || [];
  return $group->[0];
}

1;
__END__

=head1 NAME

st::api::study - an interface to Sample Tracking studies

=head1 VERSION

$Revision: 8603 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - fields in this package

  These all have default get/set accessors.

  my @aFields = $oStudy->fields();
  my @aFields = <pkg>->fields();

=head2 dev - development service URL

  my $sDevURL = $oStudy->dev();

=head2 live - live service URL

  my $sLiveURL = $oStudy->live();

=head2 separate_y_chromosome_data - Does the study have associated samples in which there is Y human DNA data is not been consented for public release.

  my $split_y = $oStudy->separate_y_chromosome_data();

=head2 contains_nonconsented_human - Does the study have associated samples in which there is human DNA which has not been consented for release.

  my $do_not_release = $oStudy->contains_nonconsented_human();

=head2 contains_unconsented_human - (Backward compat) Does the study have associated samples in which there is human DNA which has not been consented for release.

=head2 contains_nonconsented_xahuman - as contains_nonconsented_human, but specifically for the X chromosome and autosome parts

=head2 email_addresses - arrayref of email addresses related to this study

  my $arEmailStrings = $oStudy->email_addresses();

=head2 email_addresses_of_followers - arrayref of email addresses of followers of this study

  my $arEmailStrings = $oStudy->email_addresses_of_followers();

=head2 email_addresses_of_managers - arrayref of email addresses of managers of this study

  my $arEmailStrings = $oStudy->email_addresses_of_managers();

=head2 email_addresses_of_owners - arrayref of email addresses of owners of this study

  my $arEmailStrings = $oProject->email_addresses_of_owners();

=head2 reference_genome - string indictating the reference sequence which should be used for alignments

  my $refernceString = $oStudy->reference_genome();

=head2 alignments_in_bam - are alignments wanted in BAM files produced for this study

  my $boolean = $oStudy->alignments_in_bam();

=head2 accession_number

returns the accession number from sequencescape for this study

  my $sAccessionNumber = $oStudy->accession_number();

=head2 title

returns the title for the study

  my $sTitle = $oStudy->title();

=head2 description

returns text description of the study

  my $sDescription = $oStudy->description();

=head2 data_access_group

returns group to which data access should be limited

  my $sGroup = $oStudy->data_access_group();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item st::api::base

=item strict

=item warnings

=item List::MoreUtils

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by gq1

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
