##############################################################################
package App::Component::WorkList::Collection;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;

use Date::Calc qw(:all);
use Date::Manip;
use DBI::StatementManager;
use App::Statements::Component::Scheduling;
use App::Statements::Person;
use App::Statements::Scheduling;
use App::Schedule::Utilities;
use Data::Publish;
use Exporter;
use App::Statements::Worklist::WorklistCollection;

use vars qw(@ISA %RESOURCE_MAP );
@ISA   = qw(CGI::Component Exporter);

%RESOURCE_MAP = (
	'worklist-collection' => {
		_class => new App::Component::WorkList::Collection(),
		},
	);
my $ACCOUNT_OWNER = App::Universal::TRANSTYPE_ACCOUNT_OWNER;
my $ACTIVE   = App::Universal::TRANSSTATUS_ACTIVE;
my $INACTIVE = App::Universal::TRANSSTATUS_INACTIVE;
my $LIMIT = 251;
sub initialize
{
	my ($self, $page) = @_;
	my $layoutDefn = $self->{layoutDefn};
	my $arlPrefix = '/worklist/collection';

	$layoutDefn->{frame}->{heading} = "Work List";
	$layoutDefn->{style} = 'panel';
	
}

sub getHtml
{
	my ($self, $page) = @_;

	$self->initialize($page);
	createLayout_html($page, $self->{flags}, $self->{layoutDefn}, $self->getComponentHtml($page));
}

sub getComponentHtml
{
	my ($self, $page) = @_;
	
	my $selectedDate = $page->param('_seldate') || 'today';
	$selectedDate = 'today' unless ParseDate($selectedDate);
	my $todayDate =  UnixDate('today','%m/%d/%Y');
	my $fmtDate = UnixDate($selectedDate, '%m/%d/%Y');

	my $facility_id = $page->session('org_id');
	my $user_id = $page->session('user_id');
	
	my ($time1, $time2);
	
	if ($page->session('showTimeSelect'))
	{
		$time1 = $page->session('time1') || '12:00am';
		$time2 = $page->session('time2') || '11:59pm';
	}
	else
	{
		$time1 = $page->session('time1') || 30;
		$time2 = $page->session('time2') || 120;
	}

	my @start_Date = Decode_Date_US($fmtDate);
	my @end_Date   = Add_Delta_Days (@start_Date, 1);
	my $startDate = sprintf("%02d/%02d/%04d", $start_Date[1],$start_Date[2],$start_Date[0]);
	my $endDate   = sprintf("%02d/%02d/%04d", $end_Date[1],$end_Date[2],$end_Date[0]);
	
	my $startTime = $startDate . " $time1";
	my $endTime   = $startDate . " $time2";

	my @data = ();
	my $html;
	my $pub =
	{
		columnDefn =>
			[
				{colIdx => 0, head => 'Patient ID', hAlign=> 'left',dAlign => 'left',dataFmt=>"<A HREF = '/person/#0#/profile'>#0#</A>",},
				{colIdx => 1, head => 'Invoice ID', hAlign=> 'left',url =>'/invoice/#1#/summary'},
				{colIdx => 2, head => 'Event Description', dAlign => 'center'},							
				{colIdx => 3, head => 'Balance' ,dAlign => 'center',dformat => 'currency', url=>'/person/#0#/account'},
				{colIdx => 4, head => 'Age', dAlign => 'center'},
				{colIdx => 5, head => 'Next Appt', dAlign => 'center'},			
				{colIdx => 6, head => 'Reck Date', dAlign => 'center'},			
				{colIdx => 7, head => "Actions", dAlign => 'center'},			
			
		],
	};	

	my $name = $STMTMGR_WORKLIST_COLLECTION ->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonAttribute',$page->session('user_id'),'WorkListCollectionLNameRange',$page->session('org_internal_id'));
	my $minLastName = $name->{value_text}||'A';
	my $maxLastName = $name->{value_textb}||'Z';
	my $amount= $STMTMGR_WORKLIST_COLLECTION ->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonAttribute',$page->session('user_id'),'WorkList-Collection-Setup-BalanceAmount-Range',$page->session('org_internal_id'));	
	my $minAmount = $amount->{value_float}||1;
	my $maxAmount = $amount->{value_floatb}||99999;
	my $range= $STMTMGR_WORKLIST_COLLECTION ->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPersonAttribute',$page->session('user_id'),'WorkList-Collection-Setup-BalanceAge-Range',$page->session('org_internal_id'));	
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

	#Get new records on the worklist
	my $person = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($page, STMTMGRFLAG_NONE,'selWorkListPop',
			$minLastName,$maxLastName,$minAmount,$maxAmount,$minDate,$maxDate,$page->session('org_internal_id'),
			$page->session('user_id'),$fmtDate);
	my $count=0;
	foreach (@$person)
	{
		
		next if $count >$LIMIT;
		my @reck_Date = Decode_Date_US($_->{reck_date});
		next if $_->{reck_date} && Delta_Days($reck_Date[0],$reck_Date[1],$reck_Date[2],$start_Date[0],$start_Date[1],$start_Date[2])<0;
		$count++;

		$_->{trans_id} = $page->schemaAction(   'Transaction', 'add',                        
		                trans_owner_id =>$_->{person_id} || undef,
		                provider_id => $page->session('user_id') ||undef,
		                trans_owner_type => 0, 
		                 caption =>'Account Owner',
		                trans_subtype =>'Owner',
		                trans_status =>$ACTIVE,
		                trans_type => $ACCOUNT_OWNER,  
		                initiator_type =>0,
		                initiator_id =>$page->session('user_id'), 	
		                billing_facility_id => $page->session('org_internal_id'),
				data_num_a => $_->{invoice_id} ,
				invoice_id => $_->{invoice_id} ,
		
                )if (! defined $_->{trans_id} &&  $fmtDate eq $todayDate);			
                
	        my @invoice_date = Decode_Date_US($_->{invoice_date});
               	my @range_Date = Decode_Date_US($fmtDate); 
               	$_->{age} = Delta_Days($invoice_date[0],$invoice_date[1],$invoice_date[2],$range_Date[0],$range_Date[1],$range_Date[2]);
		$_->{age} = $_->{age} >= 0 ? $_->{age}  : 'N/A';								


			
                #Remove any accounts with a balance of zero that do have a reck date and the min range value > 0
                if($_->{balance} <= 0 && !$_->{reck_date} && $_->{min_amount} > 0  )
                {
                	#Mark record as inactive
			$page->schemaAction
			(
				'Transaction', 'update',                        
				trans_id =>$_->{trans_id},
			        trans_status => $INACTIVE	,			
				trans_subtype => 'Account Closed by System',			
                	);

			#Obtain account/invoice information for collectors that 
			#transferd there account to this user
                	my $transferData = $STMTMGR_WORKLIST_COLLECTION->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selAccountTransferIdById',$_->{person_id},$page->session('user_id'));                	
			foreach my $data (@$transferData)         
	                {
				#Mark account inactive 
				$page->schemaAction
				(
					'Transaction', 'update',                        
					trans_id =>$data->{trans_id},
	                		trans_status => $INACTIVE,	,			
					trans_subtype => 'Account Closed by System',			
	                	);                	
	                }                	                
                	next;
                }
		my @rowData = (							
			$_->{person_id},
			$_->{invoice_id},			
			$_->{description},					
			$_->{balance},
			$_->{age},
			$_->{appt},
			$_->{reck_date},			
			qq{<nobr>
				<A HREF="/worklist/collection/dlg-add-account-notes/$_->{person_id}"
					TITLE='Add Account Notes'>
					<IMG SRC='/resources/icons/coll-account-notes.gif' BORDER=0></A>
				<A HREF="/worklist/collection/dlg-add-transfer-account/$_->{person_id}/$_->{trans_id}"
					TITLE='Transfer Patient Account'>
					<IMG SRC='/resources/icons/coll-transfer-account.gif' BORDER=0></A>
				<A HREF="/worklist/collection/dlg-add-reck-date/$_->{person_id}/$_->{reck_id}"
					TITLE='Add Reck Date'>
					<IMG SRC='/resources/icons/coll-reck-date.gif' BORDER=0></A>
				<A HREF="/worklist/collection/dlg-add-close-account/$_->{person_id}/$_->{trans_id}"
					TITLE='Close Account'>
					<IMG SRC='/resources/icons/coll-close-account.gif' BORDER=0></A>
			</nobr>}, 


		);

		push(@data, \@rowData);
	}

	$html .= createHtmlFromData($page, 0, \@data,$pub);

	$html = "<i style='color=red'>No Collection data found.  Please setup Resource and Facility selections.</i> <P>" 
		if (scalar @{$person} < 1);

	return $html;
}

sub formatStamp
{
	my ($stamp) = @_;

	if ($stamp =~ /\d\d\/\d\d\/\d\d\d\d/)
	{
		my ($day, $time) = split(/\s/, $stamp);
		return qq{$day $time};
	}
	else
	{
		return "<b>$stamp</b>";
	}

}


1;
