use strict;
use warnings;
use Test::More tests => 21;
use Test::Exception;
use Digest::SHA qw(sha256_hex);
use t::util;

use_ok('npg::model::user');

my $util  = t::util->new({fixtures => 1});

{
  my $model = npg::model::user->new({
             util     => $util,
             id_user  => 1,
            });
  is($model->username(), 'joe_admin', 'user by id');
  is($model->is_member_of('admin'), 1, 'admin user is_member_of admin');
  is($model->is_member_of('engineers'), 1, 'admin user is_member_of engineers');
  is(join(q[ ], map {$_->username} @{$model->users}),
    'joe_admin joe_analyst joe_annotator joe_approver joe_engineer joe_events joe_loader ' .
    'joe_r_n_d joe_results pipeline public rt_error',
    'list of current users');  
}

{
  my $model = npg::model::user->new({
             util     => $util,
             username => 'joe_engineer',
            });
  is($model->id_user(), 4, 'user by username');
  is($model->is_member_of('admin'), undef, 'engineer user is not member of admin');
  is($model->is_member_of('engineers'), 1, 'admin user is_member_of engineers');
}

{
  my $model = npg::model::user->new({
             util     => $util,
             username => 'joe_analyst',
            });
  is($model->id_user(), 12, 'user by username');
  is($model->is_member_of('admin'), undef, 'analyst user is not member of admin');
  is($model->is_member_of('analyst'), 1, 'analyst user is_member_of analyst');
}

{
  my $model = npg::model::user->new({
      util     => $util,
      id_user  => 1,
  });
  is( $model->username(), q{joe_admin}, q{user by id} );
  is( $model->rfid(), q{a07c54b988516a16f305aa7d483bb2cf5a496f167ea13548cf2222c5125499e6}, q{correct sha string returned by rfid} );
}

{
  my $model = npg::model::user->new({
      util  => $util,
      rfid  => q{admin_joe},
  });
  $model->read();
  is( $model->username(), q{joe_admin}, q{user by rfid} );
  is( $model->rfid(), q{a07c54b988516a16f305aa7d483bb2cf5a496f167ea13548cf2222c5125499e6}, q{correct sha string returned by rfid} );
}

{
  my $model = npg::model::user->new({
    util => $util,
    rfid => q{no_longer_admin_joe},
    id_user => 1,
    username => q{joe_admin},
  });

  is( $model->rfid(), q{d168639a64be86ec756c120fe5acb664a4c8a60f3a4b380a534c615a554d4b34}, q{rfid has been altered on object creation} );
  lives_ok {
    $model->update();
  } q{update runs ok};
}
{
  my $model = npg::model::user->new({
    util => $util,
    id_user => 1,
  });

  $model->{rfid} = q{no_longer_admin_joe};
  is( $model->rfid(), q{no_longer_admin_joe}, q{no database call made yet} );
  $model->{rfid} = sha256_hex( $model->{rfid} );

  is( $model->rfid(), q{d168639a64be86ec756c120fe5acb664a4c8a60f3a4b380a534c615a554d4b34}, q{rfid has been modified externally} );
  lives_ok {
    $model->update();
  } q{update runs ok};

  is( $model->rfid(), q{d168639a64be86ec756c120fe5acb664a4c8a60f3a4b380a534c615a554d4b34}, q{no change to rfid on update} );
}

1;
