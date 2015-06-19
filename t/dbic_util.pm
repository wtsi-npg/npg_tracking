package t::dbic_util;

use Moose;
with 'npg_testing::db';

has fixture_path => (
    is      => 'ro',
    isa     => 'Str',
    default => 't/data/dbic_fixtures',
);

sub test_schema {
    my ($self) = @_;
    return $self->create_test_db('npg_tracking::Schema', $self->fixture_path());
}

no Moose;
__PACKAGE__->meta->make_immutable();
1;

