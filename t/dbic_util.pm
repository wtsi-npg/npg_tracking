package t::dbic_util;

use Moose;
with 'npg_testing::db';

sub default_fixture_path {
  return 't/data/dbic_fixtures';
}

has fixture_path => (
    is         => 'ro',
    isa        => 'Maybe[Str]',
    lazy_build => 1,
);
sub _build_fixture_path {
  return default_fixture_path();
}

sub test_schema {
    my ($self) = @_;
    return $self->create_test_db('npg_tracking::Schema', $self->fixture_path());
}

no Moose;
__PACKAGE__->meta->make_immutable();
1;

