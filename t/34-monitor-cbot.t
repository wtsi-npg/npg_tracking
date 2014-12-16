use strict;
use warnings;

use English qw(-no_match_vars);
use XML::LibXML;

use Test::More tests => 12;
use Test::Exception::LessClever;

use t::dbic_util;
use t::useragent;

local $ENV{dev} = 'test';
my $mock_schema = t::dbic_util->new->test_schema();

my $test;
my $dummy_cbot   = 'cBot1';
my $dummy_url    = 'no_such_url';

my $xml_doc = XML::LibXML->createDocument();
my $element = $xml_doc->createElement('count_me');
$element->addChild( $xml_doc->createTextNode('Example') );
$xml_doc->addChild($element);

my $user_agent = t::useragent->new( { is_success => 1, } );


use_ok('Monitor::Cbot');


dies_ok { $test = Monitor::Cbot->new_with_options() } 'Require a cbot name';

$test = Monitor::Cbot->new(
        ident       => $dummy_cbot,
        _schema     => $mock_schema,
        _user_agent => $user_agent,
);

is( $test->host_name(), q(cBot1.internal.sanger.ac.uk),
    'Construct network host name using intrument_comp' );

isa_ok( $test->user_agent(), 't::useragent', 'Over-ridden user agent' );

throws_ok { $test->_fetch() } qr/url required as argument/ms,
    'Require URL argument';


{
    my $test2 = Monitor::Cbot->new(
                    ident   => $dummy_cbot,
                    _schema => $mock_schema,
    );

    throws_ok { $test2->_fetch($dummy_url) }
              qr/^fetch[ ]$dummy_url[ ]failed:[ ]/msx,
              'Croak on failure to get';
}

lives_ok { $test->_fetch($dummy_url) } 'Otherwise succeed';


throws_ok { $test->get_element_content() }
          qr/No XML supplied/ms,
          'Require an argument';

throws_ok { $test->get_element_content('wrong kind of argument') }
    qr/First[ ]argument[ ]is[ ]not[ ]a[ ]XML::LibXML::Document[ ]object/msx,
    'Specifically an XML::LibXML::Document object argument';


throws_ok { $test->get_element_content($xml_doc) }
          qr/No[ ]tag[ ]name[ ]supplied/msx,
          'Require a tag name also';

is(
    $test->get_element_content( $xml_doc, 'dummy' ),
    q{},
    'Empty string for no match'
);


is(
    $test->get_element_content( $xml_doc, 'count_me' ),
    q{Example},
    'Return content otherwise'
);

1;
