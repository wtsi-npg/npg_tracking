use strict;
use warnings;
use Test::More tests => 8;
use t::util;
use Test::Trap;

use_ok('npg::model::usergroup');

my $util = t::util->new({fixtures=>1});

{
  my $usergroup = npg::model::usergroup->new({
                util => $util,
               });
  isa_ok($usergroup, 'npg::model::usergroup');
}

{
  trap {
    my $usergroup = npg::model::usergroup->new({
            util      => 'bla',
            groupname => 'fail!',
                 });
    is($usergroup->init(), undef, 'database query failure');
  };
}

{
  my $usergroup = npg::model::usergroup->new({
                util         => $util,
                id_usergroup => 4,
               });
  is($usergroup->groupname(), 'events', 'group by id');
}

{
  my $usergroup = npg::model::usergroup->new({
                util      => $util,
                groupname => 'events',
               });
  is($usergroup->id_usergroup(), 4, 'group by name');
}

{
  my $usergroup = npg::model::usergroup->new({
                util         => $util,
                id_usergroup => 4,
               });
  my $users = $usergroup->users();
  is((scalar @{$users}), 2, 'user list size');
  isa_ok($users->[0], 'npg::model::user', 'first user type');

  my $users2 = $usergroup->users();
  is_deeply($users, $users2, 'cached user list');
}

1;
