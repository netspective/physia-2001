##############################################################################
package App::Page::Search::AdhocQuery;
##############################################################################

use strict;
use App::Page::Search;
#use App::Universal;
use DBI::StatementManager;
use App::Statements::Scheduling;

use vars qw(@ISA);
@ISA = qw(App::Page::Search);

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;

	$self->setFlag(App::Page::PAGEFLAG_ISPOPUP) if $rsrc eq 'lookup';
	return $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems);
}

sub getForm
{
	my ($self, $flags) = @_;

	return ('Adhoc Query', qq{
		<textarea name=query rows=10 cols=80 style="font-family:Lucida; font-size:8pt">} .
		qq{@{[ $self->param('query')]}
		</textarea>
		<input type=submit name="execute" value="Go">
	});
}

sub execute
{
	my ($self) = @_;

	my $query = App::Data::Manipulate::trim($self->param('query'));
	
	if ($query =~ /^alter/i || $query =~ /^select/i)
	{
		$self->addContent($STMTMGR_SCHEDULING->createHtml($self, STMTMGRFLAG_DYNAMICSQL, $query));
	}
	else
	{
		$self->addContent("<b style='color:red'>Sorry.  Can't execute that command.</b>");
	}

	return 1;
}

1;
