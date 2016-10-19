#!/usr/bin/env perl

use strict;
use warnings;
use DBIx::Class::Schema::Loader qw(make_schema_at);
use Config::Auto;
use lib qw/lib/;

my $path = join q[/], $ENV{'HOME'}, q[.npg], q[npg_tracking-Schema];
my $config = Config::Auto::parse($path);
my $domain = $ENV{'dev'} || q[live];
if (defined $config->{$domain}) {
  $config = $config->{$domain};
}
my $dsn = sprintf 'dbi:mysql:host=%s;port=%s;dbname=%s',
  $config->{'dbhost'}, $config->{'dbport'}, $config->{'dbname'};

make_schema_at(
    'npg_tracking::Schema',
    {
        debug               => 0,
        dump_directory      => q[lib],
        naming              => { 
            relationships    => 'current', 
            monikers         => 'current', 
            column_accessors => 'preserve',
        },
        skip_load_external  => 1,
        use_moose           => 1,
        preserve_case       => 1,
        use_namespaces      => 1,

        rel_name_map        => sub {
          # Rename the id relationship so we can access flat versions of
          # the objects and not only the whole trees from ORM.
          my %h = %{shift@_};
          my $name=$h{name};
          $name=~s/^id_//;
          return $name;
        },

        components => [qw(InflateColumn::DateTime)],
    },
    [$dsn, $config->{'dbuser'}, $config->{'dbpass'}]
);

1;
