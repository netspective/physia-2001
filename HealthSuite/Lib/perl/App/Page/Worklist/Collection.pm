##############################################################################
package App::Page::Worklist::Collection;
##############################################################################

use strict;
use Date::Manip;
use Date::Calc qw(:all);

use App::Configuration;
use App::ImageManager;
use App::Dialog::WorklistSetup;

use CGI::Dialog::DataNavigator;
use SQL::GenerateQuery;

use DBI::StatementManager;
use App::Statements::Worklist::WorklistCollection;

use Data::Publish;
use CGI::ImageManager;

use base qw{App::Page::WorkList};

use vars qw(
	$COLLECTIONARL
	%RESOURCE_MAP
	%PUB_COLLECTION
	$QDL
	$LIMIT
);

%RESOURCE_MAP = (
	'worklist/collection' => {
			_title =>'Collections Work List',
			_iconSmall =>'images/page-icons/worklist-collections',
			_iconMedium =>'images/page-icons/worklist-collections',
			_views => [				
				{caption => 'Work List' ,name=>'wl'},			
				{caption => 'Account Notes', name => 'accountnotes',},
				{caption => 'Setup', name => 'setup',},
				],
		},
	);

$LIMIT =250;
$QDL = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL', 'InvoiceWorkList.qdl');

$COLLECTIONARL='/worklist/collection';

########################################################
# Collection Worklist Data
########################################################


%PUB_COLLECTION = (
	name => 'obs',
	columnDefn =>
		[
			{head => '#', dataFmt => '#{auto_row_number}#',},
			{head =>'Patient ID', hAlign=> 'left',dAlign => 'left',hint=>'#{name}#',url=>'/person/#{person_id}#/profile',dataFmt=>'#{person_id}#',},			
			{head =>'Patient Name', hAlign=> 'left',dAlign => 'left',dataFmt=>'#{name}#',},
			{head =>'Invoice ID', colIdx=>'#{invoice_id}#', hAlign=> 'left',url =>'/invoice/#{invoice_id}#/summary'},
			{head => 'Event Description', dAlign => 'center', dataFmt=>'#{comments}#' },							
			{head => 'Balance' , colIdx=>'#{balance}#', dformat => 'currency', dAlign => 'center', url=>'/person/#{person_id}#/account'},
			{head => 'Age', dAlign => 'center',dataFmt=>'#{age}#'},
			{head => 'Next Appt', dAlign => 'center',colIdx=>'#{data_date_a}#'},			
			{head => 'Reck Date', dAlign => 'center',colIdx=>'#{reck_date}#'},			
			{ head => "Actions", dAlign => 'left' ,
			   dataFmt => qq{
					<A HREF="/worklist/collection/dlg-add-account-notes/#{person_id}#"
						TITLE='Add Account Notes'>
						<IMG SRC='/resources/icons/coll-account-notes.gif' BORDER=0></A>
					<A HREF="/worklist/collection/dlg-add-transfer-collection/#{person_id}#/#{invoice_id}#"
						TITLE='Transfer Patient Account'>
						<IMG SRC='/resources/icons/coll-transfer-account.gif' BORDER=0></A>
					<A HREF="/worklist/collection/dlg-add-collection-reck-date/#{person_id}#/#{invoice_worklist_id}#"
						TITLE='Add Reck Date'>
						<IMG SRC='/resources/icons/coll-reck-date.gif' BORDER=0></A>
					<A HREF="/worklist/collection/dlg-add-close-collection/#{person_id}#/#{invoice_id}#"
						TITLE='Close Account'>
						<IMG SRC='/resources/icons/coll-close-account.gif' BORDER=0></A>
                        		},
			
			},			

	],
	dnQuery => \&collectionQuery,
	#dnDrillDown => \%PUB_OBS_RESULTS,
	dnARLParams => ['invoice_id'],
	dnAncestorFmt => 'Collection Worklist',
);



########################################################
# Collection Worklist Query
########################################################
sub collectionQuery
{
	my $self = shift;
	my $date=  UnixDate('tomorrow','%d-%b-%y');
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('owner_id', 'is', $self->session('person_id'));
	my $cond2 = $sqlGen->WHERE('worklist_status', 'is','Account In Collection' );
	my $cond3 = $sqlGen->WHERE('worklist_type', 'is','Collection' );
	my $cond4 = $sqlGen->WHERE('responsible_id', 'is',$self->session('person_id') );
	my $cond5 = $sqlGen->WHERE('reck_date','lessthan',$date);
	my $cond6 = $sqlGen->WHERE('reck_date', 'isnotdefined');
	my $cond7 = $sqlGen->OR($cond5,$cond6);
	my $query = $sqlGen->AND($cond1,$cond2,$cond3,$cond4,$cond7);
	$query->outColumns(
		'owner_id',
		'person_id',
		'reck_date',
		'invoice_id',	
		'data_date_a',
		'comments',
		'name',
		'balance',
		'invoice_date',
		'age',
		'invoice_worklist_id',
		'responsible_id'
	);
	return $query;
}



########################################################
# Collection Worklist Setup View
########################################################

sub prepare_view_setup
{
	my ($self) = @_;
	
	my $dialog = new App::Dialog::WorklistSetup::Collection(schema => $self->{schema});
	$self->addContent('<br>');
	$dialog->handle_page($self, 'add');
	return 1;
}



########################################################
# Collection Worklist Account Notes View
########################################################

sub prepare_view_accountnotes
{
my ($self) = @_;

        $self->addContent(qq{
        <TABLE BORDER=0 CELLSPACING=1 CELLPADDING=0>
                                <TR VALIGN=TOP>
                                        <BR>
                                        <TD>                                                                                  
                                                #component.stp-worklist.group-account-notes# <BR>
                                        </TD>
                                </TR>
                                <TR>
                                        <TD>&nbsp;</TD>
                                </TR>
                                <TR VALIGN=TOP>
                                        <TD>
                                                #component.lookup-records#<BR>
                                        </TD>
                                        <TD>&nbsp;</TD>
                                        <TD>
                                                #component.create-records# <BR>
                                        </TD>
                                        <TD>&nbsp;</TD>
                                        <TD>
                                                #component.navigate-reports-root#
                                        </TD>
                                </TR>
                </TABLE>


        });

        return 1;
};


########################################################
# Collection Worklist , Worklist view
########################################################

sub prepare_view_wl
{
	my $self = shift;

	# Create html file tabs for each document type
	my $tabsHtml = $self->setupTabs();
	#If Refresh value has been set then try to get new invoices to add to the worklist
	if ($self->param('refresh')==1)
	{						
		$self->refreshInvoiceWorkList($self->session('user_id'),$self->session('org_internal_id'));		
	}
	# Create the work list dialog
	my $dlg = new CGI::Dialog::DataNavigator(publDefn => \%PUB_COLLECTION, 
	topHtml => $tabsHtml,
	page => $self);
	my $dlgHtml = $dlg->getHtml($self, 'add');	
	$self->addContent($dlgHtml);
}

#################################
#Refresh the collectors worklist with new data
###################################3
sub refreshInvoiceWorkList
{
	 my ($self, $collector_id, $org_internal_id) = @_;
		#First get number of active invoice on collectors worklist (enforce LIMIT)
		my $count = $STMTMGR_WORKLIST_COLLECTION->getSingleValue($self, STMTMGRFLAG_NONE,'selCollectorRecordCnt',$collector_id,		
			$org_internal_id);
		
		#Update records in InvoiceWorklist with new information (appt schedule,event description)
		$STMTMGR_WORKLIST_COLLECTION->execute($self, STMTMGRFLAG_NONE,'updCollectorRecords',$collector_id,		
			$org_internal_id) if $count >0;
			
		#Get new records for worklist but only allow up to the limited number of records in the worklist at a time
		#NOW FOR THE FUN PART
		my $pullNumber = $LIMIT - $count;	
		my $fmtDate =  UnixDate('today','%m/%d/%Y');
		my @start_Date = Decode_Date_US($fmtDate);
		my $name = $STMTMGR_WORKLIST_COLLECTION ->getRowAsHash($self, STMTMGRFLAG_NONE, 'selPersonAttribute',$collector_id,'WorkListCollectionLNameRange',$org_internal_id);
		my $minLastName = $name->{value_text}||'A';
		my $maxLastName = $name->{value_textb}||'Z';
		my $amount= $STMTMGR_WORKLIST_COLLECTION ->getRowAsHash($self, STMTMGRFLAG_NONE, 'selPersonAttribute',$collector_id,'WorkList-Collection-Setup-BalanceAmount-Range',$org_internal_id);	
		my $minAmount = $amount->{value_float}||1;
		my $maxAmount = $amount->{value_floatb}||99999;
		my $range= $STMTMGR_WORKLIST_COLLECTION ->getRowAsHash($self, STMTMGRFLAG_NONE, 'selPersonAttribute',$collector_id,'WorkList-Collection-Setup-BalanceAge-Range',$org_internal_id);	
		my $minRange = $range->{value_int}||30;
		my $maxRange = $range->{value_intb}||999;
		my $minDate=$fmtDate;
		my $maxDate=$fmtDate;
		if ($minRange)
		{
		    	my @date= Add_Delta_Days (@start_Date,"-".$minRange);
		 	$maxDate = sprintf("%02d/%02d/%04d", $date[1],$date[2],$date[0]);
		}
		if ($maxRange)
		{
		    	my @date= Add_Delta_Days (@start_Date,"-".$maxRange);
		 	$minDate = sprintf("%02d/%02d/%04d", $date[1],$date[2],$date[0]);		
		}		
		$STMTMGR_WORKLIST_COLLECTION->execute($self, STMTMGRFLAG_NONE,'pullCollectorRecords',
			$minLastName,$maxLastName,$minAmount,$maxAmount,$minDate,$maxDate,$org_internal_id,
			$collector_id,$fmtDate,$pullNumber) if $pullNumber >0;	
}


########################################################
# Setup Tabs for Collection Worklist
########################################################


sub setupTabs
{
	my $self = shift;
	my $RESOURCES = \%App::ResourceDirectory::RESOURCES;

	my $children = $self->getChildResources($RESOURCES->{'page-worklist'}->{'collection'});

	my @tabs = ();
	foreach my $child (keys %$children)
	{
		my $childRes = $children->{$child};
		my $id = $childRes->{_id};
		$id =~ s/^page\-//;
		my $caption = defined $childRes->{_tabCaption} ? $childRes->{_tabCaption} : (defined $childRes->{_title} ? $childRes->{_title} : 'caption');
		push @tabs, [ $caption, "/$id", $id ];
	}

	push @tabs, [ 'Refresh Work List', "$COLLECTIONARL?refresh=1", $COLLECTIONARL ];
	my $tabsHtml = $self->getMenu_Tabs(
		App::Page::MENUFLAGS_DEFAULT,
		'arl_resource',
		\@tabs,
		{
			selColor => '#CDD3DB',
			selTextColor => 'black',
			unselColor => '#E5E5E5',
			unselTextColor => '#555555',
			highColor => 'navy',
			leftImage => 'images/design/tab-top-left-corner-white',
			rightImage => 'images/design/tab-top-right-corner-white'
		}
	);

	return [qq{<br><div align="left"><table border="0" cellspacing="0" cellpadding="0" bgcolor="white"><tr>$tabsHtml</tr></table></div>}];
}


########################################################
# Handle the page display
########################################################


sub handleARL
{
        my ($self, $arl, $params, $rsrc, $pathItems) = @_;

        unless($self->arlHasStdAction($rsrc, $pathItems, 1))
        {
                $self->param('_pm_view', $pathItems->[1] || 'wl');
        };
        
        #If the refresh option is not set then set refresh param to zero
        unless($params=~m/refresh=1/)
        {
        	$self->param('refresh',0) ;
        }
        $self->param('_dialogreturnurl', $COLLECTIONARL);
        $self->printContents();
        return 0;
}




sub getContentHandlers
{
     return ('prepare_view_$_pm_view=wl$');
}


sub initialize
{
        my $self = shift;
        $self->SUPER::initialize(@_);

        $self->addLocatorLinks(
                ['Collection', $COLLECTIONARL],
        );

        # Check user's permission to page
        my $activeView = $self->param('_pm_view');
        if ($activeView)
        {
                unless($self->hasPermission("page/worklist/collection"))
                {
                        $self->disable(qq{<br>
                                You do not have permission to view this information.
                                Permission page/worklist/verify is required.
                                Click <a href='javascript:history.back()'>here</a> to go back.
                        });
                }
        }
}


1;
