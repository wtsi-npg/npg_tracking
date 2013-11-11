#############
# Created By: Marina Gourtovaia
# Created On: 11 June 2010
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg/api/request.pm, r16549

package npg::api::request;

use Carp;
use English qw( -no_match_vars );
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::StrictConstructor;
use MooseX::ClassAttribute;
use LWP::UserAgent;
use HTTP::Request::Common;
use File::Basename;
use File::Path;
use File::Spec::Functions qw(catfile);
use Readonly;

our $VERSION = '75.2';

## no critic (RequirePodAtEnd RequireCheckingReturnValueOfEval)

=head1 NAME

npg::api::request

=head1 VERSION

$Revision: 16549 $

=head1 SYNOPSIS

=head1 DESCRIPTION

Performs requests to web services on behalf on NPG software.
Retrieves requested contents either from a specified URI or from a cache.
When retrieving the contents from URI can, optionally, save the resource
to cache.

The location of the cache is stored in an environment variable

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar our $DEFAULT_VAR_NAME => q[NPG_WEBSERVICE_CACHE_DIR];
Readonly::Scalar our $SAVE2CACHE_VAR_NAME => q[SAVE2NPG_WEBSERVICE_CACHE];

Readonly::Scalar our $MAX_RETRIES          => 10;
Readonly::Scalar our $RETRY_DELAY          => 10;
Readonly::Scalar our $LWP_TIMEOUT          => 60;
Readonly::Scalar our $DEFAULT_METHOD       => q[GET];
Readonly::Scalar our $DEFAULT_CONTENT_TYPE => q[text/xml];


subtype 'NPG_API_Request_PositiveInt'
      => as Int
      => where { $_ > 0 };


=head2 cache_dir_var_name

Name of the environmental variable that defines the location
of the cache. Class attribute.

=cut
class_has 'cache_dir_var_name'=> (isa        => 'Str',
                                  is         => 'ro',
                                  required   => 0,
                                  default    => $DEFAULT_VAR_NAME,
                                 );

=head2 cache_dir_var_name

Name of the environmental variable that defines whether
the retrieved files have to be saved to cache. Class attribute.

=cut
class_has 'save2cache_dir_var_name'=> (isa        => 'Str',
                                       is         => 'ro',
                                       required   => 0,
                                       default    => $SAVE2CACHE_VAR_NAME,
                                      );

=head2 max_retries

Maximum number of attempts to retrieve a requested resource.

=cut
has 'max_retries'=> (isa             => 'NPG_API_Request_PositiveInt',
                     is              => 'ro',
                     required        => 0,
                     default         => $MAX_RETRIES,
                    );

=head2 retry_delay

A delay (in seconds) between attempts.

=cut
has 'retry_delay'=> (isa             => 'NPG_API_Request_PositiveInt',
                     is              => 'ro',
                     required        => 0,
                     default         => $RETRY_DELAY,
                    );

=head2 content_type

Content type to accept

=cut
has 'content_type'=> (isa             => 'Maybe[Str]',
                      is              => 'ro',
                      required        => 0,
                     );

=head2 useragent

Useragent for making an HTTP request.

=cut
has 'useragent'   => (isa             => 'Object',
                      is              => 'ro',
                      required        => 0,
                      lazy_build      => 1,
                     );
sub _build_useragent {
    my $self = shift;

    my $ua = LWP::UserAgent->new();
    $ua->agent(join q[/], __PACKAGE__, $VERSION);
    $ua->timeout($LWP_TIMEOUT);
    $ua->env_proxy();
    return $ua;
}

=head2 make

Contacts a web service to perform a requested operation.
For GET requests optionally saves the content of a requested web resource
to a cache. If a global variable whose name is returned by
$self->cache_dir_var_name is set, for GET requests retrieves the
requested resource from a cache.

=cut
sub make {
    my ($self, $uri, $method, $args) = @_;

    if (!$uri) {
        croak q[Uri is not defined];
    }

    if (!$method) {
        $method = $DEFAULT_METHOD;
    }

    my $cache = $ENV{$self->cache_dir_var_name} ? $ENV{$self->cache_dir_var_name} : q[];

    my $content;

    if ($method ne $DEFAULT_METHOD) {
        if ($cache) {
            croak qq[$method requests cannot use cache: $uri];
	}
        $content = $self->_from_web($uri, $method, $args);
    } else {
        my $path = q[];
        if ($cache) {
            $self->_check_cache_dir($cache);
            $path = $self->_create_path($uri);
            if (!$path) {
                croak qq[Empty path generated for $uri];
	    }
        }

        $content = ($cache && !$ENV{$self->save2cache_dir_var_name}) ?
                  $self->_from_cache($path, $uri) :
                  $self->_from_web($uri, $method, $args, $path);
        if (!$content) {
          croak qq[Empty document at $uri $path];
        }
    }

    return $content;
}


sub _create_path {
  my ( $self, $url ) = @_;

  my ($stpath)  = $url =~ m{\Ahttps?://psd\-[^/]+(.*?)\z}xms; # sequencescape path
  ##no critic(ProhibitComplexRegexes)
  my ($npgpath) = $url =~ m{\Ahttps?://
                            (?:npg|sfweb)
                            (?:\.(?:dev|internal))?
                             \.sanger\.ac\.uk?(?::\d+)?
                             \/perl\/npg\/
                            (.*?)\z}xms; # npg path
  ##use critic
  my ($extpath) = $url =~ m{\Ahttps?://.*?/(.*?)\z}xms; # other source path

  my $path = $stpath || $npgpath || $extpath;
  $path =~ s/[ ]/_/gxms; # swap spaces for underscores
  ($path) = $path =~ m{([/[:lower:][:digit:]_.]+)}xms; # get rid of horrible characters
  $path =~ s{\A/}{}xms; # stop double // before path

  if ($npgpath) {
      $path = catfile(q{npg}, $path);
  } elsif ($stpath) {
      $path = catfile(q{st}, $path);
  } elsif ($extpath) {
      $path = catfile(q{ext}, $path);
  }

  if ($path) {
      $path = catfile($ENV{$self->cache_dir_var_name}, $path);
  }
  return $path;
}


sub _check_cache_dir {
    my ($self, $cache) = @_;

    if (!-e $cache) {
       croak qq[Cache directory $cache does not exist];
    }
    if (!-d $cache) {
       croak qq[$cache (a proposed cache directory) is not a directory];
    }
    if ($ENV{$self->save2cache_dir_var_name}) {
        if (!-w $cache) {
            croak qq[Cache directory $cache is not writable];
	}
    } else {
        if (!-r $cache) {
            croak qq[Cache directory $cache is not readable];
	}
    }
    return 1;
}

sub _from_cache {
    my ($self, $path, $uri) = @_;

    $path .= $self->_extension($self->content_type);
    if (!-e $path) {
        croak qq[$path for $uri is not in the cache];
    }

    local $RS = undef;
    open my $fh, q[<], $path or croak qq[Error when opening $path for reading: $ERRNO];
    if (!defined $fh) { croak qq[Undefined filehandle returned for $path]; }
    my $content = defined $fh ? <$fh> : croak qq[Failed to read from an open $path: $ERRNO];
    close $fh or croak qq[Failed to close a filehandle for $path: $ERRNO];

    return $content;
}

sub _from_web {
    my ($self, $uri, $method, $args, $path) = @_;

    if ($path && $ENV{$self->save2cache_dir_var_name} && $ENV{$self->cache_dir_var_name}) {
        my $content;
        eval {
	    $content = $self->_from_cache($path, $uri);
	};
        if ($content) {
            return $content;
	}
    }

    my $req;
    if ($method eq $DEFAULT_METHOD) {
        $req = GET $uri, @{$args||[]};
    } else {
        $req = POST $uri, @{$args||[]};
    }
    if ($self->content_type) {
        $req->header('Accept' => $self->content_type);
    }
    $self->_personalise_request($req);

    my $response = $self->_retry(sub {
             my $inner_response = $self->useragent()->request($req);
             if(!$inner_response->is_success()) {
                 croak $inner_response->status_line();
             }
             return $inner_response;
                                 }, $uri);

    if(!$response->is_success()) {
        croak qq[Web request to $uri failed: ] . $response->status_line();
    }

    my $content = $response->content();
    if($content =~ /<h\d>An[ ]Error[ ]Occurred/smix) {
        my ($errstr) = $content =~ m{<p>(Error.*?)</p>}smix;
        croak $errstr;
    }

    if (defined $self->content_type && $self->content_type eq $DEFAULT_CONTENT_TYPE && $content =~ /<!DOCTYPE[ ]html/xms) {
        carp 'there has been a problem - the xml is formated with an HTML doctype';
        $content =~ s/<!DOCTYPE[ ]html.*//xms;
    }

    if ($ENV{$self->save2cache_dir_var_name}) {
        my $content_type = $response->headers->header('Content-Type');
        if (!$content_type) {
            $content_type = $self->content_type;
	}
        $self->_write2cache($path, $content, $content_type);
    }

    return $content;
}


sub _write2cache {
    my ($self, $path, $content, $content_type) = @_;

    $path .= $self->_extension($content_type);

    my ($name,$dir,$suffix) = fileparse($path);
    if (-e $dir) {
        if (!-d $dir) {
            croak qq[$dir should be a directory];
	}
    } else {
        File::Path::make_path($dir);
    }

    open my $fh, q[>], $path or croak qq[Error when opening $path for writing: $ERRNO];
    $fh or croak qq[Undefined filehandle returned for $path];
    print {$fh} $content or croak qq[Failed to write to open $path: $ERRNO];
    close $fh or croak qq[Failed to close a filehandle for $path: $ERRNO];
    return;
}


sub _retry {
    my ($self, $cb, $uri) = @_;

    my $retry = 0;
    my $result;
    my $error;

    while($retry < $self->max_retries) {
        $retry++;
        eval {
            $error = q[];
            $result = $cb->();
        } or do {
            $error = $EVAL_ERROR;
        };

        if($result) {
            last;
        }

        if($retry == $self->max_retries) {
            croak q[Failed ] . $self->max_retries .
              qq[ attempts to request $uri. Giving up. Last error: $error];
        }

        sleep $self->retry_delay;
    }

    return $result;
}


sub _extension {
    my ($self, $content_type) = @_;

    my $extension = q[];
    if ($content_type) {
        my @types = split /;/smx, $content_type;
        @types = split /\//smx, $types[0];
        $extension = q[.] . $types[-1];
    }
    return $extension;
}


sub _personalise_request {
    my ($self, $req) = @_;

    my $user = q[];
    eval {$user =  getlogin;};
    if ($user) {
        $req->header('X-username' => $user);
    }
    return;
}


1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Moose::Util::TypeConstraints

=item MooseX::StrictConstructor

=item Readonly

=item Carp

=item English

=item LWP::UserAgent

=item HTTP::Request::Common

=item File::Basename

=item File::Path

=item File::Spec::Functions

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: mg8 $

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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
