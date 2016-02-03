package npg_testing::db;

use Moose::Role;
use Carp;
use English qw{-no_match_vars};
use YAML qw(Load Dump);
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile);
use Cwd;
use Try::Tiny;
use Readonly;

with qw/npg_tracking::util::db_config/;

our $VERSION = '0';

Readonly::Scalar our $FEATURE_EXTENSION => q[.yml];
Readonly::Scalar our $TEMP_DIR => q{/tmp};

has 'verbose' =>
  (is      => 'rw',
   isa     => 'Bool',
   default => 1,    # This default preserves current behaviour
   documentation => 'Print to STDERR information about loading test database ' .
                    'fixtures.',);

=head1 NAME

npg_testing::db

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

A Moose role for creating and loading a test SQLite database using an
existing DBIx database binding. The encoding used in the YAML files
and in the test database is UTF-8. If UTF-8 is enabled for the MySQL
database (using mysql_enable_utf8 => 1 in the DBI connection attributes),
then it will be enabled automatically in any temporary SQLite database
created by the create_test_db method.

=head1 SUBROUTINES/METHODS

=head2 rs_list2fixture

Dumps a list of result sets for a table to a YAML fixture.
Can be used both as an object method and as a package function.

Takes three arguments:
(1) the name of the result class name for a table,
(2) a reference to a list with result sets all coming from the same table,
(3) a path to dump the fixture to; if no path given,
    current working directory is assumed.

 Example:
   use npg_tracking::Schema;
   use npg_testing::db;
   my $s=npg_tracking::Schema->connect();
   my $t=q{RunStatusDict};
   my $rs = $s->resultset($t)->search({});
   npg_testing::db::rs_list2fixture($t, [$rs]);

=cut
sub rs_list2fixture {
    my ($self, $tname, $rs_list, $path) = @_;
    if (!ref $self) {
      $path = $rs_list;
      $rs_list = $tname;
      $tname = $self;
    }
    if (!$path) {
      $path = getcwd();
    }
    my @rows = ();
    foreach my $rs (@{$rs_list}) {
        while (my $r = $rs->next) {
            push @rows, {$r->get_columns};
        }
      }

    my $file_name = catfile($path, $tname).$FEATURE_EXTENSION;
    my $yml = Dump(\@rows);

    # YAML::LoadFile uses Perl's default non-strict UTF-8 handling. We
    # want strict handling.
    open my $out, '>:encoding(UTF-8)', $file_name or
      croak "Failed to open '$file_name' for writing: $ERRNO";
    print {$out} $yml, "\n" or croak "Failed to write to '$file_name'";
    close $out or croak "Failed to close '$file_name': $ERRNO";

    return;
}


=head2 load_fixtures

Loads YAML fixtures to the test database. The fixtures files should be
named TableName.yml or XXX-TableName.yml, where 'TableName'
is the name of the relevant table as known to the DBIx database binding
and XXX is a number that is used to force loading in certain order.

Old2new fixtures script

ls -l | grep .yml | perl -nle 'my @columns = split q[ ], $_; my $old = pop @columns; my @w=split /-|_/, $old; my $number = shift @w; my $name = join q[], map {ucfirst $_} @w; $name = join q[-], $number, $name; `mv  $old $name`'

=cut
sub load_fixtures {
    my ($self, $schema, $path) = @_;

    if (!$path && !(ref $schema)) {
        $path = $schema;
        $schema = $self;
    }
    if (!$path) {
        croak 'Path should be given';
    }

    opendir my $dh, $path or croak "Could not open $path";
    my @fixtures = sort grep { /[.]yml$/smix } readdir $dh;
    closedir $dh;
    if (scalar @fixtures == 0) { croak qq[no fixtures found at $path]; }

    for my $fx (@fixtures) {
        my $file_name = "$path/$fx";

        # YAML::DumpFile uses Perl's default non-strict UTF-8
        # handling. We want strict handling.
        my $str = q[];
        {
            local $INPUT_RECORD_SEPARATOR = undef;

            open my $fh, '<:encoding(UTF-8)', $file_name or
              croak "Failed to open '$file_name' for reading: $ERRNO";
            $str = <$fh>;
            close $fh or
              croak "Failed to close '$file_name': $ERRNO";
        }

        my $yml = Load($str);
        my @temp = split m/[._]/sxm, $fx;
        pop @temp;
        my $table = join q[.], @temp;
        $table =~ s/^(\d)+-//smx;

        if ($self->verbose) {
          carp qq[+- Loading $fx into $table];
        }

        my $rs;
        try {
            $rs = $schema->resultset($table);
        } catch {
            #old-style names have to be mapped to DBIx classes
            ##no critic (ProhibitParensWithBuiltins)
            $table = join q[], map {ucfirst $_} split(/\./smx, $table);
            ##use critic
            if ($table eq q[QxYield]) {$table = q[QXYield];}
            $rs = $schema->resultset($table);
        };
        foreach my $row (@{$yml}) {
           $rs->create($row);
        }
    }
    return;
}


=head2 create_test_db

Creates a temp SQLite test database and loads data into it.
The first argument is a DBIx Schema object full namespace,
the second is the path to the directory where the fixtures
are located, the third one is a file name for the temporary
SQLite database. If the third argument is not given, a randomly
named file in a temporary directory is used; this file will
be cleaned up on exit.

If UTF-8 is enabled for the MySQL database (using mysql_enable_utf8 =>
1 in the DBI connection attributes), then it will be enabled
automatically in any temporary SQLite database created by the
this method.

=cut
sub create_test_db {
    my ($self, $schema_package, $fixtures_path, $tmpdbfilename) = @_;

    if (!$schema_package) { croak q[Schema package undefined in create_test_db]; }

    ##no critic (ProhibitStringyEval RequireCheckingReturnValueOfEval)
    eval "require $schema_package" or do { croak $EVAL_ERROR;} ;
    ##use critic

    if (!defined $tmpdbfilename) {
      $tmpdbfilename = q[:memory:];
    }

    my $user = undef;
    my $pass = undef;
    my $dbattr = {RaiseError => 1};

    if ($self->has_config_file) {
      # If there is a config file (MySQL) which has UTF-8 enabled,
      # enable it for SQLite too.
      if ($self->dbattr->{mysql_enable_utf8}) {
        $dbattr->{sqlite_unicode} = 1;
        if ($self->verbose) {
          carp q[Enabled UTF-8 support for SQLite ] .
               q[because it is enabled for MySQL];
        }
      }
      else {
        carp q[UTF-8 support is not enabled for SQLite ] .
             q[because it is not enabled for MySQL];
      }
    }
    else {
      # There is no config file, so enable UTF-8 by default.
      $dbattr->{sqlite_unicode} = 1;
      if ($self->verbose) {
        carp q[Enabled UTF-8 support for SQLite];
      }
    }

    my $tmpschema = $schema_package->connect('dbi:SQLite:' . $tmpdbfilename,
                                             $user, $pass, $dbattr);
    $tmpschema->deploy;
    if ($fixtures_path) {
        $self->load_fixtures($tmpschema, $fixtures_path);
    } else {
        carp q[Fixtures path undefined in create_test_db];
    }
    return $tmpschema;
}

=head2 deploy_test_db

Uses existing MySQL test database. Drops existing tables and
creates new ones. The first argument is a DBIx Schema object
full namespace, the second (optional) is the path to the
directory where the fixtures are located. Requires that
the configuration file path is supplied by the caller and
that the dev environment variable is set to test.

Example creating and using a derived class:

 package test_db_user;
 use Moose;
 with 'npg_testing::db';

 package main;
 use test_db_user;
 local $ENV{'dev'} = 'test';
 my $test_db_user = test_db_user->new(config_file => '/path/to/file');
 my $dbix_schema = $test_db_user->deploy_test_db('npg_qc::Schema');
 my $dbix_schema_with_loaded_fixtures =
   $test_db_user->deploy_test_db('npg_qc::Schema', '/path/to/fixtures_dir/');

Example creating and using an anonymous class:

 use Moose::Meta::Class;
 use npg_testing::db;
 local $ENV{'dev'} = 'test';
 my $test_db_user = Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_testing::db/])
         ->new_object({ config_file => '/path/to/file',});
 my $dbix_schema = $test_db_user->deploy_test_db('npg_qc::Schema');

=cut
sub deploy_test_db {
    my ($self, $schema_package, $fixtures_path) = @_;

    if (!$ENV{'dev'} || $ENV{'dev'} ne 'test') {
        croak 'dev environment variable should be set to "test"';
    }
    if (!$self->has_config_file) {
        croak q[Configuration file path is not set];
    }
    if (!$schema_package) {
        croak q[Schema package undefined];
    }

    ##no critic (ProhibitStringyEval RequireCheckingReturnValueOfEval)
    eval "require $schema_package" or do { croak $EVAL_ERROR;} ;
    ##use critic

    my $schema = $schema_package->connect($self->dsn, $self->dbuser, $self->dbpass, $self->dbattr);
    $schema->deploy({add_drop_table => 1});
    if ($fixtures_path) {
        load_fixtures($schema,  $fixtures_path);
    } else {
        carp q[Fixtures path undefined in create_test_db];
    }

    return $schema;
}

no Moose::Role;
1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item English

=item YAML

=item File::Temp

=item Cwd

=item File::Spec::Functions

=item Try::Tiny

=item npg_tracking::util::db_config

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL by Marina Gourtovaia

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


