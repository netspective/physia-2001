##############################################################################
package App::Dialog::Medication;
##############################################################################

use strict;
use SDE::CVS ('$Id: Medication.pm,v 1.5 2000-12-18 19:32:03 robert_jenks Exp $', '$Name:  $');
use CGI::Validator::Field;
use CGI::Dialog;
use base qw(CGI::Dialog);

use Date::Manip;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Document;
use App::Dialog::Message::Prescription;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'medication' => {
		_arl => ['permed_id'],
		_arl_add => ['parent_id'],
		_arl_prescribe => ['parent_id'],
		_modes => ['add', 'prescribe', 'refill', 'update', 'approve', 'view'],
	},
);


sub new
{
	my $self = CGI::Dialog::new(@_, id => 'message', heading => '$Command Medication');
	my $mode = $self->{command};
	$self->addContent(
		new App::Dialog::Field::Person::ID(
			name => 'parent_id',
			caption => 'Patient ID',
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(
			name => 'med_name',
			caption => 'Medication',
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::MultiField(
			name => 'medication_multi',
			fields => [
				new CGI::Dialog::Field(
					name => 'dose',
					caption => 'Dose',
					size => 4,
					options => FLDFLAG_REQUIRED,
				),
				new CGI::Dialog::Field(
					name => 'dose_units',
					caption => 'Units',
					type => 'select',
					selOptions => 'mg;ug;gm;kg;pills;caps;tabs;supp;cc;ggts;mm;oz;tsp;tbls;liter;gallon;applicator;inhalation;puff;spray;packets;patch',
					options => FLDFLAG_PREPENDBLANK | FLDFLAG_REQUIRED,
				),
				new CGI::Dialog::Field(
					name => 'route',
					caption => 'Route',
					type => 'select',
					selOptions => 'PO;chew;suck;sublingual;inhaled nasally;topically;rectally;vaginally;eyes;OD;OS;ears;SQ;IM;IV',
					options => FLDFLAG_PREPENDBLANK | FLDFLAG_REQUIRED,
				),
			],
		),
		new CGI::Dialog::MultiField(
			name => 'freq_prn_multi',
			fields => [
				new CGI::Dialog::Field(
					name => 'frequency',
					caption => 'Frequency',
					type => 'select',
					selOptions => 'QD;BID;TID;QID;Q2H;Q4H;Q6H;Q8H;Q12H',
					options => FLDFLAG_PREPENDBLANK | FLDFLAG_REQUIRED,
				),
				new CGI::Dialog::Field(
					name => 'prn',
					caption => 'PRN',
					type => 'select',
					selOptions => 'Pain;Severe Pain;Nausea;Vomiting;Diarrhea;Fever;Cough;SOB;Chest Pain;Angina',
					options => FLDFLAG_PREPENDBLANK,
				),
			],
		),
		new CGI::Dialog::MultiField(
			name => 'dates_multi',
			fields => [
				new CGI::Dialog::Field(
					name => 'start_date',
					caption => 'Start',
					type => 'date',
					options => FLDFLAG_REQUIRED,
				),
				new CGI::Dialog::Field(
					name => 'end_date',
					caption => 'End Date',
					type => 'date',
					defaultValue => '',
				),
			],
		),
		new CGI::Dialog::MultiField(
			name => 'duration_multi',
			caption => 'Duration',
			fields => [
				new CGI::Dialog::Field(
					name => 'duration',
					caption => 'Duration',
					size => 4,
					#options => FLDFLAG_INLINECAPTION,
				),
				new CGI::Dialog::Field(
					name => 'duration_units',
					caption => '',
					type => 'select',
					selOptions => 'days;weeks;months',
				),
			],
		),
		new CGI::Dialog::MultiField(
			name => 'quantity_refills_multi',
			fields => [
				new CGI::Dialog::Field(
					name => 'quantity',
					caption => 'Quantity',
					size => 4,
					options => FLDFLAG_REQUIRED,
				),
				new CGI::Dialog::Field(
					name => 'num_refills',
					caption => '# of Refills',
					size => 4,
					options => FLDFLAG_REQUIRED,
				),
			],
		),
		new CGI::Dialog::MultiField(
			name => 'branding_multi',
			caption => 'Branding',
			fields => [
				new CGI::Dialog::Field(
					name => 'allow_generic',
					caption => 'Generic Allowed',
					type => 'bool',
					style => 'check',
				),
				new CGI::Dialog::Field(
					name => 'allow_substitutions',
					caption => 'Substitutions Allowed',
					type => 'bool',
					style => 'check',
				),
			],
		),
		new CGI::Dialog::Field(
			name => 'priority',
			caption => 'Priority',
			type => 'select',
			selOptions => 'Normal;Emergency;ASAP',
			style => 'radio',
			defaultValue => 'Normal',
			options => FLDFLAG_INVISIBLE,
		),
		new CGI::Dialog::Field(
			name => 'notes',
			caption => 'Notes',
			type => 'memo',
			rows => 5,
			cols => 50,
			hint => 'Notes will not be printed on the prescription',
		),
		new App::Dialog::Field::Person::ID(
			name => 'approved_by',
			caption => 'Prescription Approved By',
		),
		new App::Dialog::Field::Person::ID(
			name => 'get_approval_from',
			caption => 'Physician for Approval',
		),
		new CGI::Dialog::Field(
			name => 'destination',
			caption => 'Prescription Output',
			type => 'select',
			selOptions => 'Fax to Pharmacy:fax;Print to Printer:printer',
			options => FLDFLAG_PREPENDBLANK,
			onChangeJS => 'onChangeDestination();',
		),
		new App::Dialog::Field::Organization::ID(
			name => 'pharmacy_id',
			caption => 'Pharmacy',
		),
		new CGI::Dialog::Field(
			name => 'printer',
			caption => 'Printer',
		),
		new CGI::Dialog::Field(
			name => 'status',
			type => 'hidden',
			defaultValue => 0,
		),
	);

	$self->{activityLog} =
	{
		level => 2,
		scope =>'Person_Medication',
		key => "#param.person_id#",
		data => "medication to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->{_buttons_field} = new CGI::Dialog::Buttons();
	$self->addFooter($self->{_buttons_field});

	$self->addPostHtml(q{
		<script language="JavaScript1.2">

		function onChangeDestination()
		{
			if (destObj = eval('document.all._f_destination'))
			{
				if (destObj.options[destObj.selectedIndex].text == 'Fax to Pharmacy')
				{
					//alert ("Fax output is not yet supported.");
					setIdStyle('_id_pharmacy_id', 'display', 'block');
					setIdStyle('_id_printer', 'display', 'none');
				}
				else if (destObj.options[destObj.selectedIndex].text == 'Print to Printer')
				{
					setIdStyle('_id_printer', 'display', 'block');
					setIdStyle('_id_pharmacy_id', 'display', 'none');
				}
				else
				{
					setIdStyle('_id_printer', 'display', 'none');
					setIdStyle('_id_pharmacy_id', 'display', 'none');
				}
			}
		}

		// Call it at startup to initially hide fields
		onChangeDestination();

		</script>
	});
	
	return $self;
}


sub getSupplementaryHtml
{
	my ($self, $page, $command) = @_;

	return (CGI::Dialog::PAGE_SUPPLEMENTARYHTML_RIGHT, qq{
		#component.stp-person.allergies#<BR>
		#component.stp-person.careProviders#<BR>
		#component.stp-person.diagnosisSummary#
	});
}


sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
	
	my $buttonsField = $self->{_buttons_field};
	
	my $isNurse = grep {$_ eq 'Nurse'} @{$page->session('categories')};
	my $isPhysician = grep {$_ eq 'Physician'} @{$page->session('categories')};

	if ($command eq 'add')
	{
		$self->setFieldFlags('approved_by', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('get_approval_from', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('destination', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('pharmacy_id', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('printer', FLDFLAG_INVISIBLE);
	}
	elsif ($command eq 'prescribe' || $command eq 'refill')
	{
		unless ($isNurse || $isPhysician)
		{
			$self->setFieldFlags('destination', FLDFLAG_INVISIBLE);
			$self->setFieldFlags('pharmacy_id', FLDFLAG_INVISIBLE);
			$self->setFieldFlags('printer', FLDFLAG_INVISIBLE);
		}

		if ($isPhysician)
		{
			$self->setFieldFlags('get_approval_from', FLDFLAG_INVISIBLE);
			$self->setFieldFlags('approved_by', FLDFLAG_READONLY);
			$buttonsField->addActionButtons({caption => 'Save & Approve'});
		}
		else
		{
			$self->setFieldFlags('approved_by', FLDFLAG_INVISIBLE);
			$page->field('approved_by', '');
			$self->setFieldFlags('get_approval_from', FLDFLAG_REQUIRED);
			$buttonsField->addActionButtons({caption => 'Submit For Approval'});
		}
	}
	elsif ($command eq 'update')
	{
		$self->setFieldFlags('get_approval_from', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('approved_by', FLDFLAG_READONLY);		
		$self->setFieldFlags('destination', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('pharmacy_id', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('printer', FLDFLAG_INVISIBLE);
	}
	elsif ($command eq 'approve')
	{
		if ($isPhysician)
		{
			$self->setFieldFlags('get_approval_from', FLDFLAG_INVISIBLE);
			my $approvedBy = $self->getField('approved_by');
			$approvedBy->{type} = 'hidden';
			$page->field('approved_by', $page->session('person_id'));
			$buttonsField->addActionButtons({
				caption => 'Save & Approve',
				onClick => q{
					document.forms.dialog._f_status.value = 1;
					if (validateOnSubmit()) document.forms.dialog.submit();
				},
			});
			$buttonsField->addActionButtons({
				caption => 'Save & Deny',
				onClick => q{
					document.forms.dialog._f_status.value = 0;
					if (validateOnSubmit()) document.forms.dialog.submit();
				},
			});
		}
		else
		{
			$self->setFieldFlags('destination', FLDFLAG_INVISIBLE);
			$self->setFieldFlags('pharmacy_id', FLDFLAG_INVISIBLE);
			$self->setFieldFlags('printer', FLDFLAG_INVISIBLE);
			$self->setFieldFlags('get_approval_from', FLDFLAG_INVISIBLE);
			$self->setFieldFlags('approved_by', FLDFLAG_INVISIBLE);
			$self->setDialogViewOnly($dlgFlags);
			$buttonsField->addActionButtons({caption => 'Close'});
			$buttonsField->{noCancelButton} = 1;
		}

	}
	elsif ($command eq 'view')
	{
		$self->setFieldFlags('destination', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('pharmacy_id', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('printer', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('get_approval_from', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('approved_by', FLDFLAG_INVISIBLE);
		$self->setDialogViewOnly($dlgFlags);
		$buttonsField->addActionButtons({caption => 'Close'});
		$buttonsField->{noCancelButton} = 1;

	}
}


sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	
	my $isPhysician = grep {$_ eq 'Physician'} @{$page->session('categories')};

	if (my $permedId = $page->param('permed_id'))
	{
		$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPerMedById', $permedId);
	}

	if ($command eq 'refill' || $command eq 'prescribe')
	{
		$page->field('start_date'. UnixDate('today', '%m/%d/%Y'));
		$page->field('end_date', '');
		$page->field('approved_by', $page->session('person_id')) if $isPhysician;
	}

	if ($command eq 'add' || $command eq 'prescribe')
	{
		if ($page->param('person_id'))
		{
			$page->field('parent_id', $page->param('person_id'));
			$self->setFieldFlags('parent_id', FLDFLAG_READONLY);
		}
	}

	if ($command eq 'update' && $page->field('approved_by'))
	{
		foreach my $field (@{$self->{content}})
		{
			unless ($field->{name} eq 'dates_multi')
			{
				$field->setFlag(FLDFLAG_READONLY);
			}	
		}
		#$self->clearFieldFlags('approved_by', FLDFLAG_INVISIBLE);
	}
	elsif ($command eq 'update' && $isPhysician)
	{
		$page->field('approved_by', $page->session('person_id'));
	}

}


sub execute_add
{
	my $self = shift;
	my ($page, $command, $flags) = @_;

	my $permedId = $page->schemaAction(
		'Person_Medication', 'add',
		parent_id => $page->field('parent_id'),
		med_name => $page->field('med_name') || undef,
		dose => $page->field('dose') || undef,
		dose_units => $page->field('dose_units') || undef,
		route => $page->field('route') || undef,
		frequency => $page->field('frequency') || undef,
		prn => $page->field('prn') || undef,
		start_date => $page->field('start_date') || undef,
		end_date => $page->field('end_date')|| undef,
		duration => $page->field('duration') || undef,
		duration_units => $page->field('duration_units') || undef,
		quantity => $page->field('quantity') || undef,
		num_refills => defined $page->field('num_refills') ? $page->field('num_refills') : undef,
		allow_generic => $page->field('allow_generic') || undef,
		allow_substitutions => $page->field('allow_substitutions') || undef,
		notes => $page->field('notes') || undef,
		approved_by => $page->field('approved_by') || undef,
		pharmacy_id => $page->field('pharmacy_id') || undef,
		status => $page->field('status'),
		_debug => 0,
	);
	$page->param('permed_id', $permedId);

	unless ($page->field('approved_by'))
	{
		$self->sendApprovalRequest($page, $command, $flags);
	}

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}


sub execute_prescribe
{
	my $self = shift;
	return $self->execute_add(@_);
}


sub execute_refill
{
	my $self = shift;
	return $self->execute_add(@_);
}


sub execute_update
{
	my $self = shift;
	my ($page, $command, $flags) = @_;

	$page->schemaAction(
		'Person_Medication', 'update',
		permed_id => $page->param('permed_id'),
		med_name => $page->field('med_name') || undef,
		dose => $page->field('dose') || undef,
		dose_units => $page->field('dose_units') || undef,
		route => $page->field('route') || undef,
		frequency => $page->field('frequency') || undef,
		prn => $page->field('prn') || undef,
		start_date => $page->field('start_date') || undef,
		end_date => $page->field('end_date') || undef,
		duration => $page->field('duration') || undef,
		duration_units => $page->field('duration_units') || undef,
		quantity => $page->field('quantity') || undef,
		num_refills => $page->field('num_refills') || undef,
		allow_generic => $page->field('allow_generic') || undef,
		allow_substitutions => $page->field('allow_substitutions') || undef,
		notes => $page->field('notes') || undef,
		approved_by => $page->field('approved_by') || undef,
		pharmacy_id => $page->field('pharmacy_id') || undef,
		_debug => 0,
	);

	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}


sub execute_approve
{
	my $self = shift;
	my ($page, $command, $flags) = @_;

	my $results = $self->execute_update(@_);

	my $relatedMessages = $STMTMGR_DOCUMENT->getSingleValueList($page, STMTMGRFLAG_NONE, 'selMessagesByPerMedId', $page->param('permed_id'));
	
	my $status = $page->field('status');
	my $message = $status ? 'This medication/prescription has been approved.' : 'This medication/prescription has been denied';
	
	foreach my $doc_id (@$relatedMessages)
	{
		$page->schemaAction(
			'Document_Attribute', 'add',
			parent_id => $doc_id,
			value_type => App::Universal::ATTRTYPE_TEXT,
			item_name => 'Notes',
			person_id => $page->session('person_id'),
			value_int => 0,
			value_text => $message,
		);
	}

	return $results;
}


sub sendApprovalRequest
{
	my $self = shift;
	my ($page, $command, $flags) = @_;

	my $med_name = $page->field('med_name');
	my $patient = $page->field('parent_id');
	my $dosage = $page->field('dose') . $page->field('dose_units');

	my $msgDlg = new App::Dialog::Message::Prescription();
	$msgDlg->sendMessage($page,
		subject => 'Prescription Approval Request',
		message => $page->session('person_id') . " is seeking approval for a prescription:\n\nPatient: $patient\nMedication: $med_name $dosage\n",
		to => $page->field('get_approval_from'),
		rePatient => $page->field('parent_id'),
		permedId => $page->param('permed_id'),
	);
}


1;
