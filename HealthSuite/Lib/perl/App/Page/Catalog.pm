##############################################################################
package App::Page::Catalog;
##############################################################################

use strict;
use App::Page;
use App::Universal;
use Exporter;
use App::ImageManager;
use DBI::StatementManager;
use App::Statements::Search::Catalog;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter App::Page);

use enum qw(BITMASK:CATALOGTREEFLAG_ SHOWDESCRIPTIONS HIGHLACTIVE);

sub createCatalogTableRows
{
	my ($self, $flags, $selectedId, $records) = @_;
	unless($records)
	{
		$records = $STMTMGR_CATALOG_SEARCH->getRowsAsHashTree($self, STMTMGRFLAG_NONE, ['sel_catalogs_all', 'catalog_id', 'parent_catalog_id'], $self->session('org_id'));
	}
	return unless @$records;

	my @html = ();
	my $count = 0;
	foreach (@$records)
	{
		$count++;
		my $id = $_->{catalog_id};
		my $kidsTable = '';
		my $isSelected = $_->{catalog_id} eq $selectedId;
		if(my $kids = $_->{_kids})
		{
			$kidsTable = '<TABLE CELLSPACING=0 CELLPADDING=2>' . $self->createCatalogTableRows($flags, $selectedId, $kids) . '</TABLE>';
		}
		push(@html,
		qq{
			<TR VALIGN=TOP>
				<TD ALIGN=RIGHT><FONT FACE=ARIAL,HELVETICA SIZE=2 COLOR=GREEN>$_->{entries_count}</FONT></TD>
				<TD>
					<FONT FACE=ARIAL,HELVETICA SIZE=2>
					<A HREF='/catalog/$id' title='$id' style="text-decoration:none">@{[ $isSelected && $flags & CATALOGTREEFLAG_HIGHLACTIVE ? "<FONT COLOR=DARKRED SIZE=+1><B>$_->{caption}</B></FONT>" : $_->{caption} ]}</A>
					@{[ $flags & CATALOGTREEFLAG_SHOWDESCRIPTIONS && $_->{description} ? "<BR><FONT FACE=ARIAL,HELVETICA SIZE=1 COLOR=GREEN><I>$_->{description}</I></FONT>" : '' ]}
					$kidsTable
					</FONT>
				</TD>
			</TR>
		});
	}
	return join('', @html);
}

sub prepare_tree
{
	my ($self) = @_;
	$self->addContent(
		$STMTMGR_CATALOG_SEARCH->createHierHtml($self, STMTMGRFLAG_NONE, ['sel_catalogs_all', 0, 4], [$self->session('org_id')])
		);
	return 1;

	my $catalogTreeRows = $self->createCatalogTableRows(CATALOGTREEFLAG_HIGHLACTIVE);
	$self->addLocatorLinks(
			['All', '', undef, App::Page::MENUITEMFLAG_FORCESELECTED],
		);
	push(@{$self->{page_content_header}}, qq{
		<TABLE WIDTH=100% CELLSPACING=0 CELLPADDING=3 BORDER=0>
			<TR VALIGN=BOTTOM>
			<TD>
				<FONT FACE="Arial,Helvetica" SIZE=5 COLOR=NAVY>
					<B>Available Fee Schedules</B>
				</FONT>
			</TD>
			<TD ALIGN=RIGHT VALIGN=CENTER>
				<FONT FACE="Arial,Helvetica" SIZE=2>
				<!--- TABS COMING SOON -->
				</FONT>
			</TD>
			</TR>
		</TABLE>
		});
	$self->addContent(qq{
		<TABLE cellspacing=0 cellpadding=2 border=0>
			$catalogTreeRows
		</TABLE>
		});

	return 1;
}

sub prepare
{
	my $self = shift;
	my @pathItems = $self->param('arl_pathItems');
	my $catalogId = $pathItems[0] || '';

	return $self->prepare_tree() unless $catalogId;

	$self->addLocatorLinks(
			[$catalogId, '', undef, App::Page::MENUITEMFLAG_FORCESELECTED],
		);
	$self->addContent(
		$STMTMGR_CATALOG_SEARCH->createHtml($self, STMTMGRFLAG_NONE, 'sel_catalog_items_all', [$catalogId])
		);

	#my $entriesSth = $STMTMGR_CATALOG_SEARCH->execute($self, STMTMGRFLAG_NONE, 'sel_catalog_items_all', $catalogId);
	#my $count = 0;
	#my @entriesHtml = ();
	#while(my $row = $entriesSth->fetch())
	#{
	#	$count++;
	#	push(@entriesHtml, qq{
	#		<TR>
	#			<TD align=right><FONT FACE="Arial,Helvetica" SIZE=2>$count</FONT></TD>
	#			<TD><FONT FACE="Arial,Helvetica" SIZE=2><A HREF='/update/catalogitem/$row->[0]' title='$row->[0]'>$row->[1]</A></FONT></TD>
	#			<TD align=right><FONT FACE="Arial,Helvetica" SIZE=2>\$$row->[2]</FONT></TD>
	#		</TR>
	#		});
	#}
	#$self->addContent('<TABLE>' . join('', @entriesHtml) . '</TABLE>');

	return 1;
}

sub handleARL
{
	my ($self, $arl, $params, $rsrc, $pathItems) = @_;
	return 0 if $self->SUPER::handleARL($arl, $params, $rsrc, $pathItems) == 0;

	$self->addLocatorLinks(
			['<IMG SRC="/resources/icons/home-sm.gif" BORDER=0> Home', '/home'],
			['Practice', '/practice'],
			['Fee Schedules', '/catalog'],
		);
	$self->printContents();

	return 0;
}

1;
