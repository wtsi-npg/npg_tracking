package npg_tracking::glossary::composition::serializable;

use Moose::Role;
use JSON::XS;
use namespace::autoclean;
use Digest::SHA qw/sha256_hex/;
use Digest::MD5 qw/md5_hex/;
use Carp;

requires 'pack';
requires 'unpack';

our $VERSION = '0';

sub thaw {
  my ( $class, $json, @args ) = @_;
  if (!$json) {
    croak 'JSON string is required';
  }
  return $class->unpack( JSON::XS->new()->decode($json), @args );
}

sub freeze {
  my $self = shift;
  if ( $self->can('sort') ) {
    $self->sort();
  }
  return JSON::XS->new()->canonical(1)->encode( $self->_pack_custom() );
}

sub digest {
  my ($self, $digest_type) = @_;
  my $data = $self->freeze();
  return ($digest_type && $digest_type eq 'md5') ?
          md5_hex $data : sha256_hex $data;
}

sub _pack_custom {
  my $self = shift;
  return _clean_pack($self->pack());
}

sub _clean_pack { # Recursive function
  my $old = shift;

  my $type = ref $old;
  if (!$type || $type ne 'HASH') {
    return $old;
  }

  my $values = {};
  while ( my ($k, $v) = each %{$old} ) {
     # Delete __CLASS__ key along with private attrs
    if (defined $v && $k !~ /\A_/smx) {
      # Treat components the same way
      if (ref $v && ref $v eq 'ARRAY' && $k eq 'components') {
        my @clean = map { _clean_pack($_) } @{$v};
        $v = \@clean;
      }
      $values->{$k} = $v;
    }
  }

  return $values;
}

no Moose::Role;

1;
__END__

=head1 NAME

npg_tracking::glossary::composition::serializable

=head1 SYNOPSIS

  package my::package;

  use Moose;
  use namespace::autoclean;
  use MooseX::Storage;

  with Storage( 
    'traits' => ['OnlyWhenBuilt'],
    'format' => '=npg_tracking::glossary::composition::serializable' );
  
  has 'attr_a'  => (isa => 'Str');
  has 'attr_b'  => (isa => 'Int');
  has '_attr_c' => (isa => 'Int', default => 3,);

  __PACKAGE__->meta->make_immutable;

  1;

  package main;
  use my::package;
  
  my $p = my::package->new(attr_a => 'a', attr_b => 2);
  my json = $p->freeze();
  print $json; # prints {"attr_a":"a","attr_b":2}
               # note the absence of both the __CLASS__ key
               # and private attributes
  my $p1 = my::package->thaw($json);

=head1 DESCRIPTION

Custom JSON serialization format for MooseX::Storage framework.
Differences with MooseX::Storage::Format::JSON:
  - uses JSON::XS directly,
  - private attributes are not serialized,
  - the output does not contain the __CLASS__ key,
  - the above applies recursively to an array reference attribute called
    'components'.

=head1 SUBROUTINES/METHODS

=head2 thaw

Instantiates an object from a json string.

  my $p = my::package->thaw($json);

=head2 freeze

Serializes object's public attributes to a canonical (ordered) json string.

  $p->freeze();

=head2 digest

Returns a digest of the JSON serialization string.

  $p->digest();      # sha256_hex digest
  $p->digest('md5'); # md5 digest

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item JSON::XS

=item namespace::autoclean

=item Digest::SHA

=item Digest::MD5

=item Carp

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
