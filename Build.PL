use strict;
use warnings;
use lib 'lib';

use WTSI::DNAP::Utilities::Build;

my $class = WTSI::DNAP::Utilities::Build->subclass(code => <<'EOF');

  sub process_data_files {
    my $self = shift;
    my @files  = @{ $self->rscan_dir('data/templates',
                                     sub {-f $_ and /\.tt2$/}) };
    push @files, @{ $self->rscan_dir('data/npg_tracking_email/templates',
                                     sub {-f $_ and /\.tt2$/}) };
    push @files, @{ $self->rscan_dir('data/gfx',
                                     sub {-f $_ and /\.png$/}) };
    foreach my $f ( @files ) {
      $self->copy_if_modified(
        from    => $f,
        to_dir  => join(q[/], $self->base_dir(), $self->blib()),
        flatten => 0);
    }
    return;
  }

  sub process_htdocs_files {
    my $self = shift;
    my $files = $self->rscan_dir('htdocs', sub {-f $_ and (/\.css$/ or /\.js$/)});
    foreach my $f (@{$files}) {
      $self->copy_if_modified(
        from    => $f,
        to_dir  => join(q[/], $self->base_dir(), $self->blib()),
        flatten => 0);
    }
    return;
  }

  sub process_cgibin_files {
    my $self = shift;
    foreach my $file ( @{$self->rscan_dir('cgi-bin', sub {-f $_})} ) {
      my $dest_file = $self->copy_if_modified(
        from    => $file,
        to_dir  => join(q[/], $self->base_dir(), $self->blib()),
        flatten => 0);
      if ($dest_file) {
        $self->fix_shebang_line($dest_file);
        `chmod +x $dest_file`;
      }
    }
    return;
  }

  sub process_wtsi_local_files {
    my $self = shift;
    foreach my $file ( @{$self->rscan_dir('wtsi_local', sub {-f $_})} ) {
      $self->copy_if_modified(
        from => $file,
        to_dir  => join(q[/], $self->base_dir(), $self->blib()),
        flatten => 0);
    }
    return;
  }

  sub ACTION_install {
    my $self = shift;
    $self->SUPER::ACTION_install;
    my$config_path = join q[/], $self->install_path->{'data'}, 'npg_tracking';
    if(not -e $config_path) {
      warn "WARNING: There is no existing config file installed at $config_path so it is likely stuff will NOT work\n";
    }
  }

EOF

my $builder = $class->new(

                'module_name'         => 'npg-tracking',
                'dist_author'         => 'NPG team at WTSI <npg@sanger.ac.uk>',
                'dist_version'        => $class->report_version,
                'dist_abstract'       => 'Illumina sequencing instruments tracking',
                'license'             => 'gpl',

          'configure_requires' => {
                'ExtUtils::CBuilder'              => 0,
                'Module::Build'                   => '>= 0.42',
          },

          'build_requires' => {
                'ExtUtils::CBuilder'              => 0,
                'DateTime::Duration'              => 0,
                'DateTime::Format::SQLite'        => 0,
                'IO::File'                        => 0,
                'IPC::Open2'                      => 0,
                'List::Util'                      => 0,
                'Test::Compile'                   => 0,
                'Test::Distribution'              => 0,
                'Test::Deep'                      => '0.103',
                'Test::Exception'                 => '0.27',
                'Test::Exception::LessClever'     => '0.005',
                'Test::LongString'                => 0,
                'Test::MockModule'                => 0,
                'Test::MockObject'                => 0,
                'Test::More'                      => '0.86',
                'Test::Pod'                       => 0,
                'Test::Pod::Coverage'             => 0,
                'Test::Perl::Critic'              => 0,
                'Perl::Critic::Policy::Subroutines::ProhibitUnusedPrivateSubroutines' => 0,
                'Test::Trap'                      => '0.2.0',
                'Test::Warn'                      => '0.11',
                'WTSI::DNAP::Utilities'           => '>= 0.5.1',
          },

          'requires'    => {
                'perl'                            => '5.010',
                'autodie'                         => '2.10',
                'base'                            => '2.12',
                'Carp'                            => '1.04',
                'CGI'                             => '3.52',
                'Class::Accessor'                 => '0.31',
                'Class::Load'                     => 0,
                'Class::Std'                      => '0.0.8',
                'ClearPress::controller'          => '300',
                'ClearPress::decorator'           => '279',
                'ClearPress::model'               => '300',
                'ClearPress::util'                => '300',
                'ClearPress::view'                => '300',
                'ClearPress::view::error'         => '279',
                'Config::Auto'                    => 0,
                'Crypt::CBC'                      => 0,
                'Cwd'                             => 0,
                'Date::Parse'                     => '2.27',
                'DateTime'                        => '0.5',
                'DateTime::TimeZone'              => 0,
                'DateTime::Format::MySQL'         => 0,
                'DateTime::Format::Strptime'      => '1.0702',
                'DBD::mysql'                      => 0,
                'DBI'                             => '1.608',
                'DBIx::Class'                     => '0.08119',
                'DBIx::Class::Core'               => 0,
                'DBIx::Class::Schema'             => 0,
                'DBIx::Class::InflateColumn::DateTime' => 0,
                'Digest::MD5'                     => 0,
                'Digest::SHA'                     => 0,
                'English'                         => '1.02',
                'Errno'                           => 0,
                'Exporter'                        => '5.63',
                'Fcntl'                           => '0',
                'FindBin'                         => '1.47',
                'File::Basename'                  => 0,
                'File::Copy'                      => 0,
                'File::Find'                      => 0,
                'File::Path'                      => 0,
                'File::Spec'                      => 0,
                'File::Spec::Functions'           => 0,
                'File::Slurp'                     => 0,
                'File::Type'                      => '0.22',
                'File::Temp'                      => 0,
                'File::chdir'                     => 0,
                'GD'                              => '2.35',
                'GD::Graph::area'                 => '1.17',
                'GD::Graph::bars'                 => '1.26',
                'GD::Graph::lines'                => '1.15',
                'GD::Graph::mixed'                => '1.13',
                'GD::Image'                       => 0,
                'GD::Text'                        => 0,
                'Getopt::Long'                    => '2.37',
                'HTML::PullParser'                => '3.57',
                'HTML::Tidy'                      => 0,
                'HTTP::Request'                   => '5.818',
                'HTTP::Request::Common'           => '5.822',
                'HTTP::Response'                  => 0,
                'IO::All'                         => '0.39',
                'IO::All::FTP'                    => 0,
                'IO::Scalar'                      => '2.110',
                'IPC::System::Simple'             => 0,
                'JSON'                            => '2.12',
                'JSON::XS'                        => '2.34',
                'lib'                             => '0.5565',
                'Lingua::EN::Inflect'             => 0,
                'Linux::Inotify2'                 => 0,
                'List::MoreUtils'                 => '0.416',
                'Log::Log4perl'                   => 0,
                'LWP::UserAgent'                  => '5.823',
                'Math::Round'                     => '0.06',
                'MIME::Base64'                    => 0,
                'MIME::Lite'                      => '3.024',
                'MIME::Parser'                    => '5.427',
                'Module::PluginFinder'            => '0.04',
                'Moose'                           => '0.93',
                'Moose::Meta::Class'              => 0,
                'Moose::Role'                     => '0.93',
                'Moose::Util::TypeConstraints'    => 0,
                'MooseX::Aliases'                 => 0,
                'MooseX::AttributeHelpers'        => 0,
                'MooseX::ClassAttribute'          => 0,
                'MooseX::Getopt'                  => '0.39',
                'MooseX::Log::Log4perl'           => 0,
                'MooseX::MarkAsMethods'           => '0.13',
                'MooseX::NonMoose'                => '0',
                'MooseX::Role::Parameterized'     =>  0,
                'MooseX::Storage'                 => '0',
                'MooseX::StrictConstructor'       => '0.08',
                'namespace::autoclean'            => '0.09',
                'Net::LDAP'                       => 0,
                'open'                            => 0,
                'Perl6::Slurp'                    => '0.03',
                'Pod::Usage'                      => '0',
                'POSIX'                           => '1.09',
                'Readonly'                        => '1.03',
                'Readonly::XS'                    => 0,
                'Scalar::Util'                    => 0,
                'Socket'                          => 0,
                'strict'                          => '1.03',
                'SQL::Translator'                 => '0.11006',
                'Sys::Hostname'                   => '1.11',
                'Template'                        => '2.19',
                'Try::Tiny'                       => 0,
                'URI'                             => '1.37',
                'URI::Escape'                     => 0,
                'utf8'                            => 0,
                'warnings'                        => '1.05',
                'XML::Generator'                  => '1.01',
                'XML::LibXML'                     => '1.70',
                'XML::Simple'                     => '2.18',
                'YAML'                            => '0.68',
            },
         );

# Build and install cgi-related files
foreach my $path (qw(data htdocs cgi-bin wtsi_local)) {
  my $name = $path;
  $name =~ s/-//;
  $builder->add_build_element($name);
  if ($builder->install_base()) {
    $builder->install_path($path => join q{/}, $builder->install_base(), $path);
  }
}

$builder->create_build_script();

1;
