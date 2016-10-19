#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::api::base;
use base qw(Class::Accessor);
use strict;
use warnings;
use Carp;
use npg::api::util;
use Lingua::EN::Inflect qw(PL);
use English qw(-no_match_vars);

our $VERSION = '0';

sub new {
  my ($class, $ref) = @_;
  $ref ||= {};
  bless $ref, $class;
  $ref->init();
  return $ref;
}

sub new_from_xml {
  my ($self, $pkg, $xmlfrag, $util) = @_;
  my $obj = $pkg->new();

  if(ref $self && !$util) {
    $obj->util($self->util());
  }

  if($util) {
    $obj->util($util);
  }

  if($xmlfrag) {
    for my $f ($obj->fields()) {
      $obj->{$f} = $xmlfrag->getAttribute($f);
    }
  }

  for my $pk ($self->primary_key, $obj->primary_key) {
    if(!$obj->{$pk}) {
      eval {
      $obj->$pk($self->{$pk});
      1;
      } or do {
    # ignore
      };
    }
  }

  return $obj;
}

sub hasa {
  my ($class, $attr) = @_;
  no strict 'refs'; ## no critic (ProhibitNoStrict)

  if(ref $attr ne 'ARRAY') {
    $attr = [$attr];
  }

  for my $single (@{$attr}) {
    my $pkg = $single;
    if(ref $single eq 'HASH') {
      ($pkg)    = values %{$single};
      ($single) = keys %{$single};
    }
    my $namespace = "${class}::$single";
    if (defined &{$namespace}) {
      next;
    }

    *{$namespace} = sub {
      my $self = shift;
      my $el   = $self->read->getElementsByTagName($single)->[0];
      return $self->new_from_xml("npg::api::$pkg", $el);
    };
  }

  return;
}

sub hasmany {
  my ($class, $attr) = @_;
  no strict 'refs'; ## no critic (ProhibitNoStrict)

  if(ref $attr ne 'ARRAY') {
    $attr = [$attr];
  }

  for my $single (@{$attr}) {
    my $pkg    = $single;

    if(ref $single eq 'HASH') {
      ($pkg)    = values %{$single};
      ($single) = keys %{$single};
    }

    my $plural    = PL($single);
    my $namespace = "${class}::$plural";

    if (defined &{$namespace}) {
      next;
    }
#carp qq(Making $namespace for $class consuming <$plural/$single> and yielding npg::api::$pkg);
    *{$namespace} = sub {
      my $self = shift;
      my $el   = $self->read->getElementsByTagName($plural)->[0];

      return [map { $self->new_from_xml("npg::api::$pkg", $_); }
              $el->getElementsByTagName($single)];

    };
  }

  return;
}

sub init {}

sub util {
  my ($self, $util) = @_;
  if($util) {
    $self->{util} = $util;
  }

  if(!$self->{util}) {
    $self->{util} = npg::api::util->new();
  }

  return $self->{util};
}

sub flush {
  my $self = shift;

  for my $field (qw(read_dom)) {
    delete $self->{$field};
  }

  return;
}

sub get {
  my ($self, $field) = @_;

  if(!exists $self->{$field}) {
    $self->read();
  }

  return $self->SUPER::get($field);
}

sub fields {
  return qw();
}

sub large_fields {
  return qw();
}

sub primary_key {
  my $self = shift;
  return ($self->fields())[0];
}

sub list {
  my ($self, $filters) = @_;
  my $util       = $self->util();
  my ($obj_type) = (ref $self) =~ /([^:]+)$/smx;
  my $obj_uri    = sprintf '%s/%s', $util->base_uri(), $obj_type;

  if($filters) {
    $obj_uri .= $filters;
  }
  return $util->parser->parse_string($util->get($obj_uri, []));
}

sub read { ## no critic (ProhibitBuiltinHomonyms)
  my $self = shift;

  if(!$self->{read_dom}) {
    my $util       = $self->util();
    my ($obj_type) = (ref $self) =~ /([^:]+)$/smx;
    my $obj_pk     = $self->primary_key();
    my $obj_pk_val = $self->{$obj_pk};

    if ($obj_type eq 'user') {
      $obj_pk_val = $self->username();
    }

    if(!defined $obj_pk_val) {
      return;
    }

    my $obj_uri  = sprintf '%s/%s/%s', $util->base_uri(), $obj_type, $obj_pk_val;
    my $content = $util->get($obj_uri, []);
    eval {
      $self->{read_dom} = $util->parser->parse_string($content);
    } or do {
      $self->{read_dom} = $util->parser->parse_string(q{<?xml version="1.0" encoding="utf-8"?><error>There was an error</error>});
    };

    my $root = $self->{read_dom}->getDocumentElement();

    for my $field ($self->fields()) {
      $self->{$field} ||= $root->getAttribute($field);
    }
  }

  return $self->{read_dom};
}

1;
__END__

=head1 NAME

npg::api::base

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::api::<pkg>->fields();

=head2 large_fields - accessors for large/lazy fields

  my @largeFields = $oPkg->large_fields();

=head2 primary_key - the first element from fields() unless overridden

  my $sPrimaryField = $oDerived->primary_key();

=head2 new - constructor

  my $oDerived = npg::api::<derived>->new();

  my $oDerived = npg::api::<derived>->new({'util' => $oUtil,});

  my $oDerived = npg::api::<derived>->new({
    # 'key' => value parameters for the derived class
  });

=head2 init - post-constructor initialization. Called by new();

  Useful for performing additional initialization on construction for subclasses.

  $oDerived->init();

=head2 new_from_xml - create and populate an npg::api::* from a XML::LibXML::Element

  my $oObj = $oDerived->new_from_xml('npg::api::<package>', $oXMLElement);

=head2 hasa - makes one:one accessors on compilation

 package npg::api::<base-subclass>;
 use strict;
 use warnings;

 __PACKAGE__->hasa(['child1', 'child2', {'current_child3' => 'child3-package'}]);

=head2 hasmany - makes one:many accessors on compilation

 package npg::api::<base-subclass>;
 use strict;
 use warnings;

 __PACKAGE__->hasmany(['child1', 'child2', {'current_child3' => 'child3-package'}]);

=head2 flush - wipe DOM cache

  $oDerived->flush();

=head2 get - overridden get accessor from Class::Accessor

Fetches XML over HTTP based on self->util->base_uri().

=head2 util - util instance for this resource set

  Returns a cached object if one exists, or creates and caches a new one

  my $oUtil = $oDerived->util();

=head2 list - default handling for reading lists of objects

  my $oDOM = $oDerived->list();

=head2 read - default handling for reading individual objects

  my $oDOM = $oDerived->read();

=head2 retry - method retries connecting to ST before croaking with an error

=head2 max_retries - maximum number of retried LWP fetches to attempt

=head2 retry_delay - delay, in seconds, between retried LWP fetches

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item Class::Accessor

=item strict

=item warnings

=item Carp

=item npg::api::util

=item Lingua::EN::Inflect

=item English

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett

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
