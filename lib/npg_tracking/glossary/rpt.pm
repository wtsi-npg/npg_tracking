package npg_tracking::glossary::rpt;

use Moose::Role;
use Carp;
use Readonly;

our $VERSION = '0';

Readonly::Scalar my $RPT_KEY_DELIM  => q[:];
Readonly::Scalar my $RPT_LIST_DELIM => q[;];

=head1 NAME

npg_tracking::glossary::rpt

=head1 SYNOPSIS

Inherit from this role:

  package my::obj;
  use Moose;
  with 'npg_tracking::glossary::rpt';
  
  # later in the class
  my $h = $self->inflate_rpt('5:7:8');

Alternatively, use this role as a module:

  package my::obj;
  use npg_tracking::glossary::rpt;

  my $h = npg_tracking::glossary::rpt->inflate_rpt('5:7:8');
  
=head1 DESCRIPTION

Moose role providing conversion methods between different
rpt (run position tag) representation. All methods can be
invoked as class-level methods.

=head1 SUBROUTINES/METHODS

=head2 inflate_rpt

Parses input rpt string and returns a hash reference containing id_run,
position and, possibly, tag_index as keys.

  my $h = __PACKAGE__->inflate_rpt('5:7:8');
  print $h->{'id_run'}; #prints 5
  print $h->{'position'}; #prints 7
  print $h->{'tag_index'}; #prints 8

=cut
sub inflate_rpt {
  my ($self, $s) = @_;

  if (!$s) {
    croak 'rpt string argument is missing';
  }
  if ($s =~ $RPT_LIST_DELIM) {
    croak qq[rpt string should not contain '$RPT_LIST_DELIM'];
  }

  my @values = split /$RPT_KEY_DELIM/smx, $s;
  my $map = {};
  foreach my $key (qw(id_run position tag_index)) {
    my $v = shift @values;
    if (defined $v) {

      # The value is a string at this point, which does not cause any
      # visible problems downstream. However, if the resulting hash
      # is used in a database query, the query will run twice slower
      # (tested on MySQL v5.7) since DBIx does not cast the values
      # before sending them to a database. We will convert to int here.
      {
        # We want an error if casting did not go well.
        # The scope for this fatal warning is constrained.
        use warnings FATAL => qw(numeric);
        $map->{$key} = int $v;
      }
    }
  }

  if (!$map->{'id_run'} || !$map->{'position'}) {
    croak 'Both id_run and position should be defined non-zero values';
  }

  return $map;
}

=head2 deflate_rpt

Converts a hash or object rtp representation to string.
If no argument is supplied, assumes that the object
itself is a source of data.

  $obj->id_run(2);
  $obj->position(3);
  $obj->deflate_rpt(); #returns 2:3

  $obj1->id_run(4);
  $obj1->position(5);
  $obj->deflate_rpt($obj1); #returns 4:5

  $obj->deflate_rpt({id_run=>7,position=>8,tag_index=>0}); #returns 7:8:0
  __PACKAGE__->deflate_rpt(
    {id_run=>7,position=>8,tag_index=>0}); #returns 7:8:0

It is expected that the object/hash that is being serialized has at least
id_run and position accessors/keys.

=cut
sub deflate_rpt {
  my ($self, $rpt) = @_;

  if (!$rpt) {
    $rpt = $self;
  }
  if (!ref $rpt) {
    croak 'Hash or object input expected';
  }

  my $h = {};

  for my $attr (qw/id_run position tag_index/) {
    if (ref $rpt eq 'HASH') {
      $h->{$attr} = $rpt->{$attr};
    } else {
      if ($rpt->can($attr)) {
        $h->{$attr} = $rpt->$attr;
      }
    }
  }

  if (!$h->{'id_run'} || !$h->{'position'}) {
    croak 'Either id_run or position key is undefined';
  }

  my @rpt_components = ($h->{'id_run'}, $h->{'position'});
  if (defined $h->{'tag_index'}) {
    push @rpt_components, $h->{'tag_index'};
  }

  return join $RPT_KEY_DELIM, @rpt_components;
}

=head2 split_rpts

Treats an input string as representing a sequence of delimitered rpt strings.
Returns an array of string rpt representations.

  my $array = __PACKAGE__->split_rpts('1:2;1:2:5');

=cut
sub split_rpts {
  my ($self, $s) = @_;
  if (!$s) {
    croak 'rpt list string is not given';
  }
  return [split /$RPT_LIST_DELIM/smx, $s];
}

=head2 join_rpts

Converts a list of string rpt representations to a string
representation of an rpt list.

  my $array = __PACKAGE__->join_rpts(['1:2','1:2:5']);

=cut
sub join_rpts {
  my ($self, @rpts) = @_;

  return join $RPT_LIST_DELIM, @rpts;
}

=head2 inflate_rpts

Treats an input string as representing a sequence of delimitered rpt strings.
Returns an array of hash rpt representations.

  my $array = __PACKAGE__->inflate_rpts('1:2;1:2:5');

=cut
sub inflate_rpts {
  my ($self, $s) = @_;
  return [map { $self->inflate_rpt($_) } @{$self->split_rpts($s)}];
}

=head2 deflate_rpts

Converts a list of hash rpt representations to a string.

  my $s = __PACKAGE__->deflate_rpts(
    [{id_run=>1,position=>2}, {id_run=>1,position=>2,tag_index=>5}]);
  print $s; # 1:2;1:2:5 

=cut
sub deflate_rpts {
  my ($self, $rpts) = @_;

  if (!$rpts) {
    croak 'rpts array is missing';
  }
  if (! ref $rpts || ref $rpts ne 'ARRAY') {
    croak 'Array input expected';
  }
  return __PACKAGE__->join_rpts(map { $self->deflate_rpt($_) } @{$rpts});
}

=head2 tag_zero_rpt_list

Converts the argument rpt_list into an rpt_list for tag zero components

  my $s = __PACKAGE__->tag_zero_rpt_list('1:2:3;1:3:3');
  print $s; # 1:2:0;1:3:0

  $s = __PACKAGE__->tag_zero_rpt_list('1:2;1:3');
  print $s; # 1:2:0;1:3:0

  $s = __PACKAGE__->tag_zero_rpt_list('1:2;1:2:6');
  print $s; # 1:2:0;1:2:0 - Be warned!

=cut
sub tag_zero_rpt_list {
  my ($self, $rpt_list) = @_;
  ##no critic (BuiltinFunctions::ProhibitComplexMappings)
  return __PACKAGE__->join_rpts(map { __PACKAGE__->deflate_rpt($_) }
                                map { $_->{'tag_index'} = 0; $_ }
                                @{__PACKAGE__->inflate_rpts($rpt_list)} );
}

no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

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

