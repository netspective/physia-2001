##############################################################################
package App::Dialog::LabOrder;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use App::Statements::Org;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use App::Statements::LabTest;

use Date::Manip;
use Text::Abbrev;
use App::Universal;

use vars qw(@ISA %RESOURCE_MAP %PROCENTRYABBREV %RESOURCE_MAP %ITEMTOFIELDMAP %CODE_TYPE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'lab-order' => {_arl_add => ['person_id', 'org_id'],
	_arl_update => ['lab_order_id']},
);


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'catalog', heading => '$Command Lab Order');

	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(

		new CGI::Dialog::Field( caption => 'Lab Company', preHtml=>'<B>' , postHtml=>'</B>', name => 'lab_name', type=>'text',options=>FLDFLAG_READONLY |FLDFLAG_REQUIRED ),
		new App::Dialog::Field::Person::ID(
						types => ['Patient'],
						name => 'person_id', 
						caption => 'Patient ID',
						options => FLDFLAG_REQUIRED),
		new App::Dialog::Field::Person::ID(
						name => 'provider_id', 
						caption => 'Ordering Provider ID',
						types => ['Physician'],
						incSimpleName=>1,
						options => FLDFLAG_REQUIRED),								
		new CGI::Dialog::Field( name => 'org_internal_id', type=>'hidden'),		
		new CGI::Dialog::Field( name => 'org_id', type=>'hidden'),						
		new CGI::Dialog::MultiField(caption =>'Date/Time Ordered', name => 'order_date_time',
			fields => [
					new CGI::Dialog::Field( caption => 'Date Ordered', name => 'order_date', type=>'date'),
					new CGI::Dialog::Field( caption => 'Time Ordered', name => 'order_time', type=>'time'),
				 ]),

		new CGI::Dialog::MultiField(caption =>'Date/Time to be Done', name => 'done_date_time',
			fields => [
					new CGI::Dialog::Field( caption => 'Date to Done', name => 'done_date', type=>'date',defaultValue=>''),
					new CGI::Dialog::Field( caption => 'Time Ordered', type=>'time',name => 'done_time', ),
				 ]),
		new CGI::Dialog::Field( caption => 'Diagnosis', name => 'icd9', type=>'text',size=>'30',
			findPopup => '/lookup/icd',
			findPopupAppendValue=>','),		
		new CGI::Dialog::Field(
			name => 'labs',
			style => 'multicheck',
			type => 'select',
			caption => '',
			multiDualCaptionLeft => 'Available Labs',
			multiDualCaptionRight => 'Selected Labs',
			size => '5',
			fKeyStmtMgr => $STMTMGR_LAB_TEST,
			fKeyStmt => 'sel_available_labs',
			fKeyStmtBindFields => ['org_internal_id'],
			caption=>'Labs',	
		),	
		new CGI::Dialog::Field(
			name => 'xray',
			style => 'multicheck',
			type => 'select',
			caption => '',
			multiDualCaptionLeft => 'Available Radiology',
			multiDualCaptionRight => 'Selected Radiology',
			size => '5',
			fKeyStmtMgr => $STMTMGR_LAB_TEST,
			fKeyStmt => 'sel_available_xray',
			fKeyStmtBindFields => ['org_internal_id'],
			caption=>'Radiology',
		),	
		new CGI::Dialog::Field(
			name => 'other',
			style => 'multicheck',
			type => 'select',
			caption => '',
			multiDualCaptionLeft => 'Available Other',
			multiDualCaptionRight => 'Selected Other',
			size => '5',
			fKeyStmtMgr => $STMTMGR_LAB_TEST,
			fKeyStmt => 'sel_available_other',
			fKeyStmtBindFields => ['org_internal_id'],
			caption=>'Other',
		),		
		new CGI::Dialog::MultiField(caption =>'Comments to Lab/Patient', name => 'comments',
			fields => [		
		new CGI::Dialog::Field(caption => 'Comments to Lab', rows=>2,name => 'lab_comments', type=>'memo'),		
		new CGI::Dialog::Field(caption => 'Comments to Patient',rows=>2, name => 'patient_comments', type=>'memo'),			
		]),		
		new CGI::Dialog::Field(type => 'enum',style=>'radio',
			defaultValue=>'0', 
			enum=>'Lab_Order_Priority', 
			name => 'priority', 
			caption => 'Priority',
			),	
		new App::Dialog::Field::Person::ID(name => 'result_id', caption => 'Call Result to'),												

		new CGI::Dialog::MultiField(caption =>'Instructions to Patient', name => 'ins_patient_comm',
		fields => [		
		new CGI::Dialog::Field(caption => 'Instructions to Patient',size=>60, name => 'ins_patient', type=>'text'),	
		new CGI::Dialog::Field(type => 'enum',style=>'radio',
			defaultValue=>'0',
			enum=>'Lab_Order_Transmission',
			name => 'comm', 
			caption => 'Priority',
			),		
		]),
		new CGI::Dialog::Field(
						name => 'lab_order_id',
						type => 'hidden',
					),		
	);

	$self->{activityLog} =
	{
		scope =>'offering_catalog',
		key => "#field.catalog_id#",
		data => "Order Entry"
	};
	$self->addFooter(new CGI::Dialog::Buttons( cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}




sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
	my $isNurse = grep {$_ eq 'Nurse'} @{$page->session('categories')};
	my $isPhysician = grep {$_ eq 'Physician'} @{$page->session('categories')};
};	
sub populateData_add
{
	my ($self, $page, $command, $flags) = @_;
	$page->field('person_id',$page->param('person_id'));	
	$page->field('org_id',$page->param('org_id'));	
	$page->field('org_internal_id',$page->param('org_id'));		
	my $orgData = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selOrg', $page->session('org_internal_id'), $page->param('org_id')||undef);	
	$page->field('org_internal_id',$orgData->{org_internal_id});	
	$page->field('lab_name',$orgData->{name_primary});	
	$page->field('order_time',UnixDate('now', '%I:%M %p'));
	
	my $isPhysician = grep {$_ eq 'Physician'} @{$page->session('categories')};
	if($isPhysician)
	{
		$page->field('provider_id',$page->session('person_id'));
	}
	else
	{	#Try and get primary physician for patient
		my $phy =$STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE,'selPrimaryPhysicianOrProvider',$page->field('person_id'));
		$page->field('provider_id',$phy->{value_text});
	}
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	
	my $labData = $STMTMGR_LAB_TEST->getRowAsHash($page, STMTMGRFLAG_NONE, 'selLabOrderByID', $page->param('lab_order_id')||undef);		
	$page->field('person_id',$labData->{person_id});	
	$page->field('org_id',$labData->{org_id});	
	$page->field('org_internal_id',$labData->{lab_internal_id});		
	$page->field('lab_name',$labData->{name_primary});	
	$page->field('icd9',$labData->{icd});
	$page->field('provider_id',$labData->{provider_id});
	$page->field('lab_comments',$labData->{lab_comments});
	$page->field('patient_comments',$labData->{patient_comments});
	$page->field('ins_patient',$labData->{instructions});
	$page->field('result_id',$labData->{result_id});	
	$page->field('comm',$labData->{communication});		
	$page->field('priority',$labData->{priority});		
	$page->field('lab_order_id',$page->param('lab_order_id'));
	#Get Lab Data	
	my $test=$STMTMGR_LAB_TEST->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selTestEntryByParentId',$page->param('lab_order_id')||undef);		
	
	my @labs = ();	
	my @xray = ();		
	my @other=();
	
	foreach(@$test)
	{
		if($_->{entry_type}==300)
		{
			push(@labs,$_->{entry_id});
		}
		elsif($_->{entry_type}==310)		
		{
			push(@xray,$_->{entry_id});		
		}
		elsif($_->{entry_type}==999)
		{
			push(@other,$_->{entry_id});		
		}
	}
	$page->field('labs',@labs);
	$page->field('xray',@xray);
	$page->field('other',@other);
}
sub populateData_remove
{
	populateData_update(@_);
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $patientId = $page->field('person_id');
	my $providerId = $page->field('provider_id');
	my $labInternalId = $page->field('org_internal_id');	
	my $dateOrder = $page->field('order_date') . $page->field('order_time');
	my $dateDone = $page->field('done_date') . $page->field('done_time');
	my $icd9 = $page->field('icd9');
	my @labs = $page->field('labs');
	my @xray = $page->field('xray');
	my @other = $page->field('other');
	my $labComments = $page->field('lab_comments');
	my $patComments = $page->field('patient_comments');	
	my $priority = $page->field('priority');
	my $comm = $page->field('comm');	
	my $ins = $page->field('ins_patient');
	my $resultId = $page->field('result_id');
	my $orderId = $page->field('lab_order_id');
	my $isPhysician = grep {$_ eq 'Physician'} @{$page->session('categories')};
	
	#Create Lab Order Record	
	my $labOrderId=$page->schemaAction (
		'Lab_Order', $command,
		lab_order_id=>$orderId ,
		person_id => $patientId,
		lab_internal_id => $labInternalId,
		date_done => $dateDone,
		date_order => $dateOrder,
		icd => $icd9,
		lab_comments  => $labComments,
		patient_comments => $patComments,
		priority => $priority, 
		communication => $comm,
		instructions=>$ins,
		provider_id =>$providerId,
		result_id => $resultId,		
		lab_order_status=>1,
		org_internal_id =>$page->session('org_internal_id'),
	);	

	$labOrderId = $orderId ? $orderId : $labOrderId; 
	#Create Apporoval Message if needed
	#$self->addApprovalRequest($page,$command,$flags,$labOrderId);# unless $isPhysician;	
	
	#Get All X-ray Data need the options values	
	my $labsData = $STMTMGR_LAB_TEST->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selXrayOrder',$labOrderId);
	

	#Delete All Lab Entries and Re_Create
	my $test=$STMTMGR_LAB_TEST->execute($page,STMTMGRFLAG_NONE,'delLabEntriesByOrderID',$labOrderId);
	
	#Store Xray tests	
	my $hasXray=0;	
	foreach my $value (@xray)
	{
		my $row='';	
		for (@$labsData)
		{	
			if($_->{test_entry_id} eq $value)
			{
				$row=$_->{options};
			};			
		};		
		$page->schemaAction(
		'Lab_Order_Entry','add',
		parent_id =>$labOrderId,
		test_entry_id=>$value,
		options=>$row);	
		$hasXray=1;		
	};	
	
	#Store Lab Tests
	for (@labs)
	{
		$page->schemaAction(
		'Lab_Order_Entry','add',
		parent_id =>$labOrderId,
		test_entry_id=>$_,);			
	};
	


	#Store Other Tests	
	for (@other)
	{
		$page->schemaAction(
		'Lab_Order_Entry','add',
		parent_id =>$labOrderId,
		test_entry_id=>$_,);				
	};
	$page->param('_dialogreturnurl', "/person/%param.person_id%/dlg-add-lab-order-option?lab_order_id=$labOrderId&home=%param.home%")if $hasXray;
	$self->handlePostExecute($page, $command, $flags, undef);
	return '';
}


sub addApprovalRequest
{
	my ($self,$page, $command, $flags,$id) = @_;
	
	my $patient = $page->field('person_id');
	
	my $value = App::Universal::MSGSUBTYPE_LABORDER;
	my $msgDlg = new App::Dialog::Message();
	$msgDlg->sendMessage($page, 
		subject => 'Lab Approval Request',
		type=>$value,
		message => $page->session('person_id') . " is seeking approval for a lab.\n\nPatient: $patient\n Lab Order ID: $id\n",
		to => $page->field('provider_id'),
		rePatient => $page->field('person_id'),
		cc => $page->field('result_id'),
		doc_data_a => $id,
	);
}

1;

##############################################################################
package App::Dialog::XrayOption;
##############################################################################
use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use App::Statements::Org;
use Carp;
use CGI::Dialog;
use App::Page;
use CGI::Validator::Field;
use App::Dialog::Field::Person;
use App::Statements::LabTest;

use Date::Manip;
use Text::Abbrev;
use App::Universal;

use vars qw(@ISA  %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'lab-order-option' => {_arl_add=> ['lab_order_id'],
	},
);


sub new
{

	my ($self) = CGI::Dialog::new(@_, id => 'catalog', heading => '$Command Lab Order');

	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
		
	#determine how many x-ray options needed
	
	my $labOrderId=$GLOBAL_PAGEREF->param('lab_order_id');
	my $countXray=$STMTMGR_LAB_TEST->getSingleValue($GLOBAL_PAGEREF,STMTMGRFLAG_NONE,'countXray',$labOrderId);
	
	my @fields=();
	for (my $loop=0;$loop<$countXray;$loop++)
	{
		my $post=$loop+1;
		push(@fields,
				new CGI::Dialog::Subhead(
				heading => "X Ray Options",
				name => "heading_$loop",
			),);
		push(@fields,
				new CGI::Dialog::Field( caption => 'Test Name', 
							name => "test_name_$loop", 
							type=>'hidden',
							options=>FLDFLAG_READONLY|FLDFLAG_REQUIRED),);								
		push(@fields,
				new CGI::Dialog::Field( caption => 'Test Name', 
							name => "test_entry_id_$loop", 
							type=>'hidden',
							options=>FLDFLAG_READONLY|FLDFLAG_REQUIRED),);															
		push(@fields,
				new CGI::Dialog::Field(
					name => "sec_$loop",
					style => 'radio',
					type => 'select',
					caption => '',
					size => '5',
					caption=>'Section',
					selOptions=>"Right:0;Left:1;Bilateral:2",			
				),	);	
		push(@fields,
				new CGI::Dialog::Field(
					name => "iv_$loop",
					style => 'radio',
					type => 'select',
					caption => '',
					size => '5',
					caption=>'IV',
					selOptions=>"without:3;with:4",			
				),	);						
		push(@fields,
				new CGI::Dialog::Field(
					name => "contrast_$loop",
					style => 'radio',
					type => 'select',
					caption => '',
					size => '5',
					caption=>'Contrast',
					selOptions=>"without:5;with:6",			
				),	);			
							
	};
		
	$self->addContent(
			@fields,	
			);
	$self->addFooter(new CGI::Dialog::Buttons( cancelUrl => $self->{cancelUrl} || undef));

	return $self;			
};


sub populateData
{
	my ($self, $page, $command, $flags) = @_;
	my $labOrderId=$GLOBAL_PAGEREF->param('lab_order_id');	
	my $data=$STMTMGR_LAB_TEST->getRowsAsHashList($GLOBAL_PAGEREF,STMTMGRFLAG_NONE,'selXrayOrder',$labOrderId);	
	my $count=0;
	foreach(@$data)
	{	
		
		$page->field("test_name_$count",$_->{name});
		$page->field("test_entry_id_$count",$_->{lab_entry_id});	
		my $field = $self->getField("heading_$count");
		$field->{heading}=$_->{name};
		
		#Get Option for entry selLabEntryOptions
		my $options=$STMTMGR_LAB_TEST->getRowsAsHashList($GLOBAL_PAGEREF,STMTMGRFLAG_NONE,'selLabEntryOptions',$_->{lab_entry_id}||undef);	
		foreach my $opt (@$options)
		{
			if($opt->{member_name}==0||$opt->{member_name}==1||$opt->{member_name}==2)
			{
				$page->field("sec_$count",$opt->{member_name});
			}
			elsif($opt->{member_name}==3|| $opt->{member_name}==4 )
			{
				$page->field("iv_$count",$opt->{member_name});			
			}
			elsif($opt->{member_name}==5 || $opt->{member_name}==6 )
			{
				$page->field("contrast_$count",$opt->{member_name});						
			}
		};
		$count++;
	}

};

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	my $labOrderId=$GLOBAL_PAGEREF->param('lab_order_id');
	my $countXray=$STMTMGR_LAB_TEST->getSingleValue($GLOBAL_PAGEREF,STMTMGRFLAG_NONE,'countXray',$labOrderId);	
	for (my $loop=0;$loop<$countXray;$loop++)
	{
		my $list= '';
		$list = $page->field("sec_$loop");
		$list .= $list ne '' ? "," . $page->field("iv_$loop") : $page->field("iv_$loop");
		$list .= $list  ne '' ? "," . $page->field("contrast_$loop") : $page->field("contrast_$loop");		
		$page->schemaAction(
		'Lab_Order_Entry','update',
		entry_id=>$page->field("test_entry_id_$loop"),
		options=>$list) if $list ne '';		
	};
	$page->param('_dialogreturnurl', "/person/%param.person_id%/chart");
	$self->handlePostExecute($page, $command, $flags, undef);
	return '';
	
};

1;
