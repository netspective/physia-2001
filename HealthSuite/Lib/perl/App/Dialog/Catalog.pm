##############################################################################
package App::Dialog::Catalog;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Catalog;

use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG %PROCENTRYABBREV);
use Date::Manip;
use Text::Abbrev;

@ISA = qw(CGI::Dialog);


%PROCENTRYABBREV = abbrev qw(feescheduleentryid name modifier units description);

use vars qw(%ITEMTOFIELDMAP %CODE_TYPE_MAP);

%ITEMTOFIELDMAP =
(
	'feescheduleentryid' => 'entry_id',
	'name' => 'name',	#name stands for itemname
	'modifier' => 'modifier',
	'units' => 'default_units',
	'description' => 'description'
);

%CODE_TYPE_MAP =
(
	'item' => 0,
	'icd' => 80,
	'cpt' => 100,
	'proc'=> 110,
	'procert' => 120,
	'service' => 150,
	'sercert' => 160,
	'product' => 200,
	'hcpcs' => 210
);


sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'catalog', heading => '$Command Fee Schedule');

	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new App::Dialog::Field::Catalog::ID::New(caption => 'Fee Schedule ID',
						name => 'catalog_id', size => 14,
						options => FLDFLAG_REQUIRED,
						postHtml => "<a href=\"javascript:doActionPopup('/lookup/catalog');\">Lookup existing fee schedules</a>"),
			new CGI::Dialog::Field::TableColumn(type => 'hidden',column => 'offering_catalog_type.id',
						name => 'catalog_type', schema => $schema, value => 0),
			new CGI::Dialog::Field(caption => 'Fee Schedule Name', name => 'caption', options => FLDFLAG_REQUIRED),
			new CGI::Dialog::Field(type => 'memo', caption => 'Description', name => 'description'),
			new CGI::Dialog::Field::TableColumn(caption => 'Parent Fee Schedule ID', name => 'parent_catalog_id',
						schema => $schema, column => 'Offering_Catalog_Entry.catalog_id',
						findPopup => '/lookup/catalog/id'),
#			new CGI::Dialog::Field(type => 'memo', caption => 'Fee Schedule Entries', name => 'feescheduleentries',
#						cols => 40, rows => 5,
#						invisibleWhen => (CGI::Dialog::DLGFLAG_UPDATE | CGI::Dialog::DLGFLAG_REMOVE),
#						hints => 'Format: <b>f.FeeScheduleID,n.ItemName</b>,m.Modifier,u.UnitsAvailable,d.Description,<b>ItemType(item,icd,cpt,proc,procert,service,sercert,product,hcpcs).ItemCode,$UnitCost</b>'),
			#new CGI::Dialog::Field(caption => 'Fee Schedules', name => 'feeschedules',types => ['FeeScheduleEntry']),
			#new CGI::Dialog::Field(caption => 'CPTs', name => 'listofcpts'),
			);
	$self->{activityLog} =
	{
		scope =>'offering_catalog',
		key => "#field.catalog_id#",
		data => "FeeSchedule '#field.caption#' <a href='/search/catalog/detail/#field.catalog_id#'>#field.catalog_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons(
							nextActions_add => [
								['Add Another Fee Schedule', "/org/#session.org_id#/dlg-add-catalog", 1],
								['Show Current Fee Schedule', '/search/catalog/detail/%field.catalog_id%'],
								['Show List of Fee Schedules', '/search/catalog']
								],
							cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}



sub customValidate
{
	my ($self, $page) = @_;
#	validateFeeScheduleEntryTextArea($self, $page);

}


#This sub is called from CustomValidate for fee entry validation which is a memo type
sub validateFeeScheduleEntryTextArea
{
	my ($self, $page) = @_;
	my $endDate = '';
	my $feeEntry = $self->getField('feescheduleentries');
	#my $diags = $self->getField('claim_diags');
	#my @diagCodes = split(/\s*,\s*/, $page->field('claim_diags'));
	my $feeScheduleflag = 0;
	my $itemflag = 0;
	my $unitsflag = 0;
	my $modifierflag = 0;
	my $descflag = 0;
	my $dollarflag = 0;


	if(my $addFeeEntries = $page->field('feescheduleentries'))
	{
		my @entries = split(/\n/, $addFeeEntries);
		foreach (@entries)
		{
			my @details = split(/[,;\-]+/);

			#if(not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selCatalogById', $details[0])))
			#{
			#	$page->addDebugStmt($page, $details[0]);
			#	$feeEntry->invalidate($page, "Fee Schedule ID is incorrect. The first entry is always an existing Fee Schedule ID");
			#}


			#my @procdetails = @details[1 .. $#details];
			foreach (@details)
			{
				if($_ =~ /\r/)
				{
					chop($_);
				}
				if($_ =~ /^\s/)
				{
					substr($_,0,1)="";
				}

				#validation of diagnosis codes to see if they are in the ICD-9 codes list.
				if(m/^([^\$]*)\.(.*)$/)
				{
					#validation of other entries
					# $2 is the value XXXX entered in p.XXXX or t.XXXX or ref.XXXX
					if(my $match = $PROCENTRYABBREV{$1})
					{
						if($match eq 'feescheduleentryid') 	{ $feeScheduleflag = 1 };
						if($match eq 'name') 			{ $itemflag = 1 };
						if($match eq 'units') 			{ $unitsflag = 1 };
						if($match eq 'modifier')		{ $modifierflag = 1 };
						if($match eq 'description')		{ $descflag = 1 };

						validateEachItemInFeeItemEntryTextArea($self, $page, $match, $2);
					}
					else
					{
						my $feeEntryTypeFlag = 0;
						foreach my $entryType (keys %CODE_TYPE_MAP)
						{
							#$page->addDebugStmt($page, $entryType);
							if($_ =~ /$entryType/)
							{
								$feeEntryTypeFlag = 1;
							}

						}
						if($feeEntryTypeFlag == 0)
						{
							# add to validation code
							$feeEntry->invalidate($page, "The data format $_ is not defined. The values allowed for fee schedule entry type are cpt,hcpcs,icd,item,proc,procert,product,service,sercert");
						}
					}

				}
				elsif(m/^\$(.*)/)
				{
					#validation of the dollar amount
					if($1 !~ /^\d+(\.\d\d)?$/)
					{
						$feeEntry->invalidate($page, "The dollar amount is wrong. Please verify");
					}
					#$1 is the amount
					$dollarflag = 1;
				}
				else
				{
					#validation of plain word entries like lab, emergency
					if(my $plainWordMatch = $PROCENTRYABBREV{$_})
					{
					}
					else
					{
						$feeEntry->invalidate($page, "The data format $_ is not defined. Please verify");
					}

				}

			}
			if( $feeScheduleflag == 0 )	{ $feeEntry->invalidate($page, "The fee schedule item id is not defined. Fee schedule item ID is required"); }
			if( $itemflag == 0 )	{ $feeEntry->invalidate($page, "The item name is not defined. Item name is required"); };
			#if( $unitsflag == 0 )	{ $feeEntry->invalidate($page, "The cpt code is not defined. cpt code is required"); };
			#if( $modifierflag == 0 ){ $feeEntry->invalidate($page, "The modifier code is not defined. modifier code is required"); };
			if( $dollarflag == 0 )	{ $feeEntry->invalidate($page, "The dollar amount is not defined. dollar amount is required"); };
			#if( $descflag == 0 )	{ $feeEntry->invalidate($page, "The diagnosis code is not defined. diagnosis code is required"); };

		}
	}

}



sub validateEachItemInFeeItemEntryTextArea
{
	my ($self, $page, $fieldPrefix, $fieldValue) = @_;
	my $feeScheduleId = $page->field('catalog_id');
	my $feeEntry = $self->getField('feescheduleentries');

	#$page->addDebugStmt("feeScheduleId is $feeScheduleId and feeScheduleId in item is $fieldValue");


	if($fieldPrefix eq 'feescheduleentryid')
	{

		if($feeScheduleId ne $fieldValue)
		{
			#$page->addDebugStmt($page, $fieldValue);
			$feeEntry->invalidate($page, "Fee Schedule ID is incorrect. Please verify");
		}

	}
	#if($fieldPrefix eq 'modifier')
	#{
	#	if($fieldValue =~ m/^(\d+)$/)
	#	{
	#		# $1 is the check to see if it is an integer
	#		if(not($STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericModifierCodeId', $1)))
	#		{
	#			$feeEntry->invalidate($page, "The modifier code is wrong. Please verify");
	#		}
	#	}
	#	else
	#	{
	#		$feeEntry->invalidate($page, "The modifier code should be an integer. Please verify");
	#	}
	#}



}

sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	#return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	$page->field('parent_catalog_id', $page->param('parent_catalog_id'));
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	my $catalogId = $page->param('catalog_id');
	if(! $STMTMGR_CATALOG->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selCatalogById',$catalogId))
	{
		$page->addError("Catalog ID '$catalogId' not found.");
	}
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $id = $self->{'id'};
	my $orgId = $page->param('org_id');
	my $catalogType = $page->field('catalog_type');
	my $status = $page->field('status');
	my $costType = $page->field('cost_type');
	my $entryType = $page->field('entry_type');
	$page->schemaAction(
			'Offering_Catalog', $command,
			catalog_id => $page->field('catalog_id') || undef,
			org_id => $orgId || undef,
			catalog_type => defined $catalogType ? $catalogType : 0,
			#item_id => $page->field('item_id') || $page->param('item_id') || undef,
			caption => $page->field('caption') || undef,
			description => $page->field('description') || undef,
			parent_catalog_id => $page->field('parent_catalog_id') || undef,
			_debug => 0
			);

#	if(my $addEntries = $page->field('feescheduleentries'))
#	{
#		my @entries = split(/\n/, $addEntries);
#		foreach (@entries)
#		{
#			my @details = split(/[,;]+/);
#			my %record = (	catalog_id => $page->field('catalog_id'),
#					default_units => App::Universal::INVOICEITEM_QUANTITY,				#default for for units is 1
#					description => ''
#					);
#
#			#my @itemdetails = @details[2 .. $#details];
#			foreach (@details)
#			{
#				if($_ =~ /\r/)
#				{
#					chop($_);
#				}
#				if($_ =~ /^\s/)
#				{
#					substr($_,0,1)="";
#				}
#
#				if(m/^([^\$]*)\.(.*)$/)
#				{
#					if(my $match = $PROCENTRYABBREV{$1})
#					{
#						if(my $fieldName = $ITEMTOFIELDMAP{$match})
#						{
#							$record{$fieldName} = $2;
#						}
#					}
#					else
#					{
#						$record{entry_type} = $CODE_TYPE_MAP{$1};
#						$record{code} = $2;
#					}
#
#				}
#				elsif(m/^\$(.*)/)
#				{
#					$record{unit_cost} = $1;
#					next;
#					#$1 is the amount
#				}
#
#				# f.kkkk fee schedule id
#				# i.jjjj item name
#				# m.xxxx modifier
#				# u.yyyy units
#				# d.zzzz description
#				# $abcd dollar amount
#
#			}
#
#			# IMPORTANT: ADD VALIDATION FOR FIELD ABOVE (TALK TO RADHA/MUNIR/SHAHID)
#			$page->schemaAction('Offering_Catalog_Entry', 'add', %record, _debug => 1);
#		}
#	}
#

	$self->handlePostExecute($page, $command, $flags);
	#$page->redirect("/org/$orgId/dlg-add-feescheduleentry?_f_fs=%field.feeschedules%&_f_cpts=%field.listofcpts%");
}
use constant CATALOG_DIALOG => 'Dialog/FeeSchedule';

@CHANGELOG =
(
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_ADD, '01/04/2000', 'RK',
		CATALOG_DIALOG,
		'Added a dialog called fee schedule. '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/05/2000', 'RK',
		CATALOG_DIALOG,
		'Updated the dialog and schema-action for Fee Shedule dialog'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/10/2000', 'RK',
		CATALOG_DIALOG,
		'Added Session Activity to  Fee Schedule. '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_ADD, '01/12/2000', 'RK',
			CATALOG_DIALOG,
		'Deleted session-activity in execute_add subroutine and added activityLog in the sub new subroutine.'],
	[	CHANGELOGFLAG_ANYVIEWER | CHANGELOGFLAG_UPDATE, '01/20/2000', 'MM',
		CATALOG_DIALOG,
		'Added a fee schedule entries field and next action field to  Fee Schedule Dialog. '],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/21/2000', 'RK',
		CATALOG_DIALOG,
		'Update the field Catalog Type to a hidden field.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '01/28/2000', 'RK',
		CATALOG_DIALOG,
		'Added id for catalog dialog (as catalog) in sub new subroutine.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_UPDATE, '02/20/2000', 'MAF',
		CATALOG_DIALOG,
		'Implemented new field type for catalog ids.'],

);


##############################################################################
package App::Dialog::Catalog::Copy;
##############################################################################

use strict;
use DBI::StatementManager;
use App::Statements::Catalog;
use App::Statements::Person;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Dialog::Field::Catalog;

use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG %PROCENTRYABBREV);
use Date::Manip;
use Text::Abbrev;

@ISA = qw(CGI::Dialog);



sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'catalog', heading => 'Copy Fee Schedule');

	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	$self->addContent(
			new App::Dialog::Field::Catalog::ID(caption => 'Fee Schedule ID (From)',
						name => 'from_catalog_id', size => 14,
						options => FLDFLAG_REQUIRED,
						postHtml => "<a href=\"javascript:doActionPopup('/lookup/catalog');\">Lookup existing fee schedules</a>"),
			new CGI::Dialog::Field::TableColumn(type => 'hidden',column => 'offering_catalog_type.id',
						name => 'catalog_type', schema => $schema, value => 0),
			new App::Dialog::Field::Catalog::ID::New(caption => 'Fee Schedule ID (To)',
						name => 'to_catalog_id', size => 14,
						options => FLDFLAG_REQUIRED,),
			);
	$self->{activityLog} =
	{
		scope =>'offering_catalog',
		key => "#field.catalog_id#",
		data => "FeeSchedule '#field.caption#' <a href='/search/catalog/detail/#field.catalog_id#'>#field.catalog_id#</a>"
	};
	$self->addFooter(new CGI::Dialog::Buttons());

	return $self;
}


sub populateData_add
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	#return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;

	$page->field('from_catalog_id', $page->param('parent_catalog_id'));
}

sub getFeeScheduleGrandChildren
{
	my ($self, $page, $catalogId) = @_;

	my $fromFeeScheduleChild = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selChildrenCatalogs', $catalogId);


}

sub execute
{
	my ($self, $page, $command, $flags) = @_;
	my $id = $self->{'id'};
	my $orgId = $page->param('org_id');
	my $catalogType = $page->field('catalog_type');
	my $fromCatalogId = $page->field('from_catalog_id');
	my $toCatalogId = $page->field('to_catalog_id');
	my $endFlag = 0;

	my $fromFeeSchedule = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selCatalogById', $fromCatalogId);

	$page->schemaAction(
			'Offering_Catalog', 'add',
			catalog_id => $page->field('to_catalog_id') || undef,
			org_id => $fromFeeSchedule->{org_id} || undef,
			catalog_type => $fromFeeSchedule->{catalog_type} || undef,
			caption => $fromFeeSchedule->{caption} || undef,
			description => $fromFeeSchedule->{description} || undef,
			parent_catalog_id => $fromFeeSchedule->{parent_catalog_id} || undef,
			_debug => 0
			);


	my $fromFeeScheduleChild = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selChildrenCatalogs', $fromCatalogId);
	if (defined $fromFeeScheduleChild)
	{

	$page->addDebugStmt("fromFeeScheduleChild exists");

		$page->schemaAction(
				'Offering_Catalog', 'add',
				catalog_id => $fromFeeScheduleChild->{'catalog_id'} || undef,
				org_id => $fromFeeScheduleChild->{org_id} || undef,
				catalog_type => $fromFeeScheduleChild->{catalog_type} || undef,
				caption => $fromFeeScheduleChild->{caption} || undef,
				description => $fromFeeScheduleChild->{description} || undef,
				parent_catalog_id => $page->field('to_catalog_id'),
				_debug => 0
				);
		my $tempChild = $fromFeeScheduleChild->{'catalog_id'};
		#getFeeScheduleGrandChildren($self, $page, $tempChild);

	}
#
	#	do
	#	{
	#		my $fromFeeScheduleGrandChild = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selChildrenCatalogs', $tempChild );
	#		if (defined $fromFeeScheduleGrandChild)
	#		{
	#			$page->schemaAction(
	#					'Offering_Catalog', 'add',
	#					catalog_id => $fromFeeScheduleGrandChild->{'catalog_id'} || undef,
	#					org_id => $fromFeeScheduleGrandChild->{org_id} || undef,
	#					catalog_type => $fromFeeScheduleGrandChild->{catalog_type} || undef,
	#					caption => $fromFeeScheduleGrandChild->{caption} || undef,
	#					description => $fromFeeScheduleGrandChild->{description} || undef,
	#					parent_catalog_id => $fromFeeScheduleGrandChild->{'parent_catalog_id'},
	#					_debug => 0
	#					);
	#			$tempChild = $fromFeeScheduleGrandChild->{'catalog_id'}
	#		}
	#		else
	#		{
	#			my $endFlag = 1;
	#		}
	#	}until ($endFlag == 1);
	#}

	$self->handlePostExecute($page, $command, $flags);
}




1;
