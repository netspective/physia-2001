##############################################################################
package App::Dialog::Medication;
##############################################################################

use strict;
use SDE::CVS ('$Id: Medication.pm,v 1.28 2001-01-30 17:39:42 thai_nguyen Exp $', '$Name:  $');
use CGI::Validator::Field;
use CGI::Dialog;
use base qw(CGI::Dialog);

use Date::Manip;
use DBI::StatementManager;
use App::Statements::Person;
use App::Statements::Document;
use App::Dialog::Message::Prescription;
use App::Dialog::Field::Scheduling;
use Date::Calc qw(:all);
use App::Page;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'medication' => {
		_arl => ['permed_id'],
		_arl_add => ['parent_id'],
		_arl_prescribe => ['parent_id'],
		_modes => ['add', 'prescribe', 'refill', 'update', 'approve', 'view'],
	},
);

my $UNIT_SELOPTIONS = 'mg;ug;gm;kg;pills;caps;tabs;supp;cc;ml;ggts;mm;oz;tsp;tbls;liter;gallon;applicator;inhalation;puff;spray;packets;patch;other';
my $ROUTE_SELOPTIONS = 'PO;chew;suck;sublingual;inhaled nasally;topically;rectally;vaginally;eyes;OD;OS;ears;SQ;IM;IV';
my $FREQ_SELOPTIONS = 'QD;BID;TID;QID;Q2H;Q4H;Q6H;Q8H;Q12H;other';
my $PRN_SELOPTIONS = 'Pain;Severe Pain;Nausea;Vomiting;Diarrhea;Fever;Cough;SOB;Chest Pain;Angina;other';

sub new
{
	my $self = CGI::Dialog::new(@_, id => 'message', heading => '$Command Medication');
	my $mode = $self->{command};
	$self->addContent(
		new CGI::Dialog::Field(caption => 'Patient Name',
			name => 'parent_id',
			options => FLDFLAG_REQUIRED | FLDFLAG_READONLY,
		),
		new CGI::Dialog::Field(caption => 'Medication',
			name => 'med_name',
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::MultiField(
			name => 'medication_multi',
			fields => [
				new CGI::Dialog::Field(caption => 'Dose',
					name => 'dose',
					size => 5,
					type => 'float',
				),
				new CGI::Dialog::Field(caption => 'Units',
					name => 'dose_units',
					type => 'select',
					selOptions => $UNIT_SELOPTIONS,
					onChangeJS => qq{showFieldsOnValues(event, ['other'], ['other_dose_units']);},
				),
				new CGI::Dialog::Field(caption => 'Route',
					name => 'route',
					type => 'select',
					selOptions => $ROUTE_SELOPTIONS,
				),
			],
		),
				new CGI::Dialog::Field(caption => 'Other Units',
					name => 'other_dose_units',
				),

		new CGI::Dialog::MultiField(
			name => 'freq_prn_multi',
			fields => [
				new CGI::Dialog::Field(caption => 'Frequency',
					name => 'frequency',
					type => 'select',
					selOptions => $FREQ_SELOPTIONS,
					onChangeJS => qq{showFieldsOnValues(event, ['other'], ['other_frequency']);},
				),
				new CGI::Dialog::Field(caption => 'PRN',
					name => 'prn',
					type => 'select',
					selOptions => $PRN_SELOPTIONS,
					options => FLDFLAG_PREPENDBLANK,
					onChangeJS => qq{showFieldsOnValues(event, ['other'], ['other_prn']);},
				),
			],
		),

				new CGI::Dialog::Field(caption => 'Other Frequency',
					name => 'other_frequency',
				),
				new CGI::Dialog::Field(caption => 'Other PRN',
					name => 'other_prn',
				),


				new CGI::Dialog::Field(caption => 'First Dose',
					name => 'first_dose',
					type => 'select',
					selOptions => 'Now;In;After Completing',
					options => FLDFLAG_REQUIRED | FLDFLAG_PREPENDBLANK,
					onChangeJS => qq{showFieldsOnValues(event, ['In', 'After Completing'], ['first_dose_specs']);},
				),
				new CGI::Dialog::Field(caption => 'First Dose Details',
					name => 'first_dose_specs',
				),

		new CGI::Dialog::MultiField(
			name => 'dates_multi',
			fields => [
				new App::Dialog::Field::Scheduling::Date(caption => 'Start Date',
					name => 'start_date',
					type => 'date',
					defaultValue => '',
					#options => FLDFLAG_REQUIRED,
				),
				new App::Dialog::Field::Scheduling::Date(caption => 'End Date',
					name => 'end_date',
					type => 'date',
					defaultValue => '',
				),
			],
		),
				new CGI::Dialog::Field(caption => 'Ongoing?',
					name => 'ongoing',
					type => 'bool',
					style => 'check',
				),

		new CGI::Dialog::MultiField(caption => 'Duration',
			name => 'duration_multi',
			fields => [
				new CGI::Dialog::Field(caption => 'Duration',
					name => 'duration',
					size => 4,
					type => 'integer',
					#options => FLDFLAG_INLINECAPTION,
				),
				new CGI::Dialog::Field(caption => '',
					name => 'duration_units',
					type => 'select',
					selOptions => 'days;weeks;months',
				),
			],
		),
		new CGI::Dialog::MultiField(
			name => 'quantity_refills_multi',
			fields => [
				new CGI::Dialog::Field(caption => 'Quantity',
					name => 'quantity',
					size => 5,
					type => 'float',
					#options => FLDFLAG_REQUIRED,
				),
				new CGI::Dialog::Field(caption => '# of Refills',
					name => 'num_refills',
					type => 'select',
					selOptions => '0;1;2;3;4;5;6;7;8;9;10;11;12;other',
					#options => FLDFLAG_REQUIRED,
					onChangeJS => qq{showFieldsOnValues(event, ['other'], ['other_num_refills']);},
				),
			],
		),

				new CGI::Dialog::Field(caption => 'Other # of Refills',
					name => 'other_num_refills',
					type => 'integer',
					size => 3,
				),


				#new CGI::Dialog::Field(caption => 'Sale Units',
				#	name => 'sale_units',
				#	type => 'select',
				#	selOptions => $UNIT_SELOPTIONS,
				#	options => FLDFLAG_PREPENDBLANK,
				#	onChangeJS => qq{showFieldsOnValues(event, ['other'], ['other_sale_units']);},
				#),
				#new CGI::Dialog::Field(caption => 'Other Units',
				#	name => 'other_sale_units',
				#),

				new CGI::Dialog::Field(caption => 'Label?',
					name => 'label',
					type => 'select',
					style => 'radio',
					selOptions => 'Yes:1;No:2',
					defaultValue => 1,
				),

				new CGI::Dialog::Field(caption => 'Print Label in',
					name => 'label_language',
					type => 'select',
					selOptions => 'English;Spanish;other;',
					onChangeJS => qq{showFieldsOnValues(event, ['other'], ['other_label']);},
				),
				new CGI::Dialog::Field(caption => 'Other Language',
					name => 'other_label',
				),

				new CGI::Dialog::Field(caption => 'Substitution allowed?',
					name => 'allow_substitutions',
					type => 'select',
					style => 'radio',
					selOptions => 'Yes:1;No:2',
					defaultValue => 1,
				),
				new CGI::Dialog::Field(caption => 'Generic allowed?',
					name => 'allow_generic',
					type => 'select',
					style => 'radio',
					selOptions => 'Yes:1;No:2',
					defaultValue => 1,
				),


		new CGI::Dialog::Field(caption => 'Priority',
			name => 'priority',
			type => 'select',
			selOptions => 'Normal;Emergency;ASAP',
			style => 'radio',
			defaultValue => 'Normal',
			options => FLDFLAG_INVISIBLE,
		),
		new CGI::Dialog::Field(caption => 'Notes',
			name => 'notes',
			type => 'memo',
			rows => 5,
			cols => 50,
			hint => 'Notes will not be printed on the prescription',
		),

		new App::Dialog::Field::Person::ID(caption => 'Prescription Approved By',
			name => 'approved_by',
		),
		new App::Dialog::Field::Person::ID(caption => 'Physician for Approval',
			name => 'get_approval_from', types => ['Physician'], incSimpleName=>1,
		),
		new App::Dialog::Field::Person::ID(caption => 'Prescribed By',
			name => 'prescribed_by', types => ['Physician'], incSimpleName=>1,
		),
		new CGI::Dialog::Field(caption => 'Prescribed By (If not in system)',
			name => 'other_prescribed_by',
		),
		new CGI::Dialog::Field(caption => 'Prescription Output',
			name => 'destination',
			type => 'select',
			selOptions => 'Fax to Pharmacy:fax;Print to Printer:printer',
			options => FLDFLAG_PREPENDBLANK,
			onChangeJS => 'onChangeDestination();',
		),
		new App::Dialog::Field::Organization::ID(caption => 'Pharmacy',
			name => 'pharmacy_id',
		),
		new CGI::Dialog::Field(type => 'password', caption => 'PIN#',
			name => 'physician_pin', options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(caption => 'Printer',
			name => 'printer',
		),
		new CGI::Dialog::Field(
			name => 'status',
			type => 'hidden',
			defaultValue => 0,
		),
	);

	$self->addFooter(new CGI::Dialog::Buttons(
							nextActions_add => [
								['Add Another Medication', "/person/%param.person_id%/dlg-add-medication", 1],
								['View Patient Chart', "/person/%param.person_id%/chart"],
								['Return to Work List', "/worklist"],
								['Return to Home Page', "/person/%session.user_id%/home"],
								],
						cancelUrl => $self->{cancelUrl} || undef));

	$self->{activityLog} =
	{
		level => 2,
		scope =>'Person_Medication',
		key => "#param.person_id#",
		data => "medication to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->{_buttons_field} = new CGI::Dialog::Buttons();
	#$self->addFooter($self->{_buttons_field});

	$self->addPostHtml(qq{
		<script language="JavaScript1.2">
		if (opObj = eval('document.dialog._f_dose_units'))
		{
			if (opObj.value != 'other')
			{
				setIdDisplay('other_dose_units', 'none');
			}
		}
		if (opObj = eval('document.dialog._f_frequency'))
		{
			if (opObj.value != 'other')
			{
				setIdDisplay('other_frequency', 'none');
			}
		}
		if (opObj = eval('document.dialog._f_prn'))
		{
			if (opObj.value != 'other')
			{
				setIdDisplay('other_prn', 'none');
			}
		}
		if (opObj = eval('document.dialog._f_first_dose'))
		{
			if (opObj.value == '')
			{
				setIdDisplay('first_dose_specs', 'none');
			}
		}
		if (opObj = eval('document.dialog._f_num_refills'))
		{
			if (opObj.value != 'other')
			{
				setIdDisplay('other_num_refills', 'none');
			}
		}
		if (opObj = eval('document.dialog._f_label_language'))
		{
			if (opObj.value != 'other')
			{
				setIdDisplay('other_label', 'none');
			}
		}

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
		#component.stp-person.diagnosisSummary#<BR>
		#component.stp-person.activeMedications#<BR>
		#component.stp-person.inactiveMedications#
	});
}

sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;
	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);

	my $buttonsField = $self->{_buttons_field};

	my $isNurse = grep {$_ eq 'Nurse'} @{$page->session('categories')};
	my $isPhysician = grep {$_ eq 'Physician'} @{$page->session('categories')};

	$command = 'prescribe' if $page->flagIsSet(PAGEFLAG_ISHANDHELD);

	$self->setFieldFlags('physician_pin', FLDFLAG_INVISIBLE);
	$self->updateFieldFlags('other_num_refills', FLDFLAG_INVISIBLE);

	if ($command eq 'add')
	{
		$self->setFieldFlags('approved_by', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('get_approval_from', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('destination', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('pharmacy_id', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('printer', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('ongoing', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('first_dose', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('first_dose_specs', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('label', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('label_language', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('other_label', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('allow_substitutions', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('allow_generic', FLDFLAG_INVISIBLE);
	}
	elsif ($command eq 'prescribe' || $command eq 'refill')
	{
		$self->setFieldFlags('medication_multi', FLDFLAG_REQUIRED);
		$self->setFieldFlags('quantity_refills_multi', FLDFLAG_REQUIRED);

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
			$self->setFieldFlags('prescribed_by', FLDFLAG_INVISIBLE);
			$self->setFieldFlags('other_prescribed_by', FLDFLAG_INVISIBLE);
			$self->setFieldFlags('approved_by', FLDFLAG_INVISIBLE);
			$page->field('approved_by', '');
			$self->setFieldFlags('get_approval_from', FLDFLAG_REQUIRED);
			$buttonsField->addActionButtons({caption => 'Submit For Approval'});
		}
		if($command eq 'refill')
		{
			#$self->setFieldFlags('sale_units', FLDFLAG_INVISIBLE);
			#$self->setFieldFlags('other_sale_units', FLDFLAG_INVISIBLE);
		}
	}
	elsif ($command eq 'update')
	{
		$self->setFieldFlags('get_approval_from', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('approved_by', FLDFLAG_READONLY);
		$self->setFieldFlags('destination', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('pharmacy_id', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('printer', FLDFLAG_INVISIBLE);

		my $medInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPerMedById', $page->param('permed_id'));
		my $recordType = $medInfo->{record_type};
		if($recordType == App::Universal::RECORDTYPE_EXISTING || $recordType == App::Universal::RECORDTYPE_REFILL)
		{
			$self->setFieldFlags('ongoing', FLDFLAG_INVISIBLE);
			$self->setFieldFlags('first_dose', FLDFLAG_INVISIBLE);
			$self->setFieldFlags('first_dose_specs', FLDFLAG_INVISIBLE);
		}
	}
	elsif ($command eq 'approve')
	{
		if ($isPhysician)
		{
			$self->updateFieldFlags('physician_pin', FLDFLAG_INVISIBLE, 0);
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
		$self->setFieldFlags('label', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('label_language', FLDFLAG_INVISIBLE);
		$self->setFieldFlags('other_label', FLDFLAG_INVISIBLE);
		$self->setDialogViewOnly($dlgFlags);
		$buttonsField->addActionButtons({caption => 'Close'});
		$buttonsField->{noCancelButton} = 1;

	}
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;

	$self->setFieldFlags('parent_id', FLDFLAG_READONLY);
	my $isPhysician = grep {$_ eq 'Physician'} @{$page->session('categories')};

	if (my $permedId = $page->param('permed_id'))
	{
		$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selPerMedById', $permedId);
		my $medInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selPerMedById', $permedId);

		my $allowSubstitutions = $medInfo->{allow_substitutions} == 1 ? 1 : 2;
		$page->field('allow_substitutions', $allowSubstitutions);
		my $allowGeneric = $medInfo->{allow_generic} == 1 ? 1 : 2;
		$page->field('allow_generic', $allowGeneric);

		my $doseUnits = $medInfo->{dose_units};
		my $inList;
		my @unitOptions = split(';', $UNIT_SELOPTIONS);
		foreach (@unitOptions)
		{
			next if $doseUnits ne $_;
			$inList = 1;
		}
		if($inList)
		{
			$page->field('dose_units', $doseUnits);
		}
		else
		{
			$page->field('dose_units', 'other');
			$self->updateFieldFlags('other_dose_units', FLDFLAG_INVISIBLE, 0);
			$page->field('other_dose_units', $doseUnits);
		}


		my $frequency = $medInfo->{frequency};
		my @freqOptions = split(';', $FREQ_SELOPTIONS);
		foreach (@freqOptions)
		{
			next if $frequency ne $_;
			$inList = 1;
		}
		if($inList)
		{
			$page->field('frequency', $frequency);
		}
		else
		{
			$page->field('frequency', 'other');
			$self->updateFieldFlags('other_frequency', FLDFLAG_INVISIBLE, 0);
			$page->field('other_frequency', $frequency);
		}


		my $prn = $medInfo->{prn};
		my @prnOptions = split(';', $PRN_SELOPTIONS);
		foreach (@prnOptions)
		{
			next if $prn ne $_;
			$inList = 1;
		}
		if($inList)
		{
			$page->field('prn', $prn);
		}
		else
		{
			$page->field('prn', 'other');
			$self->updateFieldFlags('other_prn', FLDFLAG_INVISIBLE, 0);
			$page->field('other_prn', $prn);
		}


		my @firstDose = split(': ', $medInfo->{first_dose});
		$page->field('first_dose', $firstDose[0]);
		unless($firstDose[0] eq 'Now' || $firstDose[0] eq '')
		{
			$self->updateFieldFlags('first_dose_specs', FLDFLAG_INVISIBLE, 0);
			$page->field('first_dose_specs', $firstDose[1]);
		}


		#my $saleUnits = $medInfo->{sale_units};
		#my $inList;
		#my @saleUnitOptions = split(';', $UNIT_SELOPTIONS);
		#foreach (@saleUnitOptions)
		#{
		#	next if $saleUnits ne $_;
		#	$inList = 1;
		#}
		#if($inList)
		#{
		#	$page->field('sale_units', $saleUnits);
		#}
		#else
		#{
		#	$page->field('sale_units', 'other');
		#	$self->updateFieldFlags('other_sale_units', FLDFLAG_INVISIBLE, 0);
		#	$page->field('other_sale_units', $saleUnits);
		#}


		my $label = $medInfo->{label} == 1 ? 1 : 2;
		$page->field('label', $label);

		my $labelLanguage = $medInfo->{label_language};
		if($labelLanguage eq 'English' || $labelLanguage eq 'Spanish')
		{
			$page->field('label_language', $labelLanguage);
		}
		else
		{
			$self->updateFieldFlags('other_label', FLDFLAG_INVISIBLE, 0);
			$page->field('label_language', 'other');
			$page->field('other_label', $labelLanguage);
		}


		my $refills = $medInfo->{num_refills};
		$page->field('num_refills', $refills);
		if($refills > 12)
		{
			$self->updateFieldFlags('other_num_refills', FLDFLAG_INVISIBLE, 0);
			$page->field('num_refills', 'other');
			$page->field('other_num_refills', $refills);
		}

		my $prescribedBy = $medInfo->{prescribed_by};
		if($prescribedBy && $STMTMGR_PERSON->recordExists($page, STMTMGRFLAG_NONE, 'selPersonData', $prescribedBy))
		{
			$page->field('prescribed_by', $prescribedBy);
		}
		else
		{
			$page->field('prescribed_by', '');
			$page->field('other_prescribed_by', $prescribedBy);
		}
	}

	if ($command eq 'refill' || $command eq 'prescribe')
	{
		$page->field('start_date'. UnixDate('today', '%m/%d/%Y'));
		$page->field('end_date', '');
		$page->field('approved_by', $page->session('person_id')) if $isPhysician;
	}

	#if ($command eq 'add' || $command eq 'prescribe')
	#{
		if ($page->param('person_id'))
		{
			my $personName = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selPersonSimpleNameById', $page->param('person_id'));
			my $personId = $page->param('person_id');
			my $nameAndId = $personName . " (" .$personId. ")";
			$page->field('parent_id',  $nameAndId);
		}
	#}

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

sub getHtml
{
	my ($self, $page, $command) = @_;
	
	if ($page->flagIsSet(PAGEFLAG_ISHANDHELD))
	{
		unless ($page->session('active_person_id'))
		{
			$page->addContent("No patient selected.  Please select a patient.");
			return '';
		}
		else
		{
			$self->SUPER::getHtml($page, $command);	
		}
	}
	else
	{
		$self->SUPER::getHtml($page, $command);
	}
}

sub customValidate
{
	my ($self, $page) = @_;

	if ($page->field('start_date') && $page->field('end_date'))
	{
		my $startDate = Date_to_Days(Decode_Date_US($page->field('start_date')));
		my $endDate   = Date_to_Days(Decode_Date_US($page->field('end_date')));

		if ($endDate < $startDate)
		{
			my $field = $self->getField('dates_multi')->{fields}->[0];
			$field->invalidate($page, qq{
				End Date must be later than or equal Start Date.
			});
		}
	}

	if($page->field('dose_units') eq 'other' && $page->field('other_dose_units') eq '')
	{
		$self->getField('other_dose_units')->invalidate($page, 'Please enter other units');
	}
	if($page->field('frequency') eq 'other' && $page->field('other_frequency') eq '')
	{
		$self->getField('other_frequency')->invalidate($page, 'Please enter other frequency');
	}
	if($page->field('prn') eq 'other' && $page->field('other_prn') eq '')
	{
		$self->getField('other_prn')->invalidate($page, 'Please enter other prn');
	}
	#if($page->field('sale_units') eq 'other' && $page->field('other_sale_units') eq '')
	#{
	#	$self->getField('other_sale_units')->invalidate($page, 'Please enter other units');
	#}
	if($page->field('num_refills') eq 'other' && $page->field('other_num_refills') eq '')
	{
		$self->getField('other_num_refills')->invalidate($page, 'Please enter number of refills');
	}
	if($page->field('label_language') eq 'other' && $page->field('other_label') eq '')
	{
		$self->getField('other_label')->invalidate($page, 'Please enter other language for label');
	}

	#check physician password if approval is being done
	my $pin = $page->field('physician_pin');
	my $loginInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selLoginOrg', $page->session('user_id'), $page->session('org_internal_id'));
	if($pin && $pin ne $loginInfo->{password})
	{
		$self->getField('physician_pin')->invalidate($page, 'Invalid PIN. Please try again.');
	}
}

sub execute_add
{
	my $self = shift;
	my ($page, $command, $flags) = @_;

	my $recordType = App::Universal::RECORDTYPE_EXISTING;
	$recordType = App::Universal::RECORDTYPE_PRESCRIBE if $command eq 'prescribe';
	$recordType = App::Universal::RECORDTYPE_REFILL if $command eq 'refill';

	my $dose = $page->field('dose');
	my $route = $page->field('route');
	my $firstDose = $page->field('first_dose');
	my $firstDoseValue;
	if($firstDose)
	{
		$firstDoseValue = $firstDose eq 'Now' ? 'Now' : $firstDoseValue . ': ' . $page->field('first_dose_specs');
	}
	my $doseUnits = $page->field('dose_units') eq 'other' ? $page->field('other_dose_units') : $page->field('dose_units');
	my $frequency = $page->field('frequency') eq 'other' ? $page->field('other_frequency') : $page->field('frequency');
	my $prn = $page->field('prn') eq 'other' ? $page->field('other_prn') : $page->field('prn');
	#my $saleUnits = $page->field('sale_units') eq 'other' ? $page->field('other_sale_units') : $page->field('sale_units');
	my $refills = $page->field('num_refills') eq 'other' ? $page->field('other_num_refills') : $page->field('num_refills');
	my $labelLanguage = $page->field('label_language') eq 'other' ? $page->field('other_label') : $page->field('label_language');

	my $sig = $prn eq '' ? "$dose, $route, $frequency" : "$dose, $route, $frequency, $prn";

	my $ongoing = $page->field('ongoing');
	my $permedId = $page->schemaAction(
		'Person_Medication', 'add',
		parent_id => $page->param('person_id') || undef,
		med_name => $page->field('med_name') || undef,
		dose => $dose || undef,
		dose_units => $doseUnits || undef,
		route => $route || undef,
		frequency => $frequency || undef,
		prn => $prn || undef,
		start_date => $page->field('start_date') || undef,
		end_date => $page->field('end_date')|| undef,
		duration => $page->field('duration') || undef,
		duration_units => $page->field('duration_units') || undef,
		quantity => $page->field('quantity') || undef,
		num_refills => defined $refills ? $refills : undef,
		allow_generic => $page->field('allow_generic') == 1 ? 1 : 0,
		allow_substitutions => $page->field('allow_substitutions') == 1 ? 1 : 0,
		notes => $page->field('notes') || undef,
		approved_by => $page->field('approved_by') || undef,
		pharmacy_id => $page->field('pharmacy_id') || undef,
		status => $page->field('status') || undef,
		#sale_units => $saleUnits || undef,
		record_type => defined $recordType ? $recordType : undef,
		first_dose => $firstDoseValue || undef,
		ongoing => defined $ongoing ? $ongoing : undef,
		sig => $sig || undef,
		prescribed_by => $page->field('prescribed_by') || $page->field('other_prescribed_by') || undef,
		label => $page->field('label') == 1 ? 1 : 0,
		label_language => $labelLanguage || undef,
		#signed => $page->field('') || undef,
		_debug => 0,
	);
	$page->param('permed_id', $permedId);

	unless ($page->field('approved_by'))
	{
		$self->sendApprovalRequest($page, $command, $flags);
	}

	$self->handlePostExecute($page, $command, $flags);
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

	my $recordType = App::Universal::RECORDTYPE_EXISTING;
	$recordType = App::Universal::RECORDTYPE_PRESCRIBE if $command eq 'prescribe';
	$recordType = App::Universal::RECORDTYPE_REFILL if $command eq 'refill';

	my $dose = $page->field('dose');
	my $route = $page->field('route');
	my $firstDose = $page->field('first_dose');
	my $firstDoseValue;
	if($firstDose)
	{
		$firstDoseValue = $firstDose eq 'Now' ? 'Now' : $firstDoseValue . ': ' . $page->field('first_dose_specs');
	}
	my $doseUnits = $page->field('dose_units') eq 'other' ? $page->field('other_dose_units') : $page->field('dose_units');
	my $frequency = $page->field('frequency') eq 'other' ? $page->field('other_frequency') : $page->field('frequency');
	my $prn = $page->field('prn') eq 'other' ? $page->field('other_prn') : $page->field('prn');
	#my $saleUnits = $page->field('sale_units') eq 'other' ? $page->field('other_sale_units') : $page->field('sale_units');
	my $refills = $page->field('num_refills') eq 'other' ? $page->field('other_num_refills') : $page->field('num_refills');
	my $labelLanguage = $page->field('label_language') eq 'other' ? $page->field('other_label') : $page->field('label_language');

	my $sig = $prn eq '' ? "$dose, $route, $frequency" : "$dose, $route, $frequency, $prn";

	my $ongoing = $page->field('ongoing');
	$page->schemaAction(
		'Person_Medication', 'update',
		permed_id => $page->param('permed_id'),
		med_name => $page->field('med_name') || undef,
		dose => $dose || undef,
		dose_units => $doseUnits || undef,
		route => $route || undef,
		frequency => $frequency || undef,
		prn => $prn || undef,
		start_date => $page->field('start_date') || undef,
		end_date => $page->field('end_date') || undef,
		duration => $page->field('duration') || undef,
		duration_units => $page->field('duration_units') || undef,
		quantity => $page->field('quantity') || undef,
		num_refills => defined $refills ? $refills : undef,
		allow_generic => $page->field('allow_generic') == 1 ? 1 : 0,
		allow_substitutions => $page->field('allow_substitutions') == 1 ? 1 : 0,
		notes => $page->field('notes') || undef,
		approved_by => $page->field('approved_by') || undef,
		pharmacy_id => $page->field('pharmacy_id') || undef,
		#sale_units => $saleUnits || undef,
		first_dose => $firstDoseValue || undef,
		ongoing => defined $ongoing ? $ongoing : undef,
		sig => $sig || undef,
		prescribed_by => $page->field('prescribed_by') || $page->field('other_prescribed_by') || undef,
		label => $page->field('label') == 1 ? 1 : 0,
		label_language => $labelLanguage || undef,
		#signed => $page->field('') || undef,
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

	if (grep {$_ eq 'Physician'} @{$page->session('categories')})
	{
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
	}

	return $results;
}

sub execute_view
{
	my $self = shift;
	my ($page, $command, $flags) = @_;

	$self->handlePostExecute($page, $command, $flags);
}

sub sendApprovalRequest
{
	my $self = shift;
	my ($page, $command, $flags) = @_;

	return if $command eq 'add';

	my $med_name = $page->field('med_name');
	my $patient = $page->param('person_id');
	my $dosage = $page->field('dose') . $page->field('dose_units');

	my $msgDlg = new App::Dialog::Message::Prescription();
	$msgDlg->sendMessage($page,
		subject => $command eq 'refill' ? 'Prescription Refill Request' : 'Prescription Approval Request',
		message => $page->session('person_id') . " is seeking approval for a prescription:\n\nPatient: $patient\nMedication: $med_name $dosage\n",
		to => $page->field('get_approval_from') || $page->session('person_id'),
		rePatient => $page->param('person_id'),
		permedId => $page->param('permed_id'),
	);
}

1;
