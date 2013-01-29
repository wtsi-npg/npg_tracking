use strict;
use warnings;
use Test::More tests => 44;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Moose::Meta::Class;


BEGIN {
  use_ok(q{npg_tracking::illumina::run::short_info});
}

package test::short_info;
use Moose;
use Carp;
use Readonly;
use File::Spec::Functions qw(splitdir);
use List::Util qw(first);

Readonly::Scalar my $FOLDER_PATH_PREFIX_GLOB_PATTERN => '/{staging,nfs/sf{5,6,9,10,11,12,13,14,15,16,17}}/{IL,HS}*/*/';

with qw{npg_tracking::illumina::run::short_info};

sub _build_run_folder {
  my ($self) = @_;

  if( !( $self->has_id_run() || $self->has_name() ) ) {
    croak q{Need an id_run or name to generate the run_folder};
  }

  my $path = $self->_short_path();
  return first {$_ ne q()} reverse splitdir($path);
  
}


has q{_short_path}                => ( isa => q{Str}, is => q{ro}, lazy_build => 1, init_arg => undef );

sub _build__short_path {
  my ($self) = @_;
  my @dir = $self->has_run_folder() ? glob $self->_folder_path_glob_pattern() . $self->run_folder()
          : $self->has_id_run()     ? glob $self->_folder_path_glob_pattern() . q(*_{r,}) . $self->id_run() . q{*} 
          : $self->has_name()       ? glob $self->_folder_path_glob_pattern() . q{*} . $self->name()
          :                           croak q{No run_folder, name or id_run provided}
          ;

  @dir = grep {-d $_} @dir;

  if ( @dir == 0 ) {
    croak 'No paths to run folder found.';
  }

  my %fs_inode_hash; #ignore multiple paths point to the same folder
  @dir = grep {not $fs_inode_hash{join q(,),stat $_}++} @dir;

  if ( @dir > 1 ) {
    croak 'Ambiguous paths for run folder found: '.join q{,},@dir;
  }
  return shift @dir;
}

has 'pattern_prefix' => (
  is => 'ro',
  isa => 'Str',
  default => q[/nonexisting],
);

sub _folder_path_glob_pattern {
  my $self = shift;
  return $self->pattern_prefix . $FOLDER_PATH_PREFIX_GLOB_PATTERN;
}


package main;

sub create_staging {

  my ($idr, $hi_seq) = @_;
  if (!$idr) { $idr = 1234; }
  my $base = tempdir( CLEANUP => 1 );

  my $instr_prefix = $hi_seq ? q[HS] : q[IL];

  my $next = $base . q[/staging]; `mkdir $next`;
  $next = $next . q[/] . $instr_prefix . q[2]; `mkdir $next`;
  $next = $next . q[/analysis]; `mkdir $next`;
  $next = $next . q[/123456_] . $instr_prefix . q[2_] . $idr;

  if ( $hi_seq ) {
    $next .= q{_B_205NNABXX};
  }

  `mkdir $next`;
  $next = $next . q[/Data]; `mkdir $next`;
  $next = $next . q[/Intensities]; `mkdir $next`;

  my $base_calls = $next . q[/BaseCalls]; `mkdir $base_calls`;
  my $gerald = $next . q[/Bustard-2009-10-01]; `mkdir $gerald`;
  $gerald = $next . q[/GERALD-2009-10-01];  `mkdir $gerald`;

  return $base;
}

my $id_run = q{1234};
my $name = q{IL2_1234};
my $run_folder = q{123456_IL2_1234};

{
  my $short_info;
  lives_ok  { $short_info = Moose::Meta::Class->create_anon_class(
                roles => [qw/npg_tracking::illumina::run::short_info/]
              )->new_object({id_run => 1234});
            } q{object directly from the role ok};

  throws_ok { $short_info->run_folder(); }
    qr{does[ ]not[ ]support[ ]builder[ ]method[ ]'_build_run_folder'[ ]for[ ]attribute[ ]'run_folder'},
    q{Error thrown as no _build_run_folder method in class};
}

{
  my $short_info;
  lives_ok  { $short_info = test::short_info->new({}); } q{no error creating no-arg test object};
  throws_ok { $short_info->id_run();          }
    qr{Unable[ ]to[ ]obtain[ ]id_run[ ]from name[ ]:[ ]Unable[ ]to[ ]obtain[ ]name[ ]from[ ]run_folder},
    q{As no name or run_folder, can't obtain id_run};
  throws_ok { $short_info->name();            }
    qr{Unable[ ]to[ ]obtain[ ]name[ ]from[ ]run_folder},
    q{As no id_run or run_folder, can't obtain name};
  throws_ok { $short_info->run_folder();      }
    qr{Need[ ]an[ ]id_run[ ]or[ ]name[ ]to[ ]generate[ ]the[ ]run_folder},
    q{As no name or id_run, can't obtain run_folder};
  throws_ok { $short_info->_short_path();     }
    qr{No[ ]run_folder,[ ]name[ ]or[ ]id_run[ ]provided},
    q{As no attributes, cannot get short path};
  throws_ok { $short_info->short_reference(); }
    qr{Unable[ ]to[ ]obtain[ ]name[ ]from[ ]run_folder},
    q{As no id_run or run_folder, can't obtain name};
}

#### test where run_folder is given in the constructor
{
  my $short_info = test::short_info->new({
    run_folder => $run_folder,
  });
  is($short_info->id_run(), $id_run, q{id_run worked out correctly});
  is($short_info->name(), $name, q{name worked out correctly});
  is($short_info->short_reference(), $run_folder, q{short_reference returns run_folder first});

  my $hs_runfolder = q{123456_HS2_1236_B_205NNABXX};
  $short_info = test::short_info->new({
    run_folder => $hs_runfolder,
  });
  is($short_info->name(), q{HS2_1236}, q{HS name worked out correctly});
  is($short_info->id_run(), '1236', q{HS id_run worked out correctly});
  is($short_info->short_reference(), $hs_runfolder, q{HS short_reference returns run_folder first});
  is( $short_info->instrument_string(), q{HS2}, q{HS instrument name correctly worked out} );
  is( $short_info->slot(), q{B}, q{HS slot returned ok} );
  is( $short_info->flowcell_id(), q{205NNABXX}, q{HS flowcell_id returned ok} );
}

#### test where run_folder is given in the constructor
# where we can't find out the run_folder
{
  my $short_info = test::short_info->new({
    id_run => $id_run,
  });
  is($short_info->id_run(), $id_run, q{id_run returned correctly});
  is($short_info->short_reference(), $id_run, q{short_reference returns id_run});
  throws_ok { my $name = $short_info->name(); } qr{No[ ]paths[ ]to[ ]run[ ]folder[ ]found}, q{no runfolder found with which to return the path, so name/runfolder cannot be worked out};
}

# where we can find the run_folder
{
  my $base = create_staging();
  my $short_info = test::short_info->new({
    id_run => $id_run,
    pattern_prefix => $base,
  });
  is($short_info->short_reference(), $id_run, q{short_reference returns id_run});
  is($short_info->name(),$name, q{name worked out correctly});
  is($short_info->short_reference(), $run_folder, q{short_reference returns run_folder});

  $base = create_staging(undef, 1);
  $short_info = test::short_info->new({
    id_run => $id_run,
    pattern_prefix => $base,
  });
  is($short_info->short_reference(), $id_run, q{HS short_reference returns id_run});
  is($short_info->name(),q{HS2_1234}, q{HS name worked out correctly});
  is($short_info->short_reference(), q{123456_HS2_1234_B_205NNABXX}, q{HS short_reference returns run_folder});  
}

#### test where name is give in the constructor
{
  my $base = create_staging();
  my $short_info = test::short_info->new({
    name => $name,
    pattern_prefix => $base,
  });
  is($short_info->short_reference(), $name, q{short_reference returns name});
  is($short_info->id_run(), $id_run, q{id_run worked out correctly});
  is($short_info->short_reference(), $id_run, q{short_reference returns id_run});
  is($short_info->run_folder(), $run_folder, q{run_folder worked out correctly});
  is($short_info->short_reference(), $run_folder, q{short_reference returns run_folder});
}


{
  my $id = q[01234];
  my $base = create_staging($id);
  my $short_info = test::short_info->new({
    run_folder =>q{123456_IL2_01234},
    pattern_prefix => $base,
  });
  is($short_info->id_run(), 1234, q{id_run worked out correctly, no leading zero});
  is($short_info->name(), q[IL2_1234], q{name does not contain leading zero for id run});
  is($short_info->run_folder(), q[123456_IL2_01234], q{run_folder as set});
  is($short_info->short_reference(), q[123456_IL2_01234], q{short_reference returns run_folder});
  is( $short_info->instrument_string(), q{IL2}, q{IL instrument name correctly worked out} );
  is( $short_info->flowcell_id(), q{}, q{IL flowcell_id returns empty string} );
  is( $short_info->slot(), q{}, q{IL slot returns empty string} );
}


{
    my $id = q{fail};
    my $base = create_staging($id);
    my $short_info = test::short_info->new({
      run_folder =>q{123456_IL2_} . $id,
      pattern_prefix => $base,
    });

    throws_ok { $short_info->name() }
              qr/Unrecognised format for run folder name: /ms,
              q{croak if the run id doesn't start with an integer};
}


{
    my $short_info = test::short_info->new({
      run_folder =>q{120113_MS1_7362_A_MS0002061-00300},
    });

    my $name;
    my $flowcell_id;
    lives_ok { 
      $name = $short_info->name();
      $flowcell_id= $short_info->flowcell_id();
    } q{MiSeq runfolder - kit id in place of flowcell};
    is($short_info->run_folder, q(120113_MS1_7362_A_MS0002061-00300), q(run folder okay));
    is($name, q(MS1_7362), q(name okay));
    is($flowcell_id, q(MS0002061-00300), q(flowcell_id (kit id) okay));
}

1;
