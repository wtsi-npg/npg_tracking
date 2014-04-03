#########
# Created by:       kt6
# Created on:       1 April 2014

package npg_tracking::util::build;
  use base 'Module::Build';

use strict;
use warnings;

##no critic (NamingConventions::Capitalization InputOutput::ProhibitBacktickOperators ErrorHandling::RequireCarping ValuesAndExpressions::ProhibitNoisyQuotes ControlStructures::ProhibitPostfixControls RegularExpressions::RequireDotMatchAnything RegularExpressions::ProhibitUnusedCapture) 

##no critic (Variables::ProhibitPunctuationVars RegularExpressions::RequireExtendedFormatting RegularExpressions::RequireLineBoundaryMatching ErrorHandling::RequireCheckingReturnValueOfEval Subroutines::RequireFinalReturn InputOutput::RequireCheckedSyscalls)

=head2 dir_files
=cut

 sub dir_files {
    my $dir = shift;
    opendir my $dh, $dir || die "can't opendir $dir: $!";
    my @files = map { "$dir/$_" } grep { /^\w+$/ && -f "$dir/$_" } readdir $dh;
    closedir $dh;
    return @files;
  }

=head2 process_data_files
=cut

  sub process_data_files {
    my $self = shift;
    `find data/npg_tracking_email/templates -type f | cpio -pdv --quiet blib`;
    if ($self->invoked_action() eq q[webinstall]) {
      `find data/templates -type f | cpio -pdv --quiet blib`;
      `find data/gfx -type f | cpio -pdv --quiet blib`;
    }
    return;
  }


=head2 process_htdocs_files
=cut

  sub process_htdocs_files {
    `find htdocs -type f | cpio -pdv --quiet blib`;
    return;
  }

=head2 process_cgi_files
=cut

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

=head2 process_wtsilocal_files
=cut

  sub process_wtsilocal_files {
    `find wtsi_local -type f | cpio -pdv --quiet blib`;
    return;
  }

=head2 cgi_version
=cut

  sub cgi_version {
    my $version;
    eval {
      require CGI;
      $version = $CGI::VERSION;
    };
    return $version && ($version eq '3.43') ? $version : '3.52';
  }

=head2 ACTION_webinstall
=cut

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


=head2 git_tag
=cut

  sub git_tag {
    my $version;
    my $gitver = q[./scripts/gitver];
    if (!-e $gitver) {
      warn "$gitver script not found";
      $version = q[unknown];
    }
    if (!-x $gitver) {
      warn "$gitver script is not executable";
      $version = q[unknown];
    }
    if (!$version) {
      $version = `$gitver`;
      $version =~ s/\s$//smxg;
    }
    return $version;
  }

=head2 ACTION_code
=cut

  sub ACTION_code {
    my $self = shift;
    $self->SUPER::ACTION_code;

    if ( ($self->invoked_action() ne q[install]) && ($self->invoked_action() ne q[webinstall]) ){
      return;
    } else {
      my $root = q[./blib/lib];
      my @dirs  = ($root);
      for my $path (@dirs){
        opendir DIR, $path or next;   # skip dirs we can't read
        while (my $file = readdir DIR) {
          my $full_path = join '/', $path, $file;
          next if $file eq '.' or $file eq '..'; # skip dot files
           if ( -d $full_path ) {
            push @dirs, $full_path; # add dir to list
          }
        }
        closedir DIR;
      }

      my @modules;
      foreach my $dir (@dirs) {
        opendir DIR, $dir or die $!;
        while (my $file = readdir DIR) {
          next unless (-f "$dir/$file");
          next unless ($file =~ m/\.pm$/);
          push @modules, $dir . q[/] . $file;
        }
        closedir DIR;
      }

      foreach my $module (@modules) {
        my $gitver = $self->git_tag();
        if (-e $module) {
          warn "Changing version of $module to $gitver\n";
          my $backup = '.original';
          local $^I = $backup;
          local @ARGV = ($module);
          while (<>) {
            s/(\$VERSION\s*=\s*)('?\S+'?)\s*;/${1}'$gitver';/;
            s/head1 VERSION$/head1  VERSION\n\nVersion $gitver/;
            print;
          }
          unlink "$module$backup";
        } else {
          warn "File $module not found\n";
        }
      }
    }
  }
1;

=head1 NAME 

npg_tracking::util::build

=head1 VERSION

=head1 SYNOPSIS

use npg_util::Build

=head1 DESCRIPTION

Provide the methods to add git tag and SHA to VERSION and POD VERSION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over

=item Module::Build

=back

=head1 NAME

=head1 BUGS AND LIMITATIONS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

=head1 AUTHOR

Kate Taylor, E<lt>kt6@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Kate Taylor

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
