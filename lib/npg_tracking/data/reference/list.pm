package npg_tracking::data::reference::list;

use Moose::Role;
use Moose::Util::TypeConstraints;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use File::Spec::Functions qw(catfile splitdir catdir);
use File::Basename;
use Cwd qw(abs_path);

use npg_tracking::util::config qw(get_config_repository);

our $VERSION = '0';

=head1 NAME

npg_tracking::data::reference::list

=head1 VERSION

=head1 SYNOPSIS

  my $lister = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::list/])
          ->new_object();
  my @known_organisms = @{$lister->organisms};
  my %map  = %{$lister->repository_contents};
  $lister->report(q[report.csv]);

=head1 DESCRIPTION

Interface (Moose role) for retrieving information about a reference repository.

=head1 SUBROUTINES/METHODS

=cut

my$config=get_config_repository();

Readonly::Scalar our $REP_ROOT           => $ENV{'NPG_REPOSITORY_ROOT'} || $config->{'root'} || q();
Readonly::Scalar our $SNV_DIR            => q[population_snv];
Readonly::Scalar our $TRANSCRIPTOMES_DIR => q[transcriptomes];
Readonly::Scalar our $REFERENCES_DIR     => q[references];
Readonly::Scalar our $META_REFERENCES_DIR => q[meta_references];
Readonly::Scalar our $ADAPTERS_DIR       => q[adapters];
Readonly::Scalar our $GENOTYPES_DIR      => q[genotypes];
Readonly::Scalar our $BAITS_DIR          => q[baits];
Readonly::Scalar our $GBS_PLEX_DIR       => q[gbs_plex];
Readonly::Scalar our $GENO_REFSET_DIR    => q[geno_refset];
Readonly::Scalar our $PRIMER_PANEL_DIR   => q[primer_panel];
Readonly::Scalar our $TAG_SETS_DIR       => q[tag_sets];
Readonly::Scalar our $TAXON_IDS_DIR      => q[taxon_ids];
Readonly::Scalar our $BIN_DIR            => q[bin];
Readonly::Scalar our $ORG_NAME_DELIM     => q[_];

Readonly::Scalar our $LAST             => -1;
Readonly::Scalar our $SECOND_FROM_END  => -2;
Readonly::Scalar our $THIRD_FROM_END   => -3;

Readonly::Scalar our $REPORT_DELIM       => q[,];
Readonly::Scalar our $REPORT_LIST_DELIM  => q[;];

Readonly::Scalar our $NO_ALIGNMENT_OPTION  => q[Not suitable for alignment];

subtype 'NPG_TRACKING_REFERENCE_REPOSITORY'
      => as Str
      => where { -d $_ };

=head2 repository

An absolute path to the repository.

=cut
has 'repository' => (isa       => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                     is        => 'ro',
                     required  => 0,
                     default   => $REP_ROOT,
);

=head2 ref_repository

An absolute path to the reference repository.

=cut
has 'ref_repository' => (isa         => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                         is          => 'ro',
                         required    => 0,
                         lazy_build  => 1,
);
sub _build_ref_repository {
    my $self = shift;
    return catdir($self->repository, $REFERENCES_DIR);
}

=head2 metaref_repository

An absolute path to the repository for meta references.

=cut
has 'metaref_repository' => (isa     => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                             is          => 'ro',
                             required    => 0,
                             lazy_build  => 1,
);
sub _build_metaref_repository {
    my $self = shift;
    return catdir($self->repository, $META_REFERENCES_DIR);
}

=head2 snv repository

An absolute path to the snv repository.

=cut
has 'snv_repository' => (isa        => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                         is         => 'ro',
                         required   => 0,
                         lazy_build => 1,
);
sub _build_snv_repository {
    my $self = shift;
    return catdir($self->repository, $SNV_DIR);
}

=head2 transcriptomes repository

An absolute path to the transcriptomes repository.

=cut
has 'transcriptome_repository' => (isa        => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                                   is         => 'ro',
                                   required   => 0,
                                   lazy_build => 1,
);
sub _build_transcriptome_repository{
    my $self = shift;
    return catdir($self->repository, $TRANSCRIPTOMES_DIR);
}

=head2 repository name

=cut
has '_ref_repository_name' => (isa        => 'Str',
                               is         => 'ro',
                               required   => 0,
                               lazy_build => 1,
);
sub _build__ref_repository_name {
    my $self = shift;
    my @rep_dirs = splitdir(abs_path($self->ref_repository));
    return $rep_dirs[$LAST];
}

=head2 bait_repository

=cut
has 'bait_repository' => (isa        => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                          is         => 'ro',
                          required   => 0,
                          lazy_build => 1,
);
sub _build_bait_repository {
    my $self = shift;
    return catdir($self->repository, $BAITS_DIR);
}

=head2 gbs_plex_repository

=cut
has 'gbs_plex_repository' => (isa        => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                              is         => 'ro',
                              required   => 0,
                              lazy_build => 1,
);
sub _build_gbs_plex_repository {
    my $self = shift;
    return catdir($self->repository, $GBS_PLEX_DIR);
}


=head2 geno_refset_repository

=cut
has 'geno_refset_repository' => (isa        => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                                 is         => 'ro',
                                 required   => 0,
                                 lazy_build => 1,
);
sub _build_geno_refset_repository {
    my $self = shift;
    return catdir($self->repository, $GENO_REFSET_DIR);
}


=head2 primer_panel_repository

=cut
has 'primer_panel_repository' => (isa        => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                                  is         => 'ro',
                                  required   => 0,
                                  lazy_build => 1,
);
sub _build_primer_panel_repository {
    my $self = shift;
    return catdir($self->repository, $PRIMER_PANEL_DIR);
}


=head2 tag_sets_repository

=cut
has 'tag_sets_repository' => (isa        => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                              is         => 'ro',
                              required   => 0,
                              lazy_build => 1,
);
sub _build_tag_sets_repository {
    my $self = shift;
    return catdir($self->repository, $TAG_SETS_DIR);
}

=head2 adapter_repository

An absolute path to the adapter repository.

=cut
has 'adapter_repository' => (isa        => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                             is         => 'ro',
                             required   => 0,
                             lazy_build => 1,
);
sub _build_adapter_repository {
    my $self = shift;
    return catdir($self->repository, $ADAPTERS_DIR);
}

=head2 genotypes_repository

An absolute path to the current (Sequenom) genotypes repository.

=cut
has 'genotypes_repository' => (isa        => 'NPG_TRACKING_REFERENCE_REPOSITORY',
                               is         => 'ro',
                               required   => 0,
                               lazy_build => 1,
);
sub _build_genotypes_repository {
    my $self = shift;
    return catdir($self->repository, $GENOTYPES_DIR);
}

=head2 organism_name_delim

The delimiter used for the organism name.

=cut
has 'organism_name_delim' => (isa       => 'Str',
                              is        => 'ro',
                              required  => 0,
                              default   => $ORG_NAME_DELIM,
);

=head2 taxons_dir

A path to the directory with taxon ids, relative to the reference repository.

=cut
has 'taxons_dir' => (isa       => 'Str',
                     is        => 'ro',
                     required  => 0,
                     default   => $TAXON_IDS_DIR,
);

=head2 all_species

A boolean flag. If set to true (default), all species will be considered.
If set to false, species listed by the optional_species attribute are skipped

=cut
has 'all_species' => (isa       => 'Bool',
                      is        => 'ro',
                      required  => 0,
                      default   => 1,
);

=head2 optional_species

An reference to an array of species whose names will be skipped
in the organisms list. NPD_Chimera is skipped by default.

=cut
has 'optional_species' => (isa       => 'ArrayRef',
                           is        => 'ro',
                           required  => 0,
                           default   => sub {[qw/ NPD_Chimera /]},
);

=head2 organisms

A reference to a list of organisms whose references are available.

=cut
has 'organisms'        => (isa           => 'ArrayRef',
                           is            => 'ro',
                           lazy_build    => 1,
                           required      => 0,
);
sub _build_organisms {
    my $self = shift;

    opendir my $dh, $self->ref_repository or croak q[Cannot get listing on the known organisms, cannot open ] . $self->ref_repository;
    my @listing = readdir $dh;
    closedir $dh or carp q[Cannot close a dir handle];

    if (@listing == 0) {
        croak q[Empty listing for directory ] . $self->ref_repository;
    }
    @listing = grep { !/^[.]/smx } @listing;

    my @orgs = ();
    my $delim = $self->organism_name_delim;
    foreach my $item ( @listing ) {
        ##no critic (BuiltinFunctions::ProhibitBooleanGrep)
        if ($item eq $self->taxons_dir || $item eq $BIN_DIR ||
              (!$self->all_species && grep { /^$item$/smx } @{$self->optional_species})) {
            next;
        }
        ##use critic
        if (-d catfile($self->ref_repository, $item)) {
            push @orgs, $item;
        }
    }

    if (@orgs == 0) {
        croak q[Empty listing for directory (not counting upward links) ] . $self->ref_repository;
    }
    return \@orgs;
}


=head2 repository_contents

A reference to a hash representing the contents of the reference repository.
Maps species::strain/version pairs to further information, such as whether this pair
is currently a default reference for a species, what taxon ids point to this
reference, and what synonyms are available for species names.

=cut
has 'repository_contents' =>  (isa           => 'HashRef',
                               is            => 'ro',
                               lazy_build    => 1,
                               required      => 0,
);
sub _build_repository_contents {
    my $self = shift;

    my $dir = catfile($self->ref_repository, $self->taxons_dir);
    opendir my $dh, $dir or croak q[Cannot get listing of known taxons, cannot open ] . $dir;
    my @listing = readdir $dh;
    closedir $dh or carp q[Cannot close a dir handle];
    if (@listing == 0) {croak qq[Empty listing for taxons $dir];}
    @listing = grep { !/^[.]/smx } @listing;

    my $rep_name = $self->_ref_repository_name;

    my $known = {};

    foreach my $taxon_id ( @listing ) {
        if ($taxon_id !~ /^\d+$/smx) {
            croak qq[Wrong entry in the taxons directory: $taxon_id];
        }
        my $path = catfile(abs_path($self->ref_repository), $self->taxons_dir, $taxon_id);
        my $target = abs_path($path);
        if ($path eq $target) {
            croak qq[Taxon link $path does not point anywhere];
        }

        my $description = $self->taxonid2species($taxon_id);
        my $key = $description->{species} . q[:];
        if (!exists $description->{strain}) {
            my $default_strain_path = catfile($self->ref_repository, $description->{species}, q[default]);
            if (!-e $default_strain_path) {
                croak qq[Taxon id $taxon_id: no default strain link in ] .  catfile($self->ref_repository, $description->{species});
            }
            my @default_strain_dirs = splitdir(abs_path($default_strain_path));
            $key .= $default_strain_dirs[$LAST];
        } else {
            $key .= $description->{strain};
        }

        if (exists $known->{$key}->{taxon_id}) {
            push @{$known->{$key}->{taxon_id}}, $taxon_id
        } else {
            $known->{$key}->{taxon_id} = [$taxon_id];
        }
    }

    my @synonyms = ();
    foreach my $sp (@{$self->organisms}) {
        my $sdir = catfile($self->ref_repository, $sp);
        if (-l $sdir) {
            push @synonyms, $sdir;
            next;
        }
        opendir my $dh, $sdir or croak q[Cannot get listing for a directory, cannot open ] . $sdir;
        my @slisting = readdir $dh;
        closedir $dh or carp q[Cannot close a dir handle];
        @slisting = grep { !/^[.]/smx } @slisting;

        my $default = catfile($self->ref_repository, $sp, q[default]);
        my $default_strain;
        if (-e $default) {
            my @default_strain_dirs = splitdir(abs_path($default));
            $default_strain = $default_strain_dirs[$LAST];
        } else {
            croak qq[No default strain link for $sp];
        }

        foreach my $strain ( @slisting ) {
            if (-d catfile($sdir,$strain) && !(-l catfile($sdir,$strain))) {
                my $key = join q[:], $sp, $strain;
                $known->{$key}->{default} =  ($strain eq $default_strain) ? 1 : 0;
            }
        }
    }

    my @keys = keys %{$known};

    foreach my $synonym (@synonyms) {
        my @dirs = splitdir(abs_path($synonym));
        my $species = $dirs[$LAST] . q[:];
        my @strains = grep { /^$species/smx } @keys;
        if (!@strains) {
            croak qq[Soft link $synonym does not point to a species folder];
        }
        @dirs = splitdir($synonym);
        foreach my $strain (@strains) {
            if ($known->{$strain}->{default}) {
                if (exists $known->{$strain}->{synonyms}) {
                    push @{$known->{$strain}->{synonyms}}, $dirs[$LAST]
                } else {
                    $known->{$strain}->{synonyms} = [$dirs[$LAST]];
                }
            }
        }
    }

    return $known;
}

=head2 bait_repository_contents

=cut
has 'bait_repository_contents' =>  (isa           => 'HashRef',
                                    is            => 'ro',
                                    lazy_build    => 1,
                                    required      => 0,
);
sub _build_bait_repository_contents {
    my $self = shift;
    my $baits = {};

    my $rep = $self->bait_repository;
    opendir my $dh, $rep or croak qq[Cannot open directory $rep];
    my @baits = grep { !/^[.]/smx && -d "$rep/$_" } readdir $dh;
    closedir $dh or carp qq[Problem closing a handle to $rep];

    foreach my $bait_name (@baits) {
        my $dir = catdir($rep, $bait_name);
        opendir my $bdh, $dir or croak qq[Cannot open directory $dir];
        my @refs = grep { !/^[.]/smx && -d "$dir/$_" } readdir $bdh;
        closedir $bdh or carp qq[Problem closing a handle to $dir];
        @refs = sort @refs;
        $baits->{$bait_name} = \@refs;
    }
    return $baits;
}

=head2 bait_report

A string representing a report on baits repository, baits grouped by bait name.

=cut
sub bait_report {
    my $self = shift;

    my $report = qq[Bait Name\tReferences\n];
    foreach my $bait_name (sort keys %{$self->bait_repository_contents}) {
        $report .= $bait_name . qq[\t] . join(q[ ], @{$self->bait_repository_contents->{$bait_name}}) . qq[\n];
    }
    return $report;
}

=head2 bait_report_by_reference

A string representing a report on baits repository, baits grouped by reference.

=cut
sub bait_report_by_reference {
    my $self = shift;

    my $refs = {};
    foreach my $bait_name (keys %{$self->bait_repository_contents}) {
        foreach my $ref (@{$self->bait_repository_contents->{$bait_name}}) {
            push @{$refs->{$ref}}, $bait_name;
        }
    }

    my $report = qq[Reference\tBait Names\n];
    foreach my $ref (sort keys %{$refs}) {
        $report .= $ref . qq[\t] . join(q[ ], @{$refs->{$ref}}) . qq[\n];
    }
    return $report;
}

=head2 report

Creates a full CSV report about the contents of the reference repository.
Returns a string representation of the report and, if a file name is supplied
as an argument, writes the report to this file.

=cut
sub report {
    my ($self, $filename) = @_;

    my $list = join $REPORT_DELIM, ('Species:Strain', 'Is Default?', 'Taxon Ids', 'Synonyms');
    $list .= "\n";

    my $report = $self->repository_contents;

    foreach my $key (sort keys %{$report}) {
        $list .= $key . $REPORT_DELIM . $report->{$key}->{default} . $REPORT_DELIM;
        if (exists $report->{$key}->{taxon_id}) {
            my $count = 0;
            foreach my $taxon (sort @{$report->{$key}->{taxon_id}}) {
                if ($count > 0) {$list .= $REPORT_LIST_DELIM;}
                $list .= $taxon;
                $count++;
            }
        }
        $list .= $REPORT_DELIM;
        if (exists $report->{$key}->{synonyms}) {
            my $count = 0;
            foreach my $synonym (sort @{$report->{$key}->{synonyms}}) {
                if ($count > 0) {$list .= $REPORT_LIST_DELIM;}
                $list .= $synonym;
                $count++;
            }
        }
        $list .= "\n";
    }

    if ($filename) {
        open my $fh, q[>], $filename or croak qq[Cannot open file $filename for writing.];
        if ($fh) {
            print {$fh} $list or croak qq[Cannot print to $filename];
            close $fh or croak qq[Cannot close $filename];
        }
    }

    return $list;
}


=head2 short_report

Returns a string representation of a short report.

=cut
sub short_report {
    my $self = shift;

    my @list = ();
    foreach my $key (sort keys %{$self->repository_contents}) {
        my @two = split /:/smx, $key;
        push @list, $two[0] . q[ (] . $two[1] . q[)];
    }
    push @list, $NO_ALIGNMENT_OPTION;
    return join("\n", @list) . "\n";
}

=head2 taxonid2species

Matches taxon id to a species and, optionally, a strain.
Returns a reference to a hash with species and, optionally, strain keys.

=cut
sub taxonid2species {
    my ($self, $id) = @_;

    my $path =  catfile($self->ref_repository, $self->taxons_dir, $id);
    my $description = {};
    if (-e $path) {
        my @dirs = splitdir(abs_path($path));
        if ($dirs[$SECOND_FROM_END] eq $self->_ref_repository_name) {
            $description->{species} = $dirs[$LAST];
        } elsif  ($dirs[$THIRD_FROM_END] eq $self->_ref_repository_name) {
            $description->{species} = $dirs[$SECOND_FROM_END];
            $description->{strain} = $dirs[$LAST];
        } else {
            croak qq[wrong taxon link $path];
        }
    }
    return $description;
}

=head2 ref_file_prefix

Returns a prefix for the names of reference binary indices.

=cut
sub ref_file_prefix {
    my ($self, $tools_dir) = @_;
    # read the fasta directory and get the file name with the reference
    my $fasta_dir = catfile($tools_dir, q[fasta]);
    opendir my $dh, $fasta_dir or croak $ERRNO;
    my @files = readdir $dh;
    closedir $dh or croak $ERRNO;

    for my $file (@files) {
        if ( $file =~ /[.]f (?: n | ast )? a$/ismx ) {
            # add the directory separator at the end of the aligner directory path
            # and then append the reference file name, which is the prefix of the
            # binary reference file - that is our convention
            return $file;
        }
    }
    croak qq[Reference file with .fa or .fasta or .fna extension not found in $fasta_dir];
}

no Moose::Role;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Moose::Util::TypeConstraints

=item Carp

=item English

=item File::Spec::Functions

=item Readonly

=item File::Basename

=item Cwd

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013,2014,2015,2018,2020,2021 Genome Research Ltd.

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
