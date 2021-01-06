package t::instrument;
use warnings;
use strict;

sub new {
	my ($class, @args) = @_;

	my $self = {@args};
	bless $self, $class;

	return $self;
}

sub name {
	my ($self) = @_;
	return $self->{name};
}
1;