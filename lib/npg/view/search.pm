#########
# Author:        rmp
# Created:       2008-01
#
package npg::view::search;
use strict;
use warnings;
use base qw(npg::view);
use npg::controller;
use Carp;

our $VERSION = '0';

sub read { ## no critic (Subroutines::ProhibitBuiltinHomonyms)
  my ($self) = @_;
  my $model = $self->model();
  $model->query($model->dummy_pk());
  return 1;
}

sub list {
  my $self  = shift;
  my $util  = $self->util();
  my $cgi   = $util->cgi();
  my $query = $cgi->param('query') || q();
  my $model = $self->model();
  $query    =~ s/^\s+//smx;
  $query    =~ s/\s+$//smx;

  $model->query($query);

  return;
}

sub list_advanced {
  my $self  = shift;
  my $util  = $self->util();
  my $cgi   = $util->cgi();
  my $query = $cgi->param('query') || q();
  my $model = $self->model();
  $model->util($util);
  $model->query($query);
  if ($query) {
    foreach my $field ($model->fields()) {
      $model->{$field} = $cgi->param($field) || undef;
    }
  }

  return;
}

sub list_advanced_ajax {
  my $self  = shift;
  my $util  = $self->util();
  my $cgi   = $util->cgi();
  my $query = $cgi->param('query') || q();
  my $model = $self->model();
  $model->util($util);
  $model->query($query);

  return;
}

sub list_advanced_xml {
  my $self = shift;
  my $util  = $self->util();
  my $model = $self->model();
  $model->util($util);
  return;
}

1;
__END__

=head1 NAME

npg::view::search

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 list - basic handling for passing through the query term

=head2 list_advanced - creates/enables creation of more advanced search criteria and returns table

=head2 list_advanced_ajax - intent to AJAX back results from advanced search query

=head2 list_advanced_xml - returns result of advanced search query as an XML DOM tree

=head2 read - handler to catch when a search term is used where the primary key would be, and then switches this to the query term

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
