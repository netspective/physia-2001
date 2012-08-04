##############################################################################
package App::Data::Obtain::OneTime::PatToby;
############################################################################

use strict;
use App::Data::Manipulate;
use App::Data::Obtain::Excel;
use vars qw(@ISA $VERSION);
use Win32::OLE;
use Lingua::EN::NameParse;






@ISA = qw(App::Data::Obtain::Excel);
$VERSION = "1.00";


my $gFName;
my $gLName;
my $gMName;
my $gSuffix;

open (FILEHANDLE, ">error.dat");

sub code
{
	return 200;
}


sub obtain
{
	my ($self, $flags, $collection, %params) = @_;
	$flags = $self->setupFlags($flags);

	unless($params{srcFilePatData})
	{
		$self->addError("srcFilePatData parameters are required");
		return;
	}

	$self->reportMsg("Opening Excel.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $excel;
	eval {$excel = Win32::OLE->GetActiveObject('Excel.Application')};
	if($@)
	{
		$self->addError("Microsoft Excel does not seem to be installed: $@");
		return;
	}
	unless(defined $excel)
	{
		$excel = Win32::OLE->new('Excel.Application', sub {$_[0]->Quit;});
		unless($excel)
		{
			$self->addError("Unable to start Microsoft Excel");
			return;
		}
	}

	$self->reportMsg("Opening workbook $params{srcFilePatData}.") if $flags & DATAMANIPFLAG_VERBOSE;
	# open the file
	my $bookPatData = $excel->Workbooks->Open($params{srcFilePatData});
	unless($bookPatData)
	{
		$self->addError("Unable to open Excel file $params{srcFilePatData}: $!");		
		undef $excel;
		return;
	}

	#return; 
	$self->process($flags, $collection, \%params, $excel,$bookPatData);

	$self->reportMsg("Closing Excel.") if $flags & DATAMANIPFLAG_VERBOSE;
	undef $bookPatData;
	#undef $bookLocal;
	undef $excel;
}


sub ParseName 
{
	my ($self, $name,$type) = @_;
	my $parseName;
	my @nameArray = split (/,/,$name);
	my $lName;
	my $fName;
	my $mName;
	my $suffix;
	my $fullName;
	my $size = scalar(@nameArray);
	

	#my $error = $pName->parse($name);	
	#my %name_comps = $pName->components;
	#foreach my $key (keys %name_comps)
	#{
	#	print "1\n";
	#	$gLName = $name_comps{given_name_1};
	#	$gFName = $name_comps{surname_1};				
	#};
	#die "DONE";	
	#return;
	$gFName='';
	$gLName='';
	$gMName=='';
	$gSuffix=='';
	
	if ($size == 3)
	{
		#Last, Middle Suffix or MD, First Name
		#print $name;
		$lName = $nameArray[0];
		$suffix = $nameArray[1];
		$fName = $nameArray[2];		
		$gFName = $fName;
		$gMName ='';
		$gLName = $lName;
		$gSuffix = $suffix;
		#print " [$nameArray[0]] [$nameArray[1]] [$nameArray[2]]\n" ;
		
	}
	elsif ($size == 2)
	{
		if($type ne 'RP')
		{
			#Last,  First Name, Middle
			#Check Last Name for suffix
			my @name2 = split(' ',$nameArray[0]);	
			$lName = $nameArray[0];
			$suffix = '';#$name2[1];
			$lName =~s/\'/\'\'/;	
			#Check for Middle Name
			my @name2= split(' ',$nameArray[1]);
			$fName = $name2[0];
			$mName = $name2[1];
			$gFName = $fName;
			$gMName = $mName;
			$gLName = $lName;
			$gSuffix = $suffix;	
		}
		else
		{
			#Last,  First Name, Middle
			#Check Last Name for suffix
			my @name2 = split(' ',$nameArray[0]);	
			if (scalar(@name2)>1)
			{
				$mName = $name2[0];
				$lName = $name2[1];
				$fName = $nameArray[1];
				$suffix = '';
				print FILEHANDLE "Warning Check $type Name :  $name L->[$lName] M->[$mName] F->[$fName] \n ";
			}
			else
			{
				$lName = $nameArray[0];
				$suffix = '';
				$lName =~s/\'/\'\'/;					
				#Check for Middle Name
				my @name2= split(' ',$nameArray[1]);
				$fName = $name2[0];
				$mName = $name2[1];
			}
				$gFName = $fName;
				$gMName = $mName;
				$gLName = $lName;				
				$gSuffix = $suffix;	
		
		}
	}
	elsif ($size ==0)
	{
		
		$gFName = '';
		$gMName = '';
		$gLName = '';
		$gSuffix = '';	
	}
	else
	{
		print FILEHANDLE "Check $type Name :  $name\n ";
		$gFName = $name;
	}

}
sub process
{
	my ($self, $flags, $collection, $params, $excel, $book) = @_;

	# cycle through the rows
	$self->reportMsg("Acquiring worksheet.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $sheetGPCIId = exists $params->{worksheet} ? $params->{worksheet} : 1;
	my $sheet = $book->Worksheets($sheetGPCIId );
	unless($sheet)
	{
				$self->addError("Unable to acquire worksheet '$sheetGPCIId' in $params->{srcFilePatData}  $!");
				undef $book;
				undef $excel;
				return;
	}
	my $data = $collection->{data};	

	$self->reportMsg("Loading rows.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $rowIdx = 2; #skip the first rows (the headings)
	my ($range, $row);
	my $rowCount=0;
	my $valueStore;
	while($range = $sheet->Range("A$rowIdx:AG$rowIdx")->{Value})
	{
		my $row = $range->[0];
		my ($patName,$address,$cityStateZip,$phone,$ssn,$DOB,
			$rpName,$rpPhone,$rpSSN,$rpDOB,
			$gender,
			$policyNumber,$group,$policyHolder,
			$policyNumber2,$group2,$policyHolder2,
			$medicare,$medicaid	,$plan_id,$rel,	$plan_id2, $ownerplan, $ownerplan2,
			$chart,$doc,$ref_doc,$visit
		) = (	$row->[0] , $row->[1],$row->[2],$row->[3],$row->[4],$row->[5]
			,$row->[6],$row->[7],$row->[8],$row->[9]
			,$row->[11]
			,$row->[20],$row->[21],$row->[22]
			,$row->[26],$row->[27],$row->[28],
			,$row->[31],$row->[32],$row->[19],$row->[23],$row->[25],
			$row->[22], $row->[28],$row->[10],$row->[13],$row->[14],$row->[16] );
		
		#Set Size limits for some fields
		$DOB = substr($DOB,0,9);
		$rpDOB = substr($rpDOB,0,9);	
		

		$self->ParseName($patName,"Patient");		
		my $fName  = App::Data::Manipulate::trim($gFName);
		my $mName  = App::Data::Manipulate::trim($gMName);
		my $suffix = App::Data::Manipulate::trim($gSuffix);	
		my $lName  = App::Data::Manipulate::trim($gLName);	
		#$lName = ~s/\'/\'\'/;	
		$self->ParseName($rpName,"RP");
		my $rpFName  = App::Data::Manipulate::trim($gFName);
		my $rpMName  = App::Data::Manipulate::trim($gMName);
		my $rpSuffix = App::Data::Manipulate::trim($gSuffix);	
		my $rpLName  = App::Data::Manipulate::trim($gLName);	
		#$rpLName = ~s/\'/\'\'/;	
		$self->ParseName($ownerplan,"OWNER");
		my $oFName = App::Data::Manipulate::trim($gFName);
		my $oMName = App::Data::Manipulate::trim($gMName);
		my $oSuffix= App::Data::Manipulate::trim($gSuffix);			
		my $oLName = App::Data::Manipulate::trim($gLName);				
		#$oLName = ~s/\'/\'\'/;			
		$self->ParseName($ownerplan2,"OWNER2");
		my $o2FName  = App::Data::Manipulate::trim($gFName);
		my $o2MName  = App::Data::Manipulate::trim($gMName);
		my $o2Suffix = App::Data::Manipulate::trim($gSuffix);	
		my $o2LName  = App::Data::Manipulate::trim($gLName);				
		#$o2LName = ~s/\'/\'\'/;			
		
		my @cityState = split(',',$cityStateZip);
		my $city = ($cityState[0]);
		my @cityState2 = split(' ',$cityState[1]);		
		my $state = $cityState2[0];
		my $zip = $cityState2[1];
				
		
		if (uc($gender) eq 'M')
		{
			$gender = 1;
		}
		elsif (uc($gender) eq 'F')
		{
			$gender = 2;
		}
		else
		{
			$gender = 0;
		}
		
		
		my $personID = uc(substr($lName,0,11)) . $rowCount;
		my $rpID = uc(substr($rpLName,0,10)) . $rowCount . "G" ;	
		$ssn =substr($ssn,0,11);
		$rpSSN =substr($ssn,0,11);		
		#DATE CHECK
		my @dobSplit = split ("/",$DOB);
		$DOB = $dobSplit[0] ."/" . $dobSplit[1] . "/19" . $dobSplit[2];
		@dobSplit = split ("/",$rpDOB);
		$rpDOB = $dobSplit[0] ."/" . $dobSplit[1] . "/19" . $dobSplit[2];
		$rowCount++;
		$rowIdx++;
		if (!($DOB =~ m/([\d][\d])\/([\d][\d])\/([\d][\d])/ || !$DOB))		
		{
			#$self->reportMsg("BAD $personID $DOB");
			#return;
			$DOB='';
		}
		if (!($rpDOB =~ m/([\d][\d])\/([\d][\d])\/([\d][\d])/ || !$rpDOB))		
		{
			#$self->reportMsg("BAD  $rpID $rpDOB");
			$rpDOB='';
			#return;
		}	
		if (!($visit =~ m/([\d][\d])\/([\d][\d])\/([\d][\d])/ || !$visit))		
		{
			#$self->reportMsg("BAD  $rpID $rpDOB");
			$visit='';
			#return;
		}			
		#$self->reportMsg(" F ->[$fName] M ->[$mName]  L -> [$lName] S -> [$suffix]"); 
		$ref_doc =uc($ref_doc);
		#return if $rowCount > 200;
		return unless $patName;
		$self->updateMsg("read $rowIdx rows")	if ($rowIdx % 500 == 0) && ($flags & DATAMANIPFLAG_SHOWPROGRESS);		
		push(@$data,[$personID, $lName,$fName, $mName,$phone,$ssn,$DOB,$gender,$plan_id,$address,
		$city,$state,$zip,$rpLName,$rpFName,$rpMName,$rpPhone,$rpSSN,$rpDOB, $policyNumber,
		$group,$policyHolder,$policyNumber2,$group2,$policyHolder2,$medicare,$medicaid,$rel,$rpID,$plan_id2,
		$oLName,$oFName,$oMName,
		$o2LName,$o2FName,$o2MName,$suffix,$rpSuffix,$oSuffix,$o2Suffix,
		$chart,$doc,$ref_doc,$visit] );
				
	}	

	$self->reportMsg("$rowCount rows read from $params->{srcFilePatData}") if $flags & DATAMANIPFLAG_SHOWPROGRESS;
	
	
	#for  my $key (keys %{$gpciData})
	#{
	#	my $pull=$gpciData->{$key};
	#	my $pullLoc=$locData->{$key};		
	#	push(@$data,[$pull->{code}, $pull->{number},$pullLoc->{loc},$pullLoc->{state},
	#	$pullLoc->{county},$pull->{work}, $pull->{pe},$pull->{mp}]);
	#}
	
	#$self->reportMsg("Preparing Data.") if $flags & DATAMANIPFLAG_VERBOSE;

	
	
}


1;


##############################################################################
package App::Data::Obtain::OneTime::PatToby::RefDoc;
############################################################################

use strict;
use App::Data::Manipulate;
use App::Data::Obtain::Excel;
use vars qw(@ISA $VERSION);
use Win32::OLE;


my $gFName;
my $gLName;
my $gMName;
my $gSuffix;

open (FILEHANDLE, ">error2.dat");

@ISA = qw(App::Data::Obtain::Excel);
$VERSION = "1.00";

sub code
{
	return 200;
}

sub ParseName 
{
	my ($self, $name,$type) = @_;
	my $parseName;
	my @nameArray = split (/,/,$name);
	my $lName;
	my $fName;
	my $mName;
	my $suffix;
	my $fullName;
	my $size = scalar(@nameArray);
	

	#my $error = $pName->parse($name);	
	#my %name_comps = $pName->components;
	#foreach my $key (keys %name_comps)
	#{
	#	print "1\n";
	#	$gLName = $name_comps{given_name_1};
	#	$gFName = $name_comps{surname_1};				
	#};
	#die "DONE";	
	#return;
	$gFName='';
	$gLName='';
	$gMName=='';
	$gSuffix=='';
	
	if($size==4)
	{
		#Last, Middle Suffix or MD, First Name
		#print $name;
		#Check if last name has a suffix
		if(App::Data::Manipulate::trim($nameArray[2]) ne '')
		{
			$lName = $nameArray[0] ." $nameArray[1]";
			$fName = $nameArray[2];		
			$suffix = $nameArray[3];		
		}
		else
		{
			$lName = $nameArray[0]; 
			$fName = $nameArray[1];		
			$suffix = $nameArray[3];					
			print FILEHANDLE "Warning (2) Check $type Name :  $name L->[$lName] M->[$mName] F->[$fName] \n ";
		}
		
		$gFName = $fName;
		$gMName ='';
		$gLName = $lName;
		$gSuffix = $suffix;
	}
	elsif ($size == 3)
	{
		#Last, Middle Suffix or MD, First Name
		#print $name;
		#Check if last name has a suffix
		if(App::Data::Manipulate::trim($nameArray[1]) ne '')
		{
			$lName = $nameArray[0];
			$suffix = $nameArray[2];
			$fName = $nameArray[1];		
		}
		else
		{
			my @name2 = split ' ',$nameArray[0];
			$lName = $name2[0];
			$suffix = $nameArray[2];
			$fName = $name2[1];	
			print FILEHANDLE "Warning (3) Check $type Name :  $name L->[$lName] M->[$mName] F->[$fName] \n ";			
		}
		$gFName = $fName;
		$gMName ='';
		$gLName = $lName;
		$gSuffix = $suffix;
		#print " [$nameArray[0]] [$nameArray[1]] [$nameArray[2]]\n" ;
		
	}
	elsif ($size == 2)
	{
	
		#Last,  First Name, Middle
		#Check Last Name for suffix
		my @name2 = split(' ',$nameArray[0]);	
		$lName = $nameArray[0];
		$suffix = '';#$name2[1];
		$lName =~s/\'/\'\'/;	
		#Check for Middle Name
		my @name2= split(' ',$nameArray[1]);
		$fName = $name2[0];
		$mName = $name2[1];
		$gFName = $fName;
		$gMName = $mName;
		$gLName = $lName;
		$gSuffix = $suffix;	
	}
	elsif ($size ==0)
	{
		
		$gFName = '';
		$gMName = '';
		$gLName = '';
		$gSuffix = '';	
	}
	else
	{
		print FILEHANDLE "Check $type Name :  $name\n ";
		$gFName = $name;
	}
	$gLName  =~s/\'//;
	$gFName  =~s/\'/\'\'/;	
	$gMName  =~s/\'/\'\'/;		
	$gSuffix  =~s/\'/\'\'/;			
	my @array =($gFName,$gMName,$gLName,$gSuffix);
	return @array;

}

sub obtain
{
	my ($self, $flags, $collection, %params) = @_;
	$flags = $self->setupFlags($flags);

	unless($params{srcFilePatData})
	{
		$self->addError("srcFilePatData parameters are required");
		return;
	}

	$self->reportMsg("Opening Excel.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $excel;
	eval {$excel = Win32::OLE->GetActiveObject('Excel.Application')};
	if($@)
	{
		$self->addError("Microsoft Excel does not seem to be installed: $@");
		return;
	}
	unless(defined $excel)
	{
		$excel = Win32::OLE->new('Excel.Application', sub {$_[0]->Quit;});
		unless($excel)
		{
			$self->addError("Unable to start Microsoft Excel");
			return;
		}
	}

	$self->reportMsg("Opening workbook $params{srcFilePatData}.") if $flags & DATAMANIPFLAG_VERBOSE;
	# open the file
	my $bookPatData = $excel->Workbooks->Open($params{srcFilePatData});
	unless($bookPatData)
	{
		$self->addError("Unable to open Excel file $params{srcFilePatData}: $!");		
		undef $excel;
		return;
	}

	#return; 
	$self->process($flags, $collection, \%params, $excel,$bookPatData);

	$self->reportMsg("Closing Excel.") if $flags & DATAMANIPFLAG_VERBOSE;
	undef $bookPatData;
	#undef $bookLocal;
	undef $excel;
}


sub process
{
	my ($self, $flags, $collection, $params, $excel, $book) = @_;

	# cycle through the rows
	$self->reportMsg("Acquiring worksheet.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $sheetGPCIId = exists $params->{worksheet} ? $params->{worksheet} : 1;
	my $sheet = $book->Worksheets($sheetGPCIId );
	unless($sheet)
	{
				$self->addError("Unable to acquire worksheet '$sheetGPCIId' in $params->{srcFilePatData}  $!");
				undef $book;
				undef $excel;
				return;
	}
	my $data = $collection->{data};	

	$self->reportMsg("Loading 2 rows.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $rowIdx = 2; #skip the first rows (the headings)
	my ($range, $row);
	my $rowCount=0;
	my $valueStore;
	while($range = $sheet->Range("A$rowIdx:AG$rowIdx")->{Value})
	{
		my $row = $range->[0];
		my ($id ,$docName,$address,$cityStateZip,$phone,$upin) = 
		($row->[0] , $row->[1],$row->[2],$row->[3],$row->[4],$row->[5]
			,$row->[6],$row->[7],$row->[8],$row->[9]
			,$row->[11]
			,$row->[20],$row->[21],$row->[22]
			,$row->[26],$row->[27],$row->[28],
			,$row->[31],$row->[32],$row->[19],$row->[23]);
		
		my @cityState = split(',',$cityStateZip);
		my $city = ($cityState[0]);
		my @cityState2 = split(' ',$cityState[1]);		
		my $state = $cityState2[0];
		my $zip = $cityState2[1];
		#my @name = split (',',$docName);		
		#my $lName = App::Data::Manipulate::trim($name[0]);		
		#my @name2 = split (',',$name[1]);		
		#my $fName = App::Data::Manipulate::trim($name2[0]);
		#my $mName = App::Data::Manipulate::trim($name2[1]);
		#my @temp = split (' ',$name[0]);
		#unless ($fName)
		#{		
		#	$fName = $temp[0];
		#	$lName = $temp[1];
		#}
		#$lName =~s/\'/\'\'/;
		my @array = $self->ParseName($docName,"REF_DOC");
		my $fName  = App::Data::Manipulate::trim($array[0]);#$gFName);
		my $mName  = App::Data::Manipulate::trim($array[1]);#$gMName);
		my $suffix = App::Data::Manipulate::trim($array[3]);#$gSuffix);	
		my $lName  = App::Data::Manipulate::trim($array[2]);#$gLName);	
		$lName =~s/\'/\'\'/;
		my $personID = uc(substr($lName,0,11)) . uc($id);
		$id =uc($id);
		$rowCount++;
		$rowIdx++;		
		#return if $rowCount > 200;
		return unless $docName;
		$self->updateMsg("read $rowIdx rows")	if ($rowIdx % 500 == 0) && ($flags & DATAMANIPFLAG_SHOWPROGRESS);		
		push(@$data,[$personID, $lName,$fName, $mName,$phone,$upin, $city, $state,$zip,$address,$suffix,$id] );
				
	}	

	$self->reportMsg("$rowCount rows read from $params->{srcFilePatData}") if $flags & DATAMANIPFLAG_SHOWPROGRESS;
	
	
	#for  my $key (keys %{$gpciData})
	#{
	#	my $pull=$gpciData->{$key};
	#	my $pullLoc=$locData->{$key};		
	#	push(@$data,[$pull->{code}, $pull->{number},$pullLoc->{loc},$pullLoc->{state},
	#	$pullLoc->{county},$pull->{work}, $pull->{pe},$pull->{mp}]);
	#}
	
	#$self->reportMsg("Preparing Data.") if $flags & DATAMANIPFLAG_VERBOSE;

	
	
}

1;
