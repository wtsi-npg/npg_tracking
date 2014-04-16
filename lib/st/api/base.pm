#########
# Author:        rmp
# Created:       2007-03-28
#
package st::api::base;

use base qw(Class::Accessor);
use strict;
use warnings;
use Carp;

use npg::api::util;

our $VERSION = '0';

sub live_url { return q{http://psd-support.internal.sanger.ac.uk:6600}; }

sub dev_url  { return q{http://psd-dev.internal.sanger.ac.uk:6800}; }

sub new {
  my ($class, $ref) = @_;
  $ref ||= {};
  bless $ref, $class;
  return $ref;
}

sub new_from_xml {
  my ($self, $pkg, $xmlfrag, $util) = @_;
  my $obj = $pkg->new(ref $self ? { util      => $self->util(),} : {});

  if($util) {
    $obj->util($util);
  }

  $obj->_init_from_xml_node($xmlfrag);
  return $obj;
}

sub fields {
  return ();
}

sub primary_key {
  my $self = shift;
  return ($self->fields())[0];
}

sub util {
  my ($self, $util) = @_;
  if($util) {
    $self->{util} = $util;
  }
  if (!$self->{util}) {
    $self->{util} = npg::api::util->new();
  }
  return $self->{util};
}

sub get {
  my ($self, $field) = @_;

  $field = lc $field;
  if($self->{$field}) {
    return $self->{$field};
  }
  if($self->{id}) {
    $self->parse();
  }
  return $self->{$field};
}

sub entity_name {
  my $self   = shift;
  my $pkg    = ref $self;
  my ($name) = $pkg =~ /([^:]+)$/smx;
  return $name;
}

sub parse {
  my $self = shift;

  if(!$self->{parsed}) {
    if(!$self->{id}) {
      carp q[Not going to parse - no id given];
      return;
    }

    my $doc = $self->read();
    my $el  = $doc->getElementsByTagName($self->entity_name())->[0];

    if(!$el) {
      return;
    }

    $self->_init_from_xml_node($el);

    $self->{parsed}++;
  }

  return;
}

sub _init_from_xml_node {
    my ($self, $el) = @_;

    my @descriptors = @{$el->getElementsByTagName('descriptor')};
    if (!@descriptors) {@descriptors= @{$el->getElementsByTagName('property')};}

    for my $desc (@descriptors) {
      my $namec;
      eval {
        $namec  = $desc->getElementsByTagName('parameter')->[0]->getFirstChild();
      } or do {
        eval {
          $namec  = $desc->getElementsByTagName('name')->[0]->getFirstChild();
        } or do {
          carp q{unable to obtain name via name or parameter};
        };
      };
      my $name   = $namec?$namec->getData():undef;
      $name = lc $name;
      my $valuec = $desc->getElementsByTagName('value')->[0]->getFirstChild();
      my $value  = $valuec?$valuec->getData():undef;
      if (defined $value) {
        chomp $value;
      }

      $self->{$name} ||= [];
      push @{$self->{$name}}, $value;
    }

    for my $f ($self->fields()) {
      my $ea = $el->getElementsByTagName($f);
      if (scalar @{$ea} and $ea->[0]->getFirstChild()) {
        $self->{$f} = $el->getElementsByTagName($f)->[0]->getFirstChild->getData();
      }
    }
    return;
}

sub obj_uri {
  my $self = shift;
  return sprintf q(%s/%s), $self->service(), $self->{'id'};
}

sub read {    ## no critic (ProhibitBuiltinHomonyms)
  my $self = shift;

  if(exists $self->{read}) {
    return $self->{read};
  }

  if(!$self->{id}) {
    carp qq[@{[ref $self]} cannot read without an id];
    $self->{read} = undef;
    return;
  }

  my $obj_uri = $self->obj_uri();
  my $response_content = $self->util->request('text/xml')->make($obj_uri);
  my $doc;
  eval {
   $doc = $self->util->parser->parse_string($response_content);

  } or do {
    my $error_message  = $response_content . qq{\n parsing $obj_uri\n\n};
    $error_message    .= qq{This could be due to Sequencescape problems such as a dead mongrel node,\n};
    $error_message    .= qq{as this response has come from the st::api modules.\n};
    $error_message    .= qq{Please quote this in an email to seq-help\@sanger.ac.uk\n\n};

    croak $error_message;
  };

  my $root   = $doc->documentElement();
  my $e_name = $self->entity_name();
  my $r_name = $root->nodeName();

  if($r_name ne $e_name) {
    $self->{read} = undef;
    return;
  }

  $self->{read} = $doc;
  return $doc;
}

sub service {
  my ($self) = @_;
  if($ENV{dev}) {
    $self->{service} = $ENV{dev};
  }
  return (!$self->{service} || $self->{service} eq 'live') ? $self->live():$self->dev();
}

1;
__END__

=head1 NAME

st::api::base - a base class for st::api::*

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - returns empty array (all subclasses should have own fields method)

=head2 primary_key - returns primary key for class model

=head2 new - default constructor

  my $oDerived = <pkg>->new();

  my $oDerived = <pkg>->new({key => value, ...});

=head2 new_from_xml - create and populate an st::api::* from a XML::LibXML::Element

  my $oObj = $oDerived->new_from_xml('st::api::<package>', $oXMLElement);

=head2 get - default 'get' accessor (see also Class::Accessor)

  my $val = $oDerived->get($sFieldName);

=head2 entity_name - derived from package name, top-level XML entity to parse, similar to SQL table in npg::model::

  my $entity_name = $oDerived->entity_name();

=head2 parse - default 'item' parsing. Invoked by default 'get' accessor.

  my $oDerived = <pkg>->new({'id' => $iId});
  $oDerived->parse();

=head2 read - default fetching and parsing for single entities

  my $oXMLFrag = $oDerived->read();

=head2 live_url - common part of URL for all live st services

  my $CommonLiveURLPart = $oDerived->live_url();

=head2 dev_url - common part of URL for all dev st services

  my $CommonDevURLPart = $oDerived->dev_url();

=head2 service - current service URL

  my $sServiceURL = $oDerived->service();

  $oDerived->service($sURL);

=head2 obj_uri - URI from which current object can be sourced

  my $sServiceURL = $oDerived->obj_uri();

=head2 util - Get/set accessor for an npg::api::util object

  my $oSTUtil = $oSTObj->util();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item Class::Accessor

=item npg::api::util

=item strict

=item warnings

=item Carp

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett
Copyright (C) 2011 GRL, by Marina Gourtovaia

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
