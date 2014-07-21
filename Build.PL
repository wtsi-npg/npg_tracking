use strict;
use warnings;
use lib 'lib';
use npg_tracking::util::build;

my $class = npg_tracking::util::build->subclass(code => <<'EOF');

 sub dir_files {
    my $dir = shift;
    opendir my $dh, $dir || die "can't opendir $dir: $!";
    my @files = map { "$dir/$_" } grep { /^\w+$/ && -f "$dir/$_" } readdir $dh;
    closedir $dh;
    return @files;
  }

  sub process_data_files {
    my $self = shift;
    `find data/npg_tracking_email/templates -type f | cpio -pdv --quiet blib`;
    if ($self->invoked_action() eq q[webinstall]) {
      `find data/templates -type f | cpio -pdv --quiet blib`;
      `find data/gfx -type f | cpio -pdv --quiet blib`;
    }
    return;
  }

  sub process_htdocs_files {
    `find htdocs -type f | cpio -pdv --quiet blib`;
    return;
  }

  sub process_cgi_files {
    my $self = shift;
    my @files = dir_files('cgi-bin');
    foreach my $file (@files) {
      my $dest_file = $self->copy_if_modified('from' => $file, 'to_dir' => 'blib');
      if ($dest_file) {
        $self->fix_shebang_line($dest_file);
      }
    }
    `chmod +x blib/cgi-bin/*`;
    return;
  }

  sub process_wtsilocal_files {
    `find wtsi_local -type f | cpio -pdv --quiet blib`;
    return;
  }

  sub ACTION_webinstall {
    my $self = shift;
    if (!$self->install_base()) {
      warn "WARNING: '--install_base' option is not given, nothing to do for the 'webinstall' action\n\n";
      return;
    }

    $self->install_path('htdocs' => join q{/}, $self->install_base(), 'htdocs');
    $self->add_build_element('htdocs');
    $self->install_path('cgi-bin' => join q{/}, $self->install_base(), 'cgi-bin');
    $self->add_build_element('cgi');
    $self->install_path('wtsi_local' => join q{/}, $self->install_base(), 'wtsi_local');
    $self->add_build_element('wtsilocal');
    $self->depends_on('install');

    return;
  }

EOF

my $builder = $class->new(

                'module_name'         => 'npg-tracking',
                'dist_author'         => q(wtsi-npg <npg@sanger.ac.uk>),
                'dist_version'        => $class->git_tag(),
                'dist_abstract'       => 'Illumina sequencing instruments tracking',
                'license'             => 'gpl',

          'configure_requires' => {
                'ExtUtils::CBuilder'              => 0,
          },

          'build_requires' => {
                'ExtUtils::CBuilder'              => 0,
                'IPC::Open2'                      => 0,
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
                'DateTime::Format::SQLite'        => 0,
                'IO::File'                        => 0,
          },

          'requires'    => {
                'autodie'                         => '2.10',
                'base'                            => '2.12',
                'Carp'                            => '1.04',
                'CGI'                             => '3.52',
                'Class::Accessor'                 => '0.31',
                'Class::Std'                      => '0.0.8',
                'ClearPress::controller'          => '300',
                'ClearPress::decorator'           => '279',
                'ClearPress::model'               => '300',
                'ClearPress::util'                => '300',
                'ClearPress::view'                => '300',
                'ClearPress::view::error'         => '279',
                'Clone'                           => 0,
                'Config::Auto'                    => 0,
                'Crypt::CBC'                      => 0,
                'Cwd'                             => 0,
                'Data::Dumper'                    => '2.121_08',
                'Date::Calc'                      => '5.4',
                'Date::Parse'                     => '2.27',
                'DateTime'                        => '0.5',
                'DateTime::TimeZone'              => 0,
                'DateTime::Format::MySQL'         => 0,
                'DateTime::Format::Strptime'      => '1.0702',
                'DateTime::TimeZone'              => 0,
                'DBD::mysql'                      => 0,
                'DBI'                             => '1.608',
                'DBIx::Class'                     => '0.08119',
                'Digest::MD5'                     => 0,
                'Digest::SHA'                     => 0,
                'English'                         => '1.02',
                'Exporter'                        => '5.63',
                'File::Slurp'                     => '9999.13',
                'File::Type'                      => '0.22',
                'FindBin'                         => '1.47',
                'File::Basename'                  => 0,
                'File::Copy'                      => 0,
                'File::Find'                      => 0,
                'File::Path'                      => 0,
                'File::Spec'                      => 0,
                'File::Spec::Functions'           => 0,
                'File::Slurp'                     => 0,
                'File::Temp'                      => 0,
                'File::Type'                      => 0,
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
                'lib'                             => '0.5565',
                'Lingua::EN::Inflect'             => 0,
                'List::MoreUtils'                 => '0.22',
                'List::Util'                      => '1.21',
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
                'MooseX::StrictConstructor'       => '0.08',
                'MooseX::MarkAsMethods'           => '0.13',
                'MooseX::NonMoose'                => '0',
                'namespace::autoclean'            => '0.09',
                'Net::LDAP'                       => 0,
                'Perl6::Slurp'                    => '0.03',
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
                'warnings'                        => '1.05',
                'XML::Generator'                  => '1.01',
                'XML::LibXML'                     => '1.70',
                'XML::Simple'                     => '2.18',
                'YAML'                            => '0.68',
            },
         
            'dist'         => { COMPRESS => 'gzip', SUFFIX => 'gz', },
         );

if ($builder->install_base()) {
  $builder->install_path('data' => join q{/}, $builder->install_base(), 'data');
  $builder->add_build_element('data');
} else {
  warn qq[WARNING: '--install_base' option is not given, 'data' element will not be installed,\n];
}

$builder->create_build_script();

1;
