##############################################################################
package XAP::Component::CommandProcessor;
##############################################################################

use strict;
use Exporter;
use XAP::Component;
use XAP::Component::Command;

#
# the following commands will auto-register themselves
#
use XAP::Component::Command::Query;
use XAP::Component::Command::Schema;
use XAP::Component::Command::DialogPostExecute;
use XAP::Component::Command::ShowDialogFields;

use base qw(XAP::Component Exporter);

sub init
{
	my XAP::Component::CommandProcessor $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	
	$self;
}

sub applyXML
{
	my XAP::Component::CommandProcessor $self = shift;
	my ($tag, $content) = @_;

	$self->SUPER::applyXML(@_);

	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);	
	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		next unless $chTag;
		
		if(my XAP::Component::Command $cmd = XAP::Component->createClassFromXMLTag($chTag, $chContent))
		{
			$self->addChildComponent($cmd, ADDCHILDCOMPFLAGS_DEFAULT);
		}
		else
		{
			die "command '$chTag' not found";
		}
	}
	$self;
}

sub execute
{
	my XAP::Component::CommandProcessor $self = shift;
	my ($page, $flags, %params) = @_;
	
	return '' unless $self->{childCompList};
	
	my $output = '';
	if($params{dialog})
	{
		my $dlgFlags = $params{dialogFlags};
		my XAP::Component::Command $cmd;
		foreach $cmd (@{$self->{childCompList}})
		{
			$output .= $cmd->execute($page, $flags, \%params) if (! $cmd->{dialogFlags}) || ($cmd->{dialogFlags} && ($dlgFlags & $cmd->{dialogFlags}));
		}	
	}
	else
	{
		foreach my $cmd (@{$self->{childCompList}})
		{
			$output .= $cmd->execute($page, $flags, \%params);
		}
	}	
	return $output;
}

1;