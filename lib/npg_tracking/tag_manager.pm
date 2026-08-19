package npg_tracking::tag_manager;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Readonly;
use Carp;

use npg_tracking::Schema;

with qw/ MooseX::Getopt
         npg_tracking::glossary::run /;

our $VERSION = '0';

Readonly::Array my @TAG_ACTIONS => qw/add remove/;

# This custom type should accept both a scalar strings and a list of strings.
subtype q{ArrayRefOfStr},
  as q{ArrayRef[Str]};
coerce q{ArrayRefOfStr},
  from q{Str},
  via { [ $_ ] };

has q{tag} => (
  isa      => q{ArrayRefOfStr},
  is       => q{ro},
  required => 1,
  coerce   => 1,
  documentation => q{A list of tags or a single tag, } .
                   q{at least one tag should be given},
);

has q{action} => (
  isa      => q{Str},
  is       => q{ro},
  required => 0,
  default  => $TAG_ACTIONS[0],
  documentation =>
    q{Action to perform, ie "add" or "remove" tag(s), defaults to "add"},
);

has q{username} => (
  isa      => q{Str|Undef},
  is       => q{ro},
  required => 0,
  documentation =>
    q{Username for the database record, required for the "add" action},
);

has q{schema} => (
  isa        => q{npg_tracking::Schema},
  is         => q{ro},
  required   => 0,
  traits     => ['NoGetopt'],
  lazy_build => 1,
);
sub _build_schema {
  return npg_tracking::Schema->connect();
}

sub BUILD {
  my $self = shift;

  @{$self->tag} or croak 'At least one tag should be given.';
  ($self->action eq $TAG_ACTIONS[0]) || ($self->action eq $TAG_ACTIONS[1]) ||
    croak sprintf q[Invalid action '%s'.], $self->action;
  if (($self->action eq $TAG_ACTIONS[0]) && !$self->username) {
    croak 'username should be given for action ' . $self->action;
  }

  return;
}

sub perform_action {
  my $self = shift;

  my $run_row = $self->schema->resultset('Run')->find($self->id_run);
  if (!$run_row) {
    croak sprintf 'Run id %i does not exist', $self->id_run;
  }

  for my $t (@{$self->tag}) {
    if ($self->action eq 'add') {
      $run_row->set_tag($self->username, $t);
    } else {
      $run_row->unset_tag($t);
    }
  }

  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

 npg_tracking::tag_manager

=head1 SYNOPSIS

 npg_tracking::tag_manager->new(
   id_run => 33,
   tag    => 'staging',
   username => 'srpipe'
 )->perform_action();

 npg_tracking::tag_manager->new(
   id_run => 33,
   tag    => [qw/staging multiplexed/],
   username => 'srpipe',
   action => 'add'
 )->perform_action();

  npg_tracking::tag_manager->new(
   id_run => 33,
   tag    => 'staging',
   action => 'remove'
 )->perform_action();

=head1 DESCRIPTION

 Adds or removes tags for a tracked run.

=head1 SUBROUTINES/METHODS

=head2 id_run

 Integer run identifier, required.

=head2 tag

 A list of tags or a single tag to add or remove.

=head2 username

 Username for saving the tags to the database. Needed if the action is C<add>.

=head2 action

 Action to perform on tags, i.e. C<add> or C<remove>, defaults to C<add>.

=head2 schema

 DBIx schema object for the tracking database, will be built if not set.

=head2 BUILD

 Examines the object instance at the end of a call to C<new()>. Validates
 the values of attributes, raises an error in case of validation failure.

=head2 perform_action

 This no-attributes method adds or removes tags or a single tag.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item MooseX::StrictConstructor

=item Moose::Util::TypeConstraints

=item MooseX::Getopt

=item Readonly

=item Carp

=item npg_tracking::glossary::run

=item npg_tracking::Schemas

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

 Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2026 Genome Research Ltd.

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
