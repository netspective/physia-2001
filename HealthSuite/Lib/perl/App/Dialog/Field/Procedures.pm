##############################################################################
package App::Dialog::Field::Procedures;
##############################################################################

use strict;
use Carp;
use CGI::Validator;
use CGI::Validator::Field;
use CGI::Dialog;
use DBI::StatementManager;

use App::Statements::Person;
use App::Statements::Org;
use App::Statements::Catalog;
use App::Statements::Insurance;
use App::Universal;
use App::Statements::Invoice;
use Date::Manip;
use Date::Calc qw(:all);
use App::IntelliCode;
use vars qw(@ISA);
use constant FAKESELFPAY_INSINTID => -1111;
@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;

	$params{name} = 'procedures_list' unless exists $params{name};
	$params{type} = 'procedures';
	$params{lineCount} = 6 unless exists $params{count};
	$params{allowComments} = 1 unless exists $params{allowComments};
	$params{allowQuickRef} = 0 unless exists $params{allowQuickRef};

	return CGI::Dialog::Field::new($type, %params);
}

sub needsValidation
{
	return 1;
}

sub isValid
{
	my ($self, $page, $validator, $valFlags) = @_;

	my $sessUser = $page->session('user_id');
	my $sessOrgIntId = $page->session('org_internal_id');

	my $personId = $page->field('attendee_id');
	my $personInfo = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_CACHE, 'selRegistry', $personId);
	my $gender = '';
	$gender = 'M' if $personInfo->{gender_caption} eq 'Male';
	$gender = 'F' if $personInfo->{gender_caption} eq 'Female';
	my $dateOfBirth = $personInfo->{date_of_birth};

	my $servicedatebegin = '';
	my $servicedateend = '';
	#my $serviceplace = '';
	my $servicetype = '';
	my $procedure = '';
	my $modifier = '';
	my $diags = '';
	my $units = '';
	my $charges = '';
	my $emergency = '';
	my %diagsSeen = ();
	my $use_fee='';
	my $code_type='';
	my @defaultFeeSchedules;
	my @diagCodes = split(/\s*,\s*/, $page->param('_f_proc_diags'));
	my $insurance = undef;
	my $plan_id;
	my $product_id=undef;	
	my $list=undef;
	my @insFeeSchedules = ();
	my @usedFS=();
	my $payer = $page->field('payer');
	my @singlePayer = split(/\s*,\s*/, $payer);
	
	#GET FEE SCHEDULES ASSOICATED WITH THE PROIVDER ,THE ORG AND THE INSURANCE
	
	######################################################################################################################
	#THIS IF/ELSE BLOCK NEEDS WORK TO MAKE SURE IT DETERMINES PAYER CORRECTLY
	unless($singlePayer[0] == FAKESELFPAY_INSINTID)
	{
		$insurance = $STMTMGR_INSURANCE->getRowAsHash($page, STMTMGRFLAG_NONE,'selInsuranceData', $singlePayer[0]);
	}
	######################################################################################################################
	
	#Get Parent record for coverage could be a plan or a product
	my $coverage_id = $insurance->{'parent_ins_id'};
	my $coverage_parent = $STMTMGR_INSURANCE->getRowAsHash($page,STMTMGRFLAG_NONE,'selInsuranceData',$coverage_id);
	
	
	#If record type is product then a plan does not exist
	if ($coverage_parent->{'record_type'} == App::Universal::RECORDTYPE_INSURANCEPRODUCT)
	{
		$product_id = $coverage_parent->{'ins_internal_id'};
		$plan_id=undef;
	}		
	else
	{

		$plan_id = $coverage_parent->{'ins_internal_id'};
		my $product_info =$STMTMGR_INSURANCE->getRowAsHash($page,STMTMGRFLAG_NONE,'selInsuranceData',$coverage_parent->{'parent_ins_id'});
		$product_id = $product_info->{'ins_internal_id'};		
	}
	
	my $care = $page->field('care_provider_id')||undef;
	my $fac = $page->field('service_facility_id') || $page->field('hospital_id') || undef;
	#Get Fee Schedule for the Insurance, Physician, and Org (Location)
	my $getFeeScheds = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 
		'selFSHierarchy', $care,$fac ,$plan_id,$product_id);

	#Put Fee Schedules into an Insurance array
	my $order=$getFeeScheds->[0]->{'fs_order'} if $getFeeScheds->[0]->{'fs_order'} ;
	foreach my $fs (@{$getFeeScheds})
	{
		if ($order eq $fs->{'fs_order'})
		{
			#Since the same FS can appear on many levels only keep the first one
			unless (grep { $_ eq $fs->{'fs'} } @usedFS)
			{
				$list .= $list ? "fs->{'fs'} ," :$fs->{'fs'} ;
				push(@usedFS,$fs->{'fs'});				
			}
		}
		else
		{
			
			$order = $fs->{'fs_order'};
			push(@insFeeSchedules, $list) if $list;		
			$list ='';
			#Since the same FS can appear on many levels only keep the first one
			unless (grep { $_ eq $fs->{'fs'} } @usedFS)
			{			
				$list = $fs->{'fs'};
				push(@usedFS,$fs->{'fs'});
			}
		}
	}
	#Push last list values on Insurance FS
	push(@insFeeSchedules, $list) if $list;	

	#Set up default FS
	$list ='';
	#my @fsIntIds = ();
	my @fsText = split(/\s*,\s*/, $page->param('_f_proc_default_catalog'));
	foreach (@fsText)
	{
		my $catalog = $STMTMGR_CATALOG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selInternalCatalogIdByIdType',
					$page->session('org_internal_id'), $_, App::Universal::CATALOGTYPE_FEESCHEDULE);	
		push ( @defaultFeeSchedules, $catalog->{internal_catalog_id}) if $page->param('_f_proc_default_catalog');		
	}	
	# ------------------------------------------------------------------------------------------------------------------------	
	#munir's old icd validation for checking if the same icd code is entered in twice
	foreach (@diagCodes)
	{
		$diagsSeen{$_} = 1;
	}

	my $totalCodesEntered = @diagCodes;
	my $listTotal = keys %diagsSeen;

	if($totalCodesEntered != $listTotal)
	{
		$self->invalidate($page, 'Cannot enter the same ICD code more than once.');
	}

	my @errors = ();
	my $lineCount = $page->param('_f_line_count');
	for(my $line = 1; $line <= $lineCount; $line++)
	{
		$servicedatebegin = $page->param("_f_proc_$line\_dos_begin");
		$servicedateend = $page->param("_f_proc_$line\_dos_end");
		#$servicetype = $page->param("_f_proc_$line\_service_type");
		$procedure = $page->param("_f_proc_$line\_procedure");
		$modifier = $page->param("_f_proc_$line\_modifier");
		$diags = $page->param("_f_proc_$line\_diags");
		$units = $page->param("_f_proc_$line\_units");
		$charges = $page->param("_f_proc_$line\_charges");
		$emergency = $page->param("_f_proc_$line\_emg");
		$use_fee= $page->param("_f_proc_$line\_use_fee");
		$code_type=$page->param("_f_proc_$line\_code_type");

		next if $servicedatebegin eq 'From' && $servicedateend eq 'To';
		next if $servicedatebegin eq '' && $servicedateend eq '';
		
		my $chkBegin = ParseDate($servicedatebegin);
		my $chkEnd = ParseDate($servicedatebegin);


		#if($servicedatebegin !~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/)
		if(!$chkBegin)
		{
			$self->invalidate($page, "[<B>P$line</B>] Invalid Service Begin Date: $servicedatebegin");
		}
#		if($servicedateend !~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/)
		if(!$chkEnd)
		{
			$self->invalidate($page, "[<B>P$line</B>] Invalid Service End Date: $servicedateend ");
		}
		#comparing the begin and end date to see if the begin date is less than the end date
		if ($servicedatebegin =~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/ && $servicedateend =~ m/([\d][\d])\/([\d][\d])\/([\d][\d][\d][\d])/)
		{
			my $serviceBeginDate = ParseDate($servicedatebegin);
			my $serviceEndDate = ParseDate($servicedateend);
			my $flag = Date_Cmp($serviceBeginDate,$serviceEndDate);

			if($flag > 0)
			{
				# date2 is earlier
				$self->invalidate($page, "[<B>P$line</B>] Service begin date $servicedatebegin should be earlier than the end date $servicedateend");
			}
		}
		
		if($modifier ne '')
		{
			$self->invalidate($page, "[<B>P$line</B>] The modifier code $modifier is not valid. Please verify.") unless $STMTMGR_CATALOG->recordExists($page, STMTMGRFLAG_NONE, 'selGenericModifierCodeId', $modifier);
		}

		my @actualDiagCodes = ();
		my @actualDiagCodesForIntellicode = ();
		if($diags ne '')
		{
			my @diagNumbers = split(/\s*,\s*/, $diags);
			foreach my $diagNumber (@diagNumbers)
			{
				if($diagNumber !~ /^(\d+)$/)
				{
					$self->invalidate($page, "[<B>P$line</B>] The diagnosis $diagNumber should be integer. Please verify");
				}
				elsif(($diagNumber > $totalCodesEntered) || ($diagNumber == 0))
				{
					$self->invalidate($page, "[<B>P$line</B>] The diagnosis $diagNumber is not valid. Please verify");
				}
				else
				{
					push(@actualDiagCodes, $diagCodes[$diagNumber-1]);
					push(@actualDiagCodesForIntellicode, $diagCodes[$diagNumber-1]);
				}
			}

			@actualDiagCodes = join(', ', @actualDiagCodes);
			$page->param("_f_proc_$line\_actual_diags", @actualDiagCodes);
		}
		elsif($diags eq '')
		{
			$self->invalidate($page, "[<B>P$line</B>] The diagnosis relationships are not valid. Please verify");
		}

		if($units !~ /^(\d+\.?\d*|\.\d+)$/)
		{
			$self->invalidate($page, "[<B>P$line</B>] The dollar amount $units is not valid. Please verify");
		}
		if($charges ne '' && $charges !~ /^(\d+\.?\d*|\.\d+)$/)
		{
			$self->invalidate($page, "[<B>P$line</B>] The dollar amount $charges is not valid. Please verify");
		}

		## INTELLICODE VALIDATION
		my @procs = ();
		push(@procs, [$procedure, $modifier || undef, @actualDiagCodes]);
		my @cptCodes = ($procedure);

		#App::IntelliCode::incrementUsage($page, 'Cpt', \@cptCodes, $sessUser, $sessOrgIntId);
		#App::IntelliCode::incrementUsage($page, 'Icd', \@diagCodes, $sessUser, $sessOrgIntId);
		#App::IntelliCode::incrementUsage($page, 'Hcpcs', \@cptCodes, $sessUser, $sessOrgIntId);

		my @listFeeSchedules = @defaultFeeSchedules ? @defaultFeeSchedules : @insFeeSchedules;
		$page->param("_f_proc_active_catalogs", join(',', @listFeeSchedules));		
		my $fsDate = $chkBegin ? $servicedatebegin :undef  ;
		my $fs_entry=App::IntelliCode::getFSEntry($page, $procedure, $modifier || undef,$fsDate,\@listFeeSchedules);
		my $count_type = scalar(@$fs_entry);
		my $count=0;
		if ( ($servicetype eq '' || $charges eq '') && length($page->field('payer')) >0)
		{
			#$page->addError("Count Type: $count_type");
			if ($count_type==1 || ($use_fee ne '' && $count_type >=1) )
			{
				foreach(@$fs_entry)
				{
					if($count_type==1||$use_fee eq $count)
					{
						#Fail Safe To make sure service type is set. 
						#Still FS entries in database that do not have a service type
						if(length($_->[$INTELLICODE_FS_SERV_TYPE]) > 0)
						{
							$page->param("_f_proc_$line\_service_type",$_->[$INTELLICODE_FS_SERV_TYPE]);
							$page->param("_f_proc_$line\_code_type",$_->[$INTELLICODE_FS_CODE_TYPE]); 	
							$page->param("_f_proc_$line\_charges", $_->[$INTELLICODE_FS_COST]) if $charges eq '';
							$page->param("_f_proc_$line\_ffs_flag",$_->[$INTELLICODE_FS_FFS_CAP]);
							$page->param("_f_proc_$line\_fs_used",$_->[$INTELLICODE_FS_ID_NUMERIC]);
							#$page->addError("fee sched: $_->[$INTELLICODE_FS_ID_NUMERIC]");
						}
						else
						{
							$self->invalidate($page,"[<B>P$line</B>]Check that Service Type is set for Fee Schedule Entry '$procedure' in fee schedule $_->[$INTELLICODE_FS_ID_TEXT]" );
						}
					}
					$count++;
				}
			}
			elsif ($count_type>1)
			{
				my $html_svc = $self->getMultiSvcTypesHtml($page, $line,$procedure, $fs_entry);
				$self->invalidate($page, $html_svc);
			}
			else
			{				
				$self->invalidate($page,"[<B>P$line</B>]Unable to find Code '$procedure' in fee schedule(s) " . join ",",@listFeeSchedules);
			}
		}
		#unless ($charges)
		#{
		#	$count =0;
		#	my @allFeeSchedules = @defaultFeeSchedules ? @defaultFeeSchedules : @insFeeSchedules;
		#	
		#	my $fsResults = App::IntelliCode::getItemCost($page, $procedure, $modifier || undef, \@allFeeSchedules);
		#	my $resultCount = scalar(@$fsResults);
		#
		#	if($resultCount == 0)
		#	{
		#		#$self->invalidate($page, "[<B>P$line</B>] No unit cost was found for code '$procedure' and modifier '$modifier'");
		#	}
		#	elsif($resultCount == 1|| $use_fee ne '')
		#	{
		#
		#		foreach (@$fsResults)
		#		{
		#			if($resultCount == 1|| $use_fee eq $count)
		#			{
		#				my $unitCost = $_->[1];
		#				my $ffsFlag = $_->[2];
		#				$page->param("_f_proc_$line\_charges", $unitCost);
		#				$page->param("_f_proc_$line\_ffs_flag",$ffsFlag);
		#			}
		#			$count++;
		#		}
		#	}
		#	else
		#	{
		#		#my $html = $self->getMultiPricesHtml($page, $line, $fsResults);
		#		#$self->invalidate($page, $html);
		#	}
		#}

		#@errors = App::IntelliCode::validateCodes
		#(
		#	$page, App::IntelliCode::INTELLICODEFLAG_SKIPWARNING,
		#	sex => $gender,
		#	dateOfBirth => $dateOfBirth,			
		#	diags => \@actualDiagCodesForIntellicode,
		#	procs => \@procs,
		#);

		#foreach (@errors)
		#{
		#	$self->invalidate($page, "[<B>P$line</B>] $_");
		#}
	}

	explosionCodeValidate($self, $page);

	return @errors || $page->haveValidationErrors() ? 0 : 1;
}

sub explosionCodeValidate
{
	my ($self, $page) = @_;

	my $sessOrgIntId = $page->session('org_internal_id');

	#VALIDATION OF FEE SCHED RESULTS FOR CHILDREN OF EXPLOSION CODES

	my $lineCount = $page->param('_f_line_count');
	#my $getProcListField = $self->getField('procedures_list');
	if(length($page->field('payer')) >0)
	{
		for(my $line = 1; $line <= $lineCount; $line++)
		{
			next if $page->param("_f_proc_$line\_dos_begin") eq 'From' || $page->param("_f_proc_$line\_dos_end") eq 'To';
			next unless $page->param("_f_proc_$line\_dos_begin") && $page->param("_f_proc_$line\_dos_end");

			my $cptCode = $page->param("_f_proc_$line\_procedure");
			my $miscProcChildren = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_CACHE, 'selMiscProcChildren', $sessOrgIntId, $cptCode);
			if($miscProcChildren->[0]->{code})
			{
				my $servBeginDate = $page->param("_f_proc_$line\_dos_begin");
				my @listFeeSchedules = ($page->param("_f_proc_$line\_fs_used"));

				foreach my $child (@{$miscProcChildren})
				{
					my $childCode = $child->{code};
					my $modifier = $child->{modifier};
					my $fs_entry = App::IntelliCode::getFSEntry($page, $childCode, $modifier || undef,$servBeginDate,\@listFeeSchedules);
					my $count_type = scalar(@$fs_entry);
					if ($count_type == 0)
					{
						$self->invalidate($page,"[<B>P$line</B>]Unable to find Code '$childCode' in fee schedule(s) " . join ",",@listFeeSchedules);
					}
					elsif ($count_type > 1)
					{
						$self->invalidate($page,"[<B>P$line</B>]Procedure found in multiple fee schedules.");
					}
					elsif(length($fs_entry->[0]->[$INTELLICODE_FS_SERV_TYPE]) < 1)
					{ 	
						$self->invalidate($page,"[<B>P$line</B>]Check that Service Type is set for Fee Schedule Entry '$childCode' in fee schedule $fs_entry->[0]->[$INTELLICODE_FS_ID_NUMERIC]" );
					}
				}
			}
		}
	}
}

sub getMultiPricesHtml
{
	my ($self, $page, $line, $fsResults) = @_;

	my $html = qq{[<B>P$line</B>] Multiple prices found.  Please select a price for this line item.};

	foreach (@$fsResults)
	{
		my $cost = sprintf("%.2f", $_->[1]);
		$html .= qq{
			<input onClick="document.dialog._f_proc_$line\_charges.value=this.value" 
				type=radio name='_f_multi_price' value=$cost>\$$cost
		};
	}

	return $html;
}

sub getMultiSvcTypesHtml
{
	my ($self, $page,$line,$code,  $fsResults) = @_;

	my $html = qq{[<B>P$line</B>] Multiple fee schedules have code '$code'.  Please select a fee schedule to use for this item.};
	my $count=0;
	foreach (@$fsResults)
	{
		my $svc_name=$_->[$INTELLICODE_FS_ID_TEXT];
		$html .= qq{
			<input onClick="document.dialog._f_proc_$line\_use_fee.value=this.value" 
				type=radio name='_f_multi_svc_type_$line' value=$count>$svc_name
		};	
		$count++;
	}

	return $html;
}


sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	my $sessOrgIntId = $page->session('org_internal_id');
	my $sessUser = $page->session('person_id');
	my $invoiceId = $page->param('invoice_id');
	my $isHospClaim = $page->param('isHosp');

	my $bgColorAttr;
	my $textFontAttrs = 'SIZE=1 FACE="Tahoma,Arial,Helvetica" STYLE="font-family:tahoma; font-size:8pt"';
	my $spacerHtml = '&nbsp;';

	#used for hospital claims
	my $servProviderHtml;
	my $billProviderHtml;

	#get all provider ids for session org to be used for hospital claims
	my $providerIds = $STMTMGR_PERSON->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selPersonBySessionOrgAndCategory', $sessOrgIntId, 'Physician');

	#two lines below have been removed. service code is being determined in encounter.pm according to the service org that was selected
	my $svcFacility = $page->field('service_facility_id') || $page->field('hospital_id') || $sessOrgIntId;
	my $svcPlaceCode = $STMTMGR_ORG->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttribute', $svcFacility, 'HCFA Service Place');
	my $cptOrgCodes = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selTop15CPTsByORG', $sessOrgIntId);
	my $icdOrgCodes = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selTop15ICDsByORG', $sessOrgIntId);
	my $cptPerCodes = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selTop15CPTsByPerson', $sessUser);
	my $icdPerCodes = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selTop15ICDsByPerson', $sessUser);
	my $servicePlaceIds = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAllServicePlaceId');
	my $serviceTypeIds = $STMTMGR_CATALOG->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selAllServiceTypeId');

	my $cptOrgHtml;
	foreach my $cptOrgCode (@{$cptOrgCodes})
	{
		$cptOrgHtml = $cptOrgHtml . qq{ <OPTION>$cptOrgCode->{parent_id}</OPTION> };
	}
	my $icdOrgHtml;
	foreach my $icdOrgCode (@{$icdOrgCodes})
	{
		$icdOrgHtml = $icdOrgHtml . qq{ <OPTION>$icdOrgCode->{parent_id}</OPTION> };
	}
	my $cptPerHtml;
	foreach my $cptPerCode (@{$cptPerCodes})
	{
		$cptPerHtml = $cptPerHtml . qq{ <OPTION>$cptPerCode->{parent_id}</OPTION> };
	}
	my $icdPerHtml;
	foreach my $icdPerCode (@{$icdPerCodes})
	{
		$icdPerHtml = $icdPerHtml . qq{ <OPTION>$icdPerCode->{parent_id}</OPTION> };
	}
	my $placeHtml;
	foreach my $placeId (@{$servicePlaceIds})
	{
		$placeHtml = $placeHtml . qq{ <OPTION>$placeId->{id}</OPTION> };
	}
	my $serviceTypeHtml;
	foreach my $serviceTypeId (@{$serviceTypeIds})
	{
		$serviceTypeHtml = $serviceTypeHtml . qq{ <OPTION>$serviceTypeId->{id}</OPTION> };
	}

	my @lineMsgs = ();
	if(my @messages = $page->validationMessages($self->{name}))
	{
		foreach (@messages)
		{
			if(m/\[\<B\>P(\d+)\<\/B\>\]/)
			{
				push(@{$lineMsgs[$1]}, $_);
			}
			else
			{
				push(@{$lineMsgs[0]}, $_);
			}
		}
	}

	#determine if fields should be read only (if claim is not primary, all fields except for diag codes {_f_proc_diags} are read only)
	my $readOnly;
	if($invoiceId)
	{
		my $submitOrder = $page->field('submission_order');
		$readOnly = $submitOrder > 0 ? 'READONLY' : '';
	}


	my $errorMsgsHtml;
	my ($dialogName, $lineCount, $allowComments, $allowQuickRef, $allowRemove) = ($dialog->formName(), $self->{lineCount}, $self->{allowComments}, $self->{allowQuickRef}, $dlgFlags & CGI::Dialog::DLGFLAG_UPDATE);
	my ($linesHtml, $numCellRowSpan, $removeChkbox) = ('', $allowComments ? 'ROWSPAN=2' : '', '');

	#determine the procedure line count
	if($command eq 'add')
	{
		$lineCount = $isHospClaim ? 10 : $lineCount;
	}
	else
	{
		my $procedures = $STMTMGR_INVOICE->getRowsAsHashList($page, STMTMGRFLAG_NONE, 'selInvoiceProcedureItems', $invoiceId, App::Universal::INVOICEITEMTYPE_SERVICE, App::Universal::INVOICEITEMTYPE_LAB);
		$lineCount = scalar(@{$procedures});
	}

	for(my $line = 1; $line <= $lineCount; $line++)
	{
		#show the 'void' checkboxes if command is 'update'
		$removeChkbox = $allowRemove ? qq{<TD ALIGN=CENTER $numCellRowSpan><INPUT TYPE="CHECKBOX" NAME='_f_proc_$line\_remove'></TD>} : '';


		#create html for error messages, if any
		if(ref $lineMsgs[$line] eq 'ARRAY' && @{$lineMsgs[$line]})
		{
			$errorMsgsHtml = "<font $dialog->{bodyFontErrorAttrs}>" . join("<br>", @{$lineMsgs[$line]}) . "</font>";
			$numCellRowSpan = $allowComments ? 'ROWSPAN=3' : 'ROWSPAN=2';
		}
		else
		{
			$numCellRowSpan = $allowComments ? 'ROWSPAN=2' : '';
		}


		#create html for provider fields and select options for service/billing provider fields if this is a hospital claim
		if($isHospClaim)
		{
			my $selected;
			my $servProviderOptionsHtml;
			my $billProviderOptionsHtml;
			foreach my $serviceProvId (@{$providerIds})
			{
				$selected = $serviceProvId->{person_id} eq $page->param("_f_proc_$line\_service_provider_id") ? 'SELECTED' : '';
				$servProviderOptionsHtml .= qq{ <OPTION $selected>$serviceProvId->{person_id}</OPTION> };				
			}

			foreach my $billingProvId (@{$providerIds})
			{
				$selected = $billingProvId->{person_id} eq $page->param("_f_proc_$line\_billing_provider_id") ? 'SELECTED' : '';
				$billProviderOptionsHtml .= qq{ <OPTION $selected>$billingProvId->{person_id}</OPTION> };				
			}

			$servProviderHtml = qq{<TD><NOBR><SELECT NAME="_f_proc_$line\_service_provider_id">$servProviderOptionsHtml</SELECT></NOBR></TD>};
			$billProviderHtml = qq{<TD><NOBR><SELECT NAME="_f_proc_$line\_billing_provider_id">$billProviderOptionsHtml</SELECT></NOBR></TD>};
		}


		#create html for emg field
		my $emg = $page->param("_f_proc_$line\_emg");
		my $checked = $emg eq 'on' ? 'CHECKED' : '';
		my $emgHtml = "<INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_emg' ID='_f_proc_$line\_emg' VALUE='on' TYPE='CHECKBOX' $checked><FONT $textFontAttrs/><LABEL FOR='_f_proc_$line\_emg'>Emergency</LABEL></FONT>";


		$linesHtml .= qq{
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_fs_used" VALUE='@{[ $page->param("_f_proc_$line\_fs_used")]}'/>
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_item_id" VALUE='@{[ $page->param("_f_proc_$line\_item_id")]}'/>
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_actual_diags" VALUE='@{[ $page->param("_f_proc_$line\_actual_diags")]}'/>
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_ffs_flag" VALUE='@{[ $page->param("_f_proc_$line\_ffs_flag")]}'/>			
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_service_type" TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_service_type")]}'/>
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_use_fee" TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_use_fee")]}'/>
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_code_type" TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_code_type")]}'/>
			<INPUT TYPE="HIDDEN" NAME="_f_proc_$line\_prev_code" TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_prev_code")]}'/>

			<TR VALIGN=TOP>
				<SCRIPT>
					function onChange_dosBegin_$line(event, flags)
					{
						if(event.srcElement.value == 'From')
							event.srcElement.value = '0';
						event.srcElement.value = validateDate(event.srcElement.name, event.srcElement.value);
						if(document.$dialogName._f_proc_$line\_dos_end.value == '' || document.$dialogName._f_proc_$line\_dos_end.value == 'To')
							document.$dialogName._f_proc_$line\_dos_end.value = event.srcElement.value;
						if(event.srcElement.value != '')
						{
							<!--- if(document.$dialogName._f_proc_$line\_service_type.value == '') --->
							<!----	document.$dialogName._f_proc_$line\_service_type.value = '01'; --->
							if(document.$dialogName._f_proc_$line\_units.value == '')
								document.$dialogName._f_proc_$line\_units.value = 1;
							if(document.$dialogName._f_proc_$line\_diags.value == '')
								document.$dialogName._f_proc_$line\_diags.value = 1;
						}
					}
					function onChange_dosEnd_$line(event, flags)
					{
						if(event.srcElement.value == 'To')
							event.srcElement.value = '0';
						event.srcElement.value = validateDate(event.srcElement.name, event.srcElement.value);
						if(document.$dialogName._f_proc_$line\_dos_end.value == '' || document.$dialogName._f_proc_$line\_dos_end.value == 'To')
							document.$dialogName._f_proc_$line\_dos_end.value = document.$dialogName._f_proc_$line\_dos_begin.value;
						if(document.$dialogName._f_proc_$line\_dos_end.value <  document.$dialogName._f_proc_$line\_dos_begin.value)
							alert("'To' date must be same or after 'From' date");

						if(event.srcElement.value != '')
						{
							//if(document.$dialogName._f_proc_$line\_units.value == '' || document.$dialogName._f_proc_$line\_units.value == 1)
								document.$dialogName._f_proc_$line\_units.value = dateDiff(document) + 1;

							function dateDiff(document)
							{
								date1 = new Date();
								date2 = new Date();
								diff  = new Date();

								if(document.$dialogName._f_proc_$line\_dos_end.value != '' && document.$dialogName._f_proc_$line\_dos_end.value != 'To') 
								{
									date1temp = new Date(document.$dialogName._f_proc_$line\_dos_end.value);
									date1.setTime(date1temp.getTime());
								}
								if(document.$dialogName._f_proc_$line\_dos_begin.value != '' && document.$dialogName._f_proc_$line\_dos_begin.value != 'From') 
								{
									date2temp = new Date(document.$dialogName._f_proc_$line\_dos_begin.value);
									date2.setTime(date2temp.getTime());
								}

								// sets difference date to difference of first date and second date

								diff.setTime(Math.abs(date1.getTime() - date2.getTime()));

								timediff = diff.getTime();
								
								days = Math.floor(timediff / (1000 * 60 * 60 * 24)); 
								timediff = days * (1000 * 60 * 60 * 24);
								return days;
							}
						}
					}
					function onChange_procedure_$line(event, flags)
					{
						if(document.$dialogName._f_proc_$line\_modifier.value == 'Modf')
							document.$dialogName._f_proc_$line\_modifier.value = '';
						document.$dialogName._f_proc_$line\_charges.value = '';
						document.$dialogName._f_proc_$line\_service_type.value = '';						
					}
					function getFFS(event)
					{			
						if (eval("document.$dialogName._f_payer") && document.$dialogName._f_payer.options[document.$dialogName._f_payer.selectedIndex].value.search(/Primary/)==0)
						{				
							document.$dialogName._f_proc_all_catalogs.value = document.$dialogName._f_proc_default_catalog.value ? 
									document.$dialogName._f_proc_default_catalog.value : document.$dialogName._f_ins_ffs.value;
							//document.$dialogName._f_proc_all_catalogs.value = 
							//document.$dialogName._f_ins_ffs.value + "," +
							//document.$dialogName._f_proc_default_catalog.value ;
						}
						else if (eval("document.$dialogName._f_payer") && document.$dialogName._f_payer.options[document.$dialogName._f_payer.selectedIndex].value.search(/Work Comp/)==0)
						{							
							document.$dialogName._f_proc_all_catalogs.value = document.$dialogName._f_proc_default_catalog.value ? 
									document.$dialogName._f_proc_default_catalog.value : document.$dialogName._f_ins_ffs.value;
						}
						else
						{
							document.$dialogName._f_proc_all_catalogs.value = document.$dialogName._f_proc_default_catalog.value ? 
									document.$dialogName._f_proc_default_catalog.value : document.$dialogName._f_ins_ffs.value;
						}
																	
					}
				</SCRIPT>
				<TD ALIGN=RIGHT $numCellRowSpan><FONT $textFontAttrs COLOR="#333333"/><B>$line</B></FONT></TD>
				$removeChkbox
				<TD><INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_dos_begin' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_dos_begin") || 'From' ]}' ONBLUR="onChange_dosBegin_$line(event)"><BR>
					<INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_dos_end' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_dos_end") || 'To' ]}' ONBLUR="onChange_dosEnd_$line(event)"></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><NOBR><INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_procedure' TYPE='text' size=8 VALUE='@{[ $page->param("_f_proc_$line\_procedure") || ($line == 1 ? 'Procedure' : '') ]}' ONBLUR="onChange_procedure_$line(event)">
										<A HREF="javascript:getFFS();doFindLookup(document.$dialogName, document.$dialogName._f_proc_$line\_procedure, '/lookup/feeprocedure/itemValue',null,false,null,document.$dialogName._f_proc_all_catalogs);"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR><BR>
					<INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_modifier' TYPE='text' size=4 VALUE='@{[ $page->param("_f_proc_$line\_modifier") || ($line == 1 && $command eq 'add' ? '' : '') ]}'>
										<A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_$line\_modifier, '/lookup/modifier', ',', false);"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_diags' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_diags") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_units' TYPE='text' size=3 VALUE='@{[ $page->param("_f_proc_$line\_units") ]}'></TD>
				<TD><FONT SIZE=1>&nbsp;</FONT></TD>
				<TD><INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_charges' TYPE='text' size=10 VALUE='@{[ $page->param("_f_proc_$line\_charges") ]}'></TD>
				<TD><nobr>$emgHtml</nobr></TD>
				$servProviderHtml
				$billProviderHtml
			</TR>
		};
		
		$linesHtml .= qq{
			<TR>
				<TD COLSPAN=4 ALIGN=RIGHT><FONT $textFontAttrs><I>Comments:</I></FONT></TD>
				<TD COLSPAN=8><INPUT $readOnly CLASS='procinput' NAME='_f_proc_$line\_comments' TYPE='text' size=50 VALUE='@{[ $page->param("_f_proc_$line\_comments") ]}'></TD>
			</TR>
		} if $allowComments;

		$linesHtml .= qq{
			<TR>
				<TD COLSPAN=12>$errorMsgsHtml</TD>
			</TR>
		} if $errorMsgsHtml;
	}

	my $lineZeroErrMsgs = '';
	if(ref $lineMsgs[0] eq 'ARRAY' && @{$lineMsgs[0]})
	{
		$lineZeroErrMsgs = "<font $dialog->{bodyFontErrorAttrs}>" . join("<br>", @{$lineMsgs[0]}) . "</font>";
	}

	my $nonLinesHtml = qq{
		<TR>
			<TD COLSPAN=5>$lineZeroErrMsgs</TD>
		</TR>
	} if $lineZeroErrMsgs;

	my $quickRefHtml = qq{
			<TD>
				<TABLE CELLSPACING=0 CELLPADDING=2 BORDER=1>
					<TR VALIGN=TOP>
						<TD BGCOLOR=#DDDDDD><FONT $textFontAttrs>My ICDs</FONT><BR>
						<NOBR><SELECT SIZE=5 NAME="_f_myproc_diags_static" >@{[ $icdPerHtml ]} </SELECT></NOBR></TD>
						<TD BGCOLOR=#DDDDDD><FONT $textFontAttrs>Our ICDs</FONT><BR>
						<NOBR><SELECT SIZE=5 NAME="_f_ourproc_diags_static" >@{[ $icdOrgHtml ]} </SELECT></NOBR></TD>
					</TR>
					<TR VALIGN=TOP>
						<TD BGCOLOR=#DDDDDD><FONT $textFontAttrs>My CPTs</FONT><BR>
						<NOBR><SELECT SIZE=5 NAME="_f_myproc_cpts_static" >@{[ $cptPerHtml ]} </SELECT></NOBR></TD>
						<TD BGCOLOR=#DDDDDD><FONT $textFontAttrs>Our CPTs</FONT><BR>
						<NOBR><SELECT SIZE=5 NAME="_f_ourproc_cpts_static" >@{[ $cptOrgHtml ]} </SELECT></NOBR></TD>
					</TR>
					<TR VALIGN=TOP>
						<TD BGCOLOR=#DDDDDD COLSPAN=2><FONT $textFontAttrs>Service Places/Types</FONT><BR>
						<NOBR><SELECT SIZE=5 NAME="_f_places_static" >@{[ $placeHtml ]} </SELECT></NOBR>
						<NOBR><SELECT SIZE=5 NAME="_f_types_static" >@{[ $serviceTypeHtml ]} </SELECT></NOBR>
						</TD>
					</TR>
				</TABLE>
			</TD>
	} if $allowQuickRef;

	my $removeHd = $allowRemove ? qq{<TD ALIGN=CENTER><FONT $textFontAttrs><IMG SRC="/resources/icons/action-edit-remove-x.gif"></FONT></TD>} : '';
	my $providerHd = $isHospClaim ? qq{<TD><FONT SIZE=1>&nbsp;</FONT></TD><TD ALIGN=CENTER  COLSPAN=2><FONT $textFontAttrs>Providers<BR>Service/Billing</FONT></TD>} : '';
	return qq{
		<TR valign=top $bgColorAttr>
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
			<TD COLSPAN=2>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<INPUT TYPE="HIDDEN" NAME="_f_proc_active_catalogs" VALUE='@{[ $page->param("_f_proc_active_catalogs") ]}'/>
					<INPUT TYPE="HIDDEN" NAME="_f_proc_all_catalogs" VALUE='@{[ $page->param("_f_proc_all_catalogs") ]}'/>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD><FONT $textFontAttrs>Diagnoses (ICD-9s)</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<!-- <TD><FONT $textFontAttrs>Service Place</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD> -->
						<TD><FONT $textFontAttrs>Default Fee Schedule(s)</FONT></TD>
					</TR>
					<TR VALIGN=TOP>
						<TD><NOBR><INPUT TYPE="TEXT" SIZE=20 NAME="_f_proc_diags"  VALUE='@{[ $page->param("_f_proc_diags") ]}'>
							<A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_diags, '/lookup/icd', ',', false);"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD><INPUT $readOnly TYPE="TEXT" SIZE=20 NAME="_f_proc_default_catalog"  VALUE='@{[ $page->param("_f_proc_default_catalog") ]}'>
							<A HREF="javascript:doFindLookup(document.$dialogName, document.$dialogName._f_proc_default_catalog, '/lookup/catalog', ',', false);"><IMG SRC="/resources/icons/magnifying-glass-sm.gif" BORDER=0></A></NOBR></TD>
					</TR>
					$nonLinesHtml
				</TABLE>
				<TABLE CELLSPACING=0 CELLPADDING=2>
					<INPUT TYPE="HIDDEN" NAME="_f_line_count" VALUE="$lineCount"/>
					<TR VALIGN=TOP BGCOLOR=#DDDDDD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>&nbsp;</FONT></TD>
						$removeHd
						<TD ALIGN=CENTER><FONT $textFontAttrs>Dates</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>CPT/Modf</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Diagnoses</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Units</FONT></TD>
						<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>Charge</FONT></TD>
						<!--<TD><FONT SIZE=1>&nbsp;</FONT></TD>
						<TD ALIGN=CENTER><FONT $textFontAttrs>EMG</FONT></TD>-->
						$providerHd
					</TR>
					$linesHtml
				</TABLE>
			</TD>
			$quickRefHtml
			<TD width=$self->{_spacerWidth}>$spacerHtml</TD>
		</TR>
	};
}

1;
