package t::dbic_util;

use Moose;
use Readonly;
use Test::More;
Readonly::Scalar my $DEFAULT_FIXTURE_PATH => 't/data/dbic_fixtures';

with 'npg_testing::db';

has fixture_path => (
    is      => 'ro',
    isa     => 'Str',
    default => $DEFAULT_FIXTURE_PATH,
);

sub test_schema {
    my ($self) = @_;
    return $self->create_test_db('npg_tracking::Schema', $self->fixture_path());
}


no Moose;
__PACKAGE__->meta->make_immutable();
1;


__END__


=head1 NAME

t::dbic_util - make a DBIC schema to run tests against.

=head1 VERSION

=head1 SYNOPSIS

    C<<use t::dbic_util;
       my $schema = t::dbic_util->new->test_schema();>>

=head1 DESCRIPTION

    This module exists to consume the role npg_testing::db, and apply the
    create_test_db and load_fixture methods found there to make a schema to
    run tests against.

    The module needs no arguments, but the location of the fixtures and of the
    SQLite database file can be over-ridden.

    C<<my $util = t::dbic_util->new->(
                    fixture_path => '/some/nonstandard/place',
                    db_file_name => '/someplace/else',
    );

    my $schema = $util->test_schema();>>
    

=head1 SUBROUTINES/METHODS

=head2 test_schema

    Create a test database and return the schema object to be used by the test
    file.

=head1 CONFIGURATION AND ENVIRONMENT


=head1 INCOMPATIBILITIES


=head1 BUGS AND LIMITATIONS


=head1 AUTHOR

John O'Brien, E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (C) 2010 GRL, by John O'Brien

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
