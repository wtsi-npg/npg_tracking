package npg_tracking::glossary::moniker;

use Moose::Role;
use Carp;
use Readonly;
use File::Spec;
use List::MoreUtils qw/none/;
use List::Util qw/uniq/;

use npg_tracking::glossary::tag;

requires 'composition';

our $VERSION = '0';

Readonly::Scalar my $DELIM       => q[_];
Readonly::Scalar my $LANE_DELIM  => q[-];
Readonly::Scalar my $NOT_COMMON  => q[-1];
Readonly::Scalar my $SUFFIX_KEY  => q[suffix];
Readonly::Scalar my $EXT_KEY     => q[ext];

sub file_name {
  my ($self, $selected_lanes) = @_;

  my $name;
  if ($self->_file_name_semantic()) {
    $name = sprintf '%i%s%s%s',
      $self->_id_run_common(),
      $self->_position_label($DELIM, $selected_lanes),
      $self->_tag_index_label($npg_tracking::glossary::tag::TAG_DELIM),
      $self->_subset_label();
  } else {
    $name = $self->generic_name();
  }

  return $name;
}

sub file_name_full {
  my ($self, $name, @options) = @_;

  $name or croak 'File name base should be given';

  if (@options) {

    if (scalar @options % 2 != 0) {
      croak 'The argument list should contain a file name'.
            ' and, optionally, a list of key-value options';
    }

    my %h = @options; # Safe, we know that we have an even number
                      # of list members.

    if (exists $h{$SUFFIX_KEY} && $h{$SUFFIX_KEY} ne q[]) {
      $name .= q[_] . $h{$SUFFIX_KEY};
      delete $h{$SUFFIX_KEY};
    }
    if (exists $h{$EXT_KEY} && $h{$EXT_KEY} ne q[]) {
      $name .= q[.] . $h{$EXT_KEY};
      delete  $h{$EXT_KEY};
    }

    if (keys %h) {
      croak sprintf 'The following options are not recognised: %s. Accepted options: %s, %s.',
                    join(q[, ], sort keys %h),
                    $SUFFIX_KEY,
                    $EXT_KEY;
    }
  }
  return $name;
}

sub dir_path {
  my ($self, $selected_lanes) = @_;

  my @names = ();
  if ($self->_dir_path_semantic()) {
    @names = grep {$_} ($self->_position_label('lane', $selected_lanes),
                        $self->_tag_index_label('plex'));
  } else {
    push @names, $self->generic_name();
  }

  return File::Spec->catdir(@names);
}

sub generic_name {
  my $self = shift;
  return $self->composition()->digest();
}

sub parse_file_name {
  my ($self, $name) = @_;

  $name or croak 'File name argument required';

  my $parsed = {};
  ##no critic (RegularExpressions::RequireExtendedFormatting)
  if ( $name =~ /\A(\d+)(?:_(\d))?(?:#(\d+))?(?:_(\w+))?(?:[.](\S+))?\Z/sm ) {
  ##use critic
    $parsed->{'id_run'}    = $1;
    $parsed->{'position'}  = $2;
    $parsed->{'tag_index'} = $3;
    $parsed->{'suffix'}    = $4;
    $parsed->{'extension'} = $5;

    ( $parsed->{'id_run'} and
      ( $parsed->{'position'} or defined $parsed->{'tag_index'} ) ) or
      $parsed = {};
  }

  (keys %{$parsed}) or croak
    "Argument file name $name does not conform to expected pattern";

  for my $k (keys %{$parsed}) {
    defined $parsed->{$k} or delete $parsed->{$k};
  }

  return $parsed;
}

has [qw/_id_run_common _tag_index_common/] => (
  metaclass  => 'DoNotSerialize',
  isa        => 'Maybe[Int]',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);

has '_subset_common' => (
  metaclass  => 'DoNotSerialize',
  isa        => 'Maybe[Str]',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);

for my $attr (qw/id_run tag_index subset/) {
  __PACKAGE__->meta()->add_method('_build_' . _attr_name($attr), sub {
    my $self = shift;
    return _get_common($self->composition(), $attr);
  });
}

has [qw/_file_name_semantic _dir_path_semantic/] => (
  metaclass  => 'DoNotSerialize',
  isa        => 'Bool',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);
sub _build__file_name_semantic {
  my $self = shift;
  return $self->_is_semantic(qw/id_run tag_index subset/);
}
sub _build__dir_path_semantic {
  my $self = shift;
  return $self->_is_semantic(qw/id_run tag_index/);
}

sub _attr_name {
  my $attr = shift;
  return join q[_], q[], $attr, 'common';
}

sub _is_semantic {
  my ($self, @attrs) = @_;
  return none { $_ eq $NOT_COMMON }
         grep { defined }
         map  { $self->$_ }
         map  { _attr_name($_) }
         @attrs;
}

sub _get_common {
  my ($composition, $attr_name) = @_;

  my $common = $NOT_COMMON;
  my @distinct = uniq
                 map {$_->$attr_name}
                 $composition->components_list();
  if (@distinct == 1) {
    $common = $distinct[0];
  }

  return $common;
}

sub _subset_label {
  my $self = shift;
  return $self->_subset_common() ? $DELIM . $self->_subset_common() : q[];
}

sub _tag_index_label {
  my ($self, $delim) = @_;
  $delim or croak 'Delimeter argument should be defined';
  return defined $self->_tag_index_common ? $delim . $self->_tag_index_common : q[];
}

sub _position_label {
  my ($self, $prefix, $selected_lanes) = @_;
  $prefix or croak 'Prefix argument should be defined';
  return ($selected_lanes || $self->composition()->num_components() == 1)
         ? $prefix . join $LANE_DELIM, map {$_->position()}
                                       $self->composition()->components_list()
         : q[];
}

no Moose::Role;

1;

__END__

=head1 NAME

npg_tracking::glossary::moniker

=head1 SYNOPSIS

=head1 DESCRIPTION

A Moose role providing factory functionality for file and
directory names for entities which can be described by a composition
(required attribute), see npg_tracking::glossary::composition.

Both file and directory names are deterministic. It is guaranteed
that the same name is returned for a given composition and that names
for different compositions do not clash. It is not always possible
to translate the name back to the composition.

Private attributes defined in this role will not be serialized under
the MooseX::Storage framework.

=head3 Heuristic

In a general case file names are based on the sha256_hex
digest associated with the composition object. In some cases
it is possible to construct human-readable and semantically
meaningful names. For file names, in all such cases the subset
of all components should be either undefined or the same and
all components should belong to the same run. Directories
aggregate files for all subsets of a particular entity,
therefore, the subset value will be disregarded.

=head3 File or directory name for results of an arbitrary merge
(composition)

sha256_hex digest associated with the composition object.
It is not possible to translate this name back to the composition.

=head3 File name for a one-component composition

=over

=item <IDRUN>_<POSITION>

=item <IDRUN>_<POSITION>_<SUBSET>

=item <IDRUN>_<POSITION>#<TAG_INDEX>

=item <IDRUN>_<POSITION>#<TAG_INDEX>_<SUBSET>

=back

B<Examples:> 1937_2, 1937_2#5, 1937_2#5_phix, 1937_3_human

=head3 File name for a composition of components representing the
same sample in each lane of the run

=over

=item <IDRUN>#<TAG_INDEX>

=item <IDRUN>#<TAG_INDEX>_<SUBSET>

=item <IDRUN>

=item <IDRUN>_<SUBSET>

=back

B<Examples:> 2456#4, 2456#4_phix, 2789, 2798_human

It is not possible to tranlate this name back to composition without
knowing the number of lanes for the run (flowcell).

=head3 File name for a composition of components representing the same
sample in some lanes of the run

=over

=item <IDRUN>_<POSITION>[-<POSITION>]#<TAG_INDEX>

=item <IDRUN>_<POSITION>[-<POSITION>]#<TAG_INDEX>_<SUBSET>

=item <IDRUN>_<POSITION>[-<POSITION>]

=item <IDRUN>_<POSITION>[-<POSITION>]_<SUBSET>

=back

B<Examples:> 17899_1-3-4#5, 17899_2-6#5_phix, 17899_7-9, 17899_7-9_human

=head3 Directory path for data from a single lane

=over

=item rpt list <IDRUN>:<POSITION> => lane<POSITION>

=item rpt list <IDRUN>:<POSITION>:<TAG_INDEX> => lane<POSITION>/plex<TAG_INDEX>

=back

B<Examples:> 18456:4 => lane4, 18456:4:89 => lane4/plex89

=head3 Directory path for data for a sample merged across all lanes of a run

=over

=item plex<TAG_INDEX>

=item empty string

=back

B<Examples:> plex132, plex0

=head3 Directory path for data for a sample merged across some lanes of a run

=over

=item lanes<POSITION>-<POSITION>[-<POSITION>]/plex<TAG_INDEX>

=item lanes<POSITION>-<POSITION>[-<POSITION>]

=back

B<Examples:> lane1-2 lane1-3-5/plex77, lane6-7/plex0

=head1 SUBROUTINES/METHODS

=head2 file_name

Returns a file name root for the entity described  by the composition object
returned by the 'composition' attribute.

Optionally takes a boolean argument telling the method whether the composition
represents a sunset of lanes in the run. False by default.

 my $file_name = $self->file_name();
 my $selected_lanes = 0;
 $file_name = $self->file_name($selected_lanes);
 $selected_lanes = 1;
 $file_name = $self->file_name($selected_lanes);

=head2 file_name_full

A package-level or class method.
Adds a suffix and a file extension to an argument filename.

  my $name= q[26219_1#0];
  $p->file_name_full($name);                                         # 26219_1#0
  $p->file_name_full($name, ext => 'bam');                           # 26219_1#0.bam
  $p->file_name_full($name, ext => 'stats', suffix => 'F0xB00');     # 26219_1#0_F0xB00.stats 
  $p->file_name_full($name, ext => 'stats.md5', suffix => 'F0xB00'); # 26219_1#0_F0xB00.stats.md5 

=head2 dir_path

Returns a relative directory path for the entity described by the composition
object returned by the 'composion' attribute. The path might contain one or more
components. This method does not create the path, neither it checks that the
path exists.

Optionally takes a boolean argument telling the method whether the composition
represents a sunset of lanes in the run. False by default.

  my $dir = $self->dir_path();
  my $selected_lanes = 0;
  $dir = $self->dir_path($selected_lanes);
  $selected_lanes = 1;
  $dir = $self->dir_path($selected_lanes);

=head2 generic_name

Returns a generic name for a file or directory, which is based on a sha256_hex
digest associated with the composition object. This type of name is used within
this module when a semantically meaningful name cannot  be generated.

=head2 parse_file_name

A package level method.
Given a file name, returns a hash containing such file components as
run id, position, tag index, suffix and extension (keys used: id_run, position,
tag_index, suffix, extension).
  
  my $parsed = $self->parse_file_name('1234_4#0_phix.cram');
  $parsed = $self->parse_file_name('1234_4#3_phix.cram.crai');

Not all possible components of a file name have to be present. However, 
run id and either position or tag index should be present. File name components
that are not present in the argument file name will not be present in the
returned hash.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item MooseX::Storage::Meta::Attribute::DoNotSerialize

=item Carp

=item Readonly

=item File::Spec

=item List::MoreUtils

=item List::Util

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018,2019,2020 GRL

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
