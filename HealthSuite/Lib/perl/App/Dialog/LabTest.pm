##############################################################################
package App::Dialog::LabTest;
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
use App::Statements::Worklist::WorklistCollection;

use CGI::ImageManager;
use Date::Manip;
use Text::Abbrev;
use App::Universal;
use App::Statements::LabTest;

use vars qw(@ISA %RESOURCE_MAP %PROCENTRYABBREV %RESOURCE_MAP %ITEMTOFIELDMAP %CODE_TYPE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'lab-test' => {
		_arl_add =>['internal_catalog_id','catalog_type'],
		_arl_modify => ['entry_id']
	},
);


use constant MAXROWS => 15;
#							postHtml=>qq{<A HREF = javascript:changePanel("$nextPanel",$loop);>$IMAGETAGS{'icons/arrow-down-blue'}</A>}
sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'catalog', heading => '$Command Lab Test');

	my $schema = $self->{schema};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;
	my @request=();
	my $loop;


	my $options=0; 		
	push(@request,
		new CGI::Dialog::DataGrid(
		caption => '',
		name=>'panel',
		rows =>15,
		rowFields =>[
			{
				_class=>'CGI::Dialog::Field',
				name=>'entry_id',
				type=>'hidden',
				caption=>'',
			},		
			{	_class => 'CGI::Dialog::Field',		
				name=>"test_id",
				type=>'text',
				size=>15,
				maxLength=>30,
				caption =>'Test ID',
			},
			{	_class => 'CGI::Dialog::Field',		
				name=>"test_caption",
				type=>'text',
				caption =>'Caption',
				maxLength=>30,
			},
			{	_class => 'CGI::Dialog::Field',		
				name=>"code",
				type=>'text',
				caption =>'Charge Code',
			}	,			
			{	_class => 'CGI::Dialog::Field',		
				name=>"doc_price",
				type=>'currency',
				caption =>'Physician Cost',
			}	,			
			{	_class => 'CGI::Dialog::Field',		
				name=>"pat_price",
				type=>'currency',
				caption =>'Patient Cost',	
			},

		],
	     ),
	    );

	
	my @requestSingle=();
	push (@requestSingle ,	new CGI::Dialog::Field(
					name => 'entry_id',
					type => 'hidden',
				),	
				new CGI::Dialog::Field(
					name => 'lab_type_cap',
					type => 'hidden',
				),					
		new CGI::Dialog::MultiField(caption =>'Test ID/Caption', name => "test",
			#options => FLDFLAG_REQUIRED,
			fields=>[						
					new CGI::Dialog::Field(caption=>"Test ID", type=>'text',
								#options => FLDFLAG_REQUIRED ,
								name=>"test_id",size=>15,maxLength=>30),
					new CGI::Dialog::Field(caption=>"Test Caption", ,
								#options => FLDFLAG_REQUIRED ,
								maxLength=>30,
								name=>"test_caption"),
				],),					
				new CGI::Dialog::Field(caption=>"Charge Code", type=>'text',name=>"code"),			
				new CGI::Dialog::Field(caption=>"Physician Cost", type=>'currency',name=>"doc_price"),			
				new CGI::Dialog::Field(caption=>"Patient Cost", type=>'currency',name=>"pat_price")
				);
	$self->addContent(
		new CGI::Dialog::Field(
			name => 'org_id',
			type => 'text',
			caption => 'Lab Org ID',
			size=>15,
			maxLength=>30,
			options=>FLDFLAG_READONLY,
		),	
		
		new CGI::Dialog::Field(caption => 'Test Type',
			type => 'hidden',
			name=>'test_type',
			options=>FLDFLAG_READONLY
		),		
		new CGI::Dialog::Field( caption => 'Test Selection', 						
					type => 'select',
					selOptions=>"Single:0;Panel:1",					
					name => 'panel_test',
					options => FLDFLAG_REQUIRED,
					onChangeJS => qq{setMode(event);}
					),						
		new CGI::Dialog::MultiField
		(caption =>'Panel ID/Caption', name => "panel_id_name",
			options => FLDFLAG_REQUIRED,
			fields=>[					
				new CGI::Dialog::Field(
					name => 'panel_id',
					type => 'text',
					caption => 'Panel ID',
					size=>15,
					maxLength=>30,
					#options => FLDFLAG_REQUIRED
				),
				new CGI::Dialog::Field(
					name => 'panel_name',
					type => 'text',
					caption => 'Panel Name',
					size=>15,
					maxLength=>30,
					#options => FLDFLAG_REQUIRED			
				),					
				],
			),		
		@requestSingle,
		@request,		
		new CGI::Dialog::Field(
			name => 'internal_catalog_id',
			type => 'hidden',
		),			
		
	);

	$self->{activityLog} =
	{
		scope =>'offering_catalog',
		key => "#field.catalog_id#",
		data => "Order Entry"
	};
	$self->addFooter(new CGI::Dialog::Buttons(nextActions_add => [
				['Add Another Tests', "/org/#param.org_id#/dlg-add-lab-test/#param.internal_catalog_id#", 1],
				['Show Current Tests', "/org/#param.org_id#/catalog?catalog=labtest"],
	],
	 cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}


 sub makeStateChanges
 {
       	my ($self, $page, $command, $dlgFlags) = @_;
       	$self->SUPER::makeStateChanges($page, $command, $dlgFlags);
	$self->setFieldFlags('panel_test',FLDFLAG_READONLY) if $command ne 'add';	


	#Stick Down arrow on dataGrid fields	
	my $pos=-1;
	for (my $loop=1;$loop<MAXROWS;$loop++)
	{
		$pos+=6;
		my $field = $self->getField("panel")->{fields}->[$pos];
		my $nextField=$loop+1;
		$field->{postHtml}=qq{<A HREF = javascript:changePanel($nextField);>$IMAGETAGS{'icons/arrow-down-blue'}</A>};	
	};
	
	my $maxrows=MAXROWS;
       	$self->addPostHtml(
       	qq{
		<script language="JavaScript1.2">
		for(loop=1;loop<=$maxrows;loop++)
		{	
			setIdDisplay("panel_"+loop,'none');		
		};		
		function setMode(event)
		{
			var myValue = event.srcElement.value;
			if (myValue==1)
			{

				setSingle('none');
				setPanel('block');
			}
			else
			{
				setSingle('block');	
				setPanel('none');
			}

		};
		
		function setSingle(mode)
		{
			setIdDisplay('test',mode);			
			setIdDisplay('code',mode);			
			setIdDisplay('doc_price',mode);			
			setIdDisplay('pat_price',mode);								
		}				
		function setPanel(mode)
		{
			setIdDisplay('panel_id_name',mode);		
			setIdDisplay('panel_1',mode);		
       			setIdDisplay("panel",mode);								
		};		
		function changePanel(index)
		{
			var prevField=index-1;
 			mode=eval("document.all._id_panel_" + index + ".style.display");		
 			var newmode;
 			if(mode=='block')
 			{
 				//Close all grid lines below this line
 				for (loop=index; loop<=$maxrows;loop++)
 				{
					setIdDisplay("panel_"+loop,'none'); 				
				}
 			}
 			else
 			{
 				setIdDisplay("panel_"+index,'block'); 				
 			}
		}
		</script>
	});
}
sub populateData_add
{
	my ($self, $page, $command, $flags) = @_;
	$page->field('lab_type',$page->param('catalog_type'));	
	$page->field('org_id',$page->param('org_id'));	
	$page->field('internal_catalog_id',$page->param('internal_catalog_id'));
	$page->addError("Lab Catalog does not exist.") unless $page->param('internal_catalog_id');	
	my $panel = $page->field('panel_test');
	
	#Configure the dialog
	$self->configureDialog($page,$command,$panel);
}

sub populateData_update
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;
	my $id = $page->param('entry_id');	
	my $data=  $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selCatalogItemById',$id);	
	$page->field('test_group',$data->{parent_entry_id}||undef);
	if ($flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL)
	{
		$self->addPostHtml(qq{<script language="JavaScript1.2">setIdDisplay("panel_id_name",'none');setIdDisplay("panel",'none');</script>});						
		$page->field('org_id',$page->param('org_id'));	
		if($data->{data_text} eq 'Single Test')
		{
			$page->field('test_id',$data->{modifier});
		 	$page->field('test_caption',$data->{name});
		 	$page->field('code',$data->{code});		 	
			$page->field('doc_price',$data->{unit_cost});	
			$page->field('pat_price',$data->{data_num});			
			$page->field('panel_test',0);
			$page->field('entry_id',$id);
			$page->field('internal_catalog_id',$data->{catalog_id});
			$page->field('lab_type',$data->{entry_type});				
			
		}
		else
		{
			$page->field('panel_test',1);	
			$page->field('entry_id',$id);	
			$page->field('internal_catalog_id',$data->{catalog_id});	
			$page->field('panel_name',$data->{name});
			$page->field('panel_id',$data->{modifier});		
			$page->field('entry_id',$id);
			$page->field('lab_type',$data->{entry_type});				
			#Get Children record of this parent
			my $dataChild=  $STMTMGR_CATALOG->getRowsAsHashList($page,STMTMGRFLAG_NONE,'selCatalogItemsByParentItem',$id);
			my $loop=1;
			$self->addPostHtml(qq{<script language="JavaScript1.2">setSingle('none');setPanel('block'); </script>});		
			foreach (@$dataChild)
			{
				$page->field("test_id_$loop",$_->{modifier});
				$page->field("test_caption_$loop",$_->{name});	
				$page->field("doc_price_$loop",$_->{unit_cost});	
				$page->field("pat_price_$loop",$_->{unit_cost});				
				$page->field("entry_id_$loop",$_->{entry_id});
		 		$page->field("code_$loop",$_->{code});		 						
				$self->addPostHtml(qq{<script language="JavaScript1.2">changePanel($loop); </script>});							
				$loop++;	
			};
			$self->addPostHtml(qq{<script language="JavaScript1.2">setSingle('none');setPanel('block'); </script>});
			
		}	
		
		#Set Heading for Dialog
		my $catalogData = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selCatalogById',$page->field('internal_catalog_id')||undef);	
		my $com =ucfirst($command) ;
		my $type = ucfirst(lc($catalogData->{caption}));
		$self->{heading}="$com $type Test";		
	}
	else
	{
		my $panel = $data->{modifier} eq 'Single Test'?  0 : 1 ;
		$self->configureDialog($page,$command,$panel);
	};

}

sub configureDialog
{
	my ($self, $page,$command,$panel) = @_;

	#Set Test Selection to read only if this is a update or delete
	
	#Set Heading for Dialog
	my $catalogData = $STMTMGR_CATALOG->getRowAsHash($page,STMTMGRFLAG_NONE,'selCatalogById',$page->field('internal_catalog_id')||undef);	
	my $com =ucfirst($command) ;
	my $type = ucfirst(lc($catalogData->{caption}));
	$self->{heading}="$com $type Test";
	$page->field('test_type',$type);
	#Reset Dialog
	$self->addPostHtml(qq{<script language="JavaScript1.2">setIdDisplay("panel_id_name",'none');setIdDisplay("panel",'none');</script>});						
	if($panel)
	{
		for (my $loop=1;$loop<=MAXROWS;$loop++)
		{
			if($page->field("test_id_$loop"))
			{
				$self->addPostHtml(qq{<script language="JavaScript1.2">changePanel($loop); </script>});								
			}
			$self->addPostHtml(qq{<script language="JavaScript1.2">setSingle('none');setPanel('block'); </script>});					
		}
	}
	else
	{
		$self->addPostHtml(qq{<script language="JavaScript1.2">setPanel('none');</script>});
	}
}
sub populateData_remove
{
	populateData_update(@_);
	
	#Hide the caption if panel test;
}
sub customValidate
{
	my ($self, $page) = @_;
	
	
	#Based On test type some fields are not required
	if($page->field('panel_test'))
	{
		#$self->clearFieldFlags('test',FLDFLAG_REQUIRED);		
		my $field;
		$field = $self->getField("panel_id_name");
		unless($page->field('panel_id') && $page->field('panel_name') )
		{
			$field->invalidate($page, qq{For Panel test panel name and ID are required.});
		}
	}
	else		
	{
		my $field;
		$field = $self->getField("test");
		unless($page->field('test_id') && $page->field('test_caption') )
		{
			$field->invalidate($page, qq{Test Name and ID are required.});
		}
	
		#$self->clearFieldFlags('panel_id_name',FLDFLAG_REQUIRED);
		#$self->clearFieldFlags('panel_name',FLDFLAG_REQUIRED);		
		#$self->clearFieldFlags('panel_id',FLDFLAG_REQUIRED);		
	}	
	
	
}


sub saveSingleTest
{
	my ($self, $page, $command, $flags) = @_;
	my $lab_id = $page->field('test_id');
	my $caption = $page->field('test_caption');
	my $doc_price =$page->field('doc_price');
	my $pat_price =$page->field('pat_price');	
	my $entry_type = $page->field('lab_type');
	my $parent_id = $page->field('test_group');
	my $code = $page->field("code");		
	$page->schemaAction(
		'Offering_Catalog_Entry',$command,
		entry_id=>$page->field('entry_id')||undef,
		#modifier=>'Single Test',
		modifier=>$lab_id,		
		#name=>$lab_id,
		name=>$caption,		
		#description=>$,
		data_text =>'Single Test',
		code=>$code,
		unit_cost =>$doc_price,
		data_num =>$pat_price,		
		entry_type =>App::Universal::CATALOGENTRYTYPE_SERVICE,
		catalog_id=>$page->field('internal_catalog_id'),	
		parent_entry_id=>$parent_id,
	);
};

sub savePanelTest
{
	my ($self, $page, $command, $flags) = @_;
	my $panelName = $page->field('panel_name');	
	my $panelId = $page->field('panel_id');		
	my $entry_type = $page->field('lab_type');
	my $code = $page->field("code");	
	my $doc_total=0;
	my $pat_total=0;
	my $parentGroup = $page->field('test_group');
	#Save Group Info
	my $parentId=$page->schemaAction(
		'Offering_Catalog_Entry',$command,
		entry_id=>$page->field('entry_id')||undef,
		#modifier=>'Panel Test',	
		data_text =>'Panel Test',
		modifier=>$panelId,	
		#name=>$panelId,
		name=>$panelName,		
		#description=>$panelName,
		code=>$code,
		entry_type =>App::Universal::CATALOGENTRYTYPE_SERVICE,
		catalog_id=>$page->field('internal_catalog_id'),
		parent_entry_id =>$parentGroup,
	);
	
	#Save Test Panel
	$parentId = $page->field('entry_id') || $parentId;
	my $loop;
	my $list;
	for ($loop=1;$loop<=MAXROWS;$loop++)
	{


		my $test_id = $page->field("test_id_$loop");
		my $cap = $page->field("test_caption_$loop");		
		my $price = $page->field("doc_price_$loop");			
		my $price2 = $page->field("pat_price_$loop");					
		my $entry_id = $page->field("entry_id_$loop");
		my $code = $page->field("code_$loop");
		next unless ($test_id || $page->field("entry_id_$loop"));
		$list .= $list ? ", $cap " : $cap;
		#Even if the dialog is an update the user can add new test  to a panel so determine
		#if current test  has an entry_id
		$command =  $page->field("entry_id_$loop") ?  'update' : 'add' if $command eq 'update';		
		if($test_id)
		{

			$page->schemaAction(
			'Offering_Catalog_Entry',$command,
			#modifier=>'Panel Test Item',	
			data_text =>'Panel Test Item',
			modifier=>$test_id,	
			entry_id=>$page->field("entry_id_$loop") ||undef,
			unit_cost=>$price,	
			data_num=>$price2,
			#name=>$test_id,
			name=>$cap,
			#description=>$cap,
			code=>$code,
			parent_entry_id =>$parentId,
			entry_type =>App::Universal::CATALOGENTRYTYPE_SERVICE,
			catalog_id=>$page->field('internal_catalog_id')		
			);
			$doc_total+=$price;
			$pat_total+=$price2;
		}
		elsif($page->field("entry_id_$loop"))
		{
			$page->schemaAction(
			'Offering_Catalog_Entry','remove',
			entry_id=>$page->field("entry_id_$loop"),
			);
		
		}		
	}
	#update panel price
	$page->schemaAction(
		'Offering_Catalog_Entry','update',
		entry_id=>$parentId,
		unit_cost=>$doc_total,
		data_num=>$pat_total,
		description=>$list
	);	
	
};

sub execute
{
	my ($self, $page, $command, $flags) = @_;


	#Check if this is panel of test of single test
	my $panel = $page->field('panel_test');
	if($panel)
	{	
		$self->savePanelTest($page,$command,$flags);				
	}	
	else
	{
		$self->saveSingleTest($page,$command,$flags);
	}	
	$page->param('_dialogreturnurl', '/org/%param.org_id%/catalog?catalog=labtest_detail&labtest_detail=%field.internal_catalog_id%') if $command ne 'add';
	$self->handlePostExecute($page, $command, $flags, undef);			
	return ;
}

1;

