##############################################################################
package XAP::Component::Controller;
##############################################################################

use strict;
use DBI;
use Security::AccessControl;
use Date::Manip;
use Schema::API;
use Apache::Session::Flex;

use XAP::Component;
use base qw(XAP::Component);
use fields qw(
	options
	file_AccessControlDefn
	fmt_UnixDate
	fmt_UnixStamp
	fmt_SQLDate
	fmt_SQLStamp

	dataSources
	defaultDataSource
	defaultDbHdl

	file_SchemaDefn
	schema
	schemaFlags
	sqlUnitWork
	valUnitWork
	sqlMsg
	sqlDump
	errUnitWork
	cntUnitWork
	sqlLog

	acl

	sessMgrClassName
	sessMgrClassParams
	sessIdCookieName

	arbitraryConfigData
	);

use vars qw(%FIELDS %SPECIAL_ASSIGNMENTS);
use constant TAG_CONFIG_ITEM		=> 'config-item';
use constant TAG_CONFIG_ITEM_SELECT	=> 'config-item-select';
use constant TAG_CONFIG_ITEM_OPTION	=> 'config-item-option';
use constant TAG_CONFIG_DATA_SRC	=> 'data-source';
use constant TAG_CONFIG_SCHEMA_DEFN	=> 'schema-defn';

use enum qw(BITMASK:CONFIGOPTION_ APPLYPREFILTER APPLYPOSTFILTER);
use constant CONFIGOPTIONS_DEFAULT => CONFIGOPTION_APPLYPREFILTER | CONFIGOPTION_APPLYPOSTFILTER;

XAP::Component->registerXMLTagClass('controller', __PACKAGE__);

use enum qw(:DATASRCINFO_ CONNECTKEY USERNAME PASSWORD PARAMS);

sub init
{
	my XAP::Component::Controller $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{options} = exists $params{options} ? $params{options} : CONFIGOPTIONS_DEFAULT;
	$self->{file_AccessControlDefn} = exists $params{file_AccessControlDefn} ? $params{file_AccessControlDefn} : undef;
	$self->{fmt_UnixDate} = exists $params{fmt_UnixDate} ? $params{fmt_UnixDate} : '%m/%d/%Y';
	$self->{fmt_UnixStamp} = exists $params{fmt_UnixStamp} ? $params{fmt_UnixStamp} : '%m/%d/%Y %I:%M %p';
	$self->{fmt_SQLDate} = exists $params{fmt_SQLDate} ? $params{fmt_SQLDate} : 'MM/DD/YYYY';
	$self->{fmt_SQLStamp} = exists $params{fmt_SQLStamp} ? $params{fmt_SQLStamp} : 'MM/DD/YYYY HH12:MI AM';
	$self->{arbitraryConfigData} = exists $params{arbitraryConfigData} ? $params{arbitraryConfigData} : {};

	$self->{dataSources} = exists $params{dataSources} ? $params{dataSources} : undef;
	$self->{defaultDataSource} = exists $params{defaultDataSource} ? $params{defaultDataSource} : undef;
	$self->{defaultDbHdl} = exists $params{defaultDbHdl} ? $params{defaultDbHdl} : undef;
	$self->{file_SchemaDefn} = exists $params{file_SchemaDefn} ? $params{file_SchemaDefn} : undef;
	$self->{schema} = exists $params{schema} ? $params{schema} : undef;
	$self->{schemaFlags} = exists $params{schemaFlags} ? $params{schemaFlags} : 0;
	$self->{sqlUnitWork} = undef;
	$self->{valUnitWork} = undef;
	$self->{sqlMsg} = undef;
	$self->{sqlDump} = undef;
	$self->{errUnitWork} = [];
	$self->{cntUnitWork} = 0;
	$self->{sqlLog} = [];

	$self->{sessIdCookieName} = exists $params{sessIdCookieName} ? $params{sessIdCookieName} : 'XAP_SESSID_0102';

	$self->clearFlag(COMPFLAG_URLADDRESSABLE);
	$self;
}

sub DESTROY
{
	my XAP::Component::Controller $self = shift;
	
	if(my $dataSources = $self->{dataSources})
	{
		foreach (@{$dataSources})
		{
			#$_->[DATASRCINFO_DBIHANDLE]->disconnect() if $_->[DATASRCINFO_DBIHANDLE];
		}
	}
}

sub addDataSource
{
	my XAP::Component::Controller $self = shift;
	my $dataSourceId = shift;
	
	my $firstDataSource = 0;
	unless($self->{dataSources})
	{
		$self->{dataSources} = {};
		$firstDataSource = 1;
	}
	
	my ($dsInfo, $isDefault) = ([], undef);
	if(scalar(@_) == 1)
	{
		my $dsInfoStr = shift;
		my ($connectInfo, $isDefault) = split(/,/, $dsInfoStr); 
		my ($nameInfo, $connectKey) = split(/@/, $connectInfo); 
		my ($userName, $passWord) = split(/\//, $nameInfo); 
		push(@$dsInfo, $connectKey, $userName, $passWord);
	}
	else
	{
		$isDefault = shift;
		push(@$dsInfo, @_);
	}
	$isDefault = 1 if ($dataSourceId eq 'default') || (! defined $isDefault && $firstDataSource);
	push(@$dsInfo, { RaiseError => 1 });
		
	$self->{dataSources}->{$dataSourceId} = $dsInfo;
	$self->{defaultDataSource} = $dsInfo if $isDefault =~ m/^(1|default|yes)$/i;
}

sub applyXML
{
	my XAP::Component::Controller $self = shift;
	my ($tag, $content) = @_;
	my $attrs = $content->[0];

	$self->SUPER::applyXML(@_);
	my $arbitraryConfigData = ($self->{arbitraryConfigData} =
	{
		# put all default config information in here
	});

	if(my $inherit = $attrs->{inherit})
	{
		if(my XAP::Component::Controller $inhConfig = $self->getComponent('.../' . $inherit))
		{
			foreach (qw(
				file_SchemaDefn file_AccessControlDefn fmt_UnixDate fmt_UnixStamp fmt_SQLDate fmt_SQLStamp
				schema schemaFlags dataSources defaultDataSource defaultDbHdl
				))
			{
				my $fieldNum = $FIELDS{$_};
				$self->[$fieldNum] = $inhConfig->[$fieldNum];
			}
			my $inharbitraryConfigData = $inhConfig->{arbitraryConfigData};
			foreach (keys %$inharbitraryConfigData)
			{
				$arbitraryConfigData->{$_} = $inharbitraryConfigData->{$_};
			}
		}
	}

	my $varHashRef =
	{
		'config' => $arbitraryConfigData,
		'env' => \%ENV,
	};
	
	my $replaceVars = sub
	{
		my $value = shift;
		$value =~ s/\$(\w+)\.([\w\-]+)\$/$varHashRef->{$1}->{$2} || 0/ge;
		return $value;
	};

	my $assignValue = sub
	{
		my ($name, $value, $type) = @_;
		$value =~ s/\$(\w+)\.([\w\-]+)\$/$varHashRef->{$1}->{$2} || 0/ge;
		$arbitraryConfigData->{$name} = $value;
		#
		# TO-DO: add $type checks for path-require, path-autocreate, file-require, etc.
		#
		my $fieldNum = exists $SPECIAL_ASSIGNMENTS{$name} ? $SPECIAL_ASSIGNMENTS{$name} : (exists $FIELDS{$name} ? $FIELDS{$name} : undef);
		$self->[$fieldNum] = $value if defined $fieldNum;

		return $value ? 1 : 0;
	};

	my $childCount = scalar(@$content);
	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);
		next unless $chTag; # if $tag is 0, it's just characters

		my $chAttrs = $chContent->[0];
		if($chTag eq TAG_CONFIG_ITEM)
		{
			&$assignValue($chAttrs->{name}, $chAttrs->{value}, $chAttrs->{type});
		}
		elsif($chTag eq TAG_CONFIG_ITEM_SELECT)
		{
			my ($name, $type) = ($chAttrs->{name}, $chAttrs->{type});

			# the grandchildren ("g"Children) are the options -- we'll pick the first one that's non-zero
			my $gChildCount = scalar(@$chContent);
			for(my $gChild = 1; $gChild < $gChildCount; $gChild += 2)
			{
				my ($gChTag, $gChContent) = ($chContent->[$gChild], $chContent->[$gChild+1]);
				next unless $gChTag; # if $tag is 0, it's just characters
				last if &$assignValue($name, $gChContent->[0]->{value}, $type);
			}
		}
		elsif($chTag eq TAG_CONFIG_DATA_SRC)
		{
			my $dsId = $chAttrs->{id} || 'default';
			if(my $connectStr = &$replaceVars($chAttrs->{'connect-str'}))
			{
				$self->addDataSource($dsId, $connectStr);
			}
			else
			{
				$self->addDataSource(
						$dsId, $chAttrs->{default} || undef,
						&$replaceVars($chAttrs->{'connect-key'}), 
						&$replaceVars($chAttrs->{'user-name'}), 
						&$replaceVars($chAttrs->{'password'}));
			}
		}
		elsif($chTag eq TAG_CONFIG_SCHEMA_DEFN)
		{
			$self->{file_SchemaDefn} = &$replaceVars($chAttrs->{src});
			$self->{schema} = undef;
			$self->{schemaFlags} = 0;
		}
	}
	
	foreach my $varName (sort keys %ENV)
	{
		if($varName =~ m/^XAP_DATASOURCE_(.*)/)
		{
			$self->addDataSource(lc($1), &$replaceVars($ENV{$varName}));
		}
	}

	#print "CONFIG: '$self->{id}'\n";
	#foreach (sort keys %{$self->{arbitraryConfigData}})
	#{
	#	print "$_ = '$self->{arbitraryConfigData}->{$_}'\n";
	#}

	$self;
}

sub getSessionType
{
	my XAP::Component::Controller $self = shift;
	return $self->{sessType};
}

#-----------------------------------------------------------------------------
# DATE/TIME MANAGEMENT ROUTINES
#-----------------------------------------------------------------------------

sub getDate
{
	my XAP::Component::Controller $self = shift;
	my $parse = shift || 'today';

	return UnixDate($parse, $self->{fmt_UnixDate});
}

sub getTimeStamp
{
	my XAP::Component::Controller $self = shift;
	my $parse = shift || 'now';

	return UnixDate($parse, $self->{fmt_UnixStamp});
}

sub defaultUnixDateFormat
{
	my XAP::Component::Controller $self = shift;
	return $self->{fmt_UnixDate};
}

sub defaultUnixStampFormat
{
	my XAP::Component::Controller $self = shift;
	return $self->{fmt_UnixStamp};
}

#-----------------------------------------------------------------------------
# DATABASE MANAGEMENT ROUTINES
#-----------------------------------------------------------------------------

sub getDbh
{
	my XAP::Component::Controller $self = shift;
	my $dsId = shift;
	my $dsInfo = $dsId ? $self->{dataSources}->{$dsId} : $self->{defaultDataSource};

	die "dataSource '@{[ $dsId || 'default' ]}' not found" unless $dsInfo;
	if(my $dbh = DBI->connect_cached(@$dsInfo))
	{
		return $dbh;
	}
	else
	{
		die "couldn't connect to dataSource '@{[ $dsId || 'default' ]}' (@{[ join(', ', @$dsInfo) ]})";
	}
}

sub loadSchema
{
	my XAP::Component::Controller $self = shift;
	
	$self->{schema} = new Schema::API(xmlFile => $self->{file_SchemaDefn});
	$self->{schema}->{dbh} = $self->getDbh();
}

sub schemaAction
{
	my $self = shift;
	$self->loadSchema() unless $self->{schema};
	return $self->{schema}->schemaAction($self, @_);
}

sub executeSql
{
	my XAP::Component::Controller $self = shift;
	$self->getDbh() unless $self->{defaultDbHdl};

	my $stmhdl = shift;
	my $rc;
	eval
	{
		$rc = $stmhdl->execute(@{$self->{valUnitWork}});
	};
	if($@||!$rc)
	{
		$self->addError($self->{sqlMsg}) if $self->{sqlMsg} ;
		$self->addError(join ("<br>",$@, $self->{defaultDbHdl}->errstr));
		$self->addError($self->{sqlDump});
		$@ = undef;
		return 0;
	}
	return $rc;
}

sub beginUnitWork
{
	my XAP::Component::Controller $self = shift;
	my $msg = shift;
	$self->{sqlMsg} = $msg  ? $msg : undef;
	$self->{sqlUnitWork}='BEGIN ';
	$self->{cntUnitWork}=0;
	$self->{errUnitWork}=[];
	$self->{valUnitWork}=undef;
	$self->{sqlDump}=undef;
	$self->{schemaFlags}|= SCHEMAAPIFLAG_UNITSQL;
	$self->{schemaFlags}&=~SCHEMAAPIFLAG_EXECSQL;
	return 1;
}

sub endUnitWork
{
	my XAP::Component::Controller $self = shift;
	$self->{sqlUnitWork}.= "END;  ";
	my $stmhdl = $self->prepareSql($self->{sqlUnitWork});
	$self->{schemaFlags}&= ~SCHEMAAPIFLAG_UNITSQL;
	$self->{sqlUnitWork}=undef;
	if (scalar(@{$self->{errUnitWork}}))
	{
		$self->addError($self->{sqlMsg}) if $self->{sqlMsg} ;
		$self->addError(join ("<br>",@{$self->{errUnitWork}}));
		return 0;
	}
	return $self->executeSql($stmhdl);
}

sub unitWork
{
	my XAP::Component::Controller $self = shift;
	return $self->{schemaFlags} & SCHEMAAPIFLAG_UNITSQL;
}

sub storeSql
{
	my XAP::Component::Controller $self = shift;
	my ($sql, $vals, $errors) = @_;
	my $out_vals = join ",",@{$vals};
	$self->{cntUnitWork}++;
	if(scalar(@{$errors}) > 0)
	{

		push(@{$self->{errUnitWork}},"<b> Unit Of Work Query $self->{cntUnitWork} error :</b> @{$errors} <br> $sql $out_vals");
	}
	$self->{sqlUnitWork}.= $sql . ";\n";
	$self->{sqlDump}.= "<b> Line $self->{cntUnitWork} </b>" . $sql .  "<BR> <font color=red>$out_vals</font> <BR>" ;
	push(@{$self->{valUnitWork}},@{$vals});
}

sub getSqlLog
{
	my XAP::Component::Controller $self = shift;
	return $self->{sqlLog};
}

sub clearSqlLog
{
	my XAP::Component::Controller $self = shift;
	$self->{sqlLog} = [];
	return $self->{sqlLog};
}

#-----------------------------------------------------------------------------
# SESSION MANAGEMENT ROUTINES
#-----------------------------------------------------------------------------

sub establishSession
{
	my XAP::Component::Controller $self = shift;
	my ($page, $flags) = @_;

	my %session;
	my $activeSessionId = $page->cookie($self->{sessIdCookieName});	
	tie %session, 'Apache::Session::Flex', $activeSessionId ? $activeSessionId : undef, 
	{
	   Store     => 'File',
	   Lock      => 'Null',
	   Generate  => 'MD5',
	   Serialize => 'Storable',
	};

	$page->{page_session} = \%session;
	$page->setDebugFlags($session{debugFlags}) if $session{debugFlags};
	if($activeSessionId)
	{
		$session{accessCount}++;
	}
	else
	{
		$session{accessCount} = 0;
		$page->addCookie(-name => $self->{sessIdCookieName}, -value => $session{_session_id});
	}
	
	return $page->sessionStatus(XAP::CGI::Page::SESSIONSTATUS_ACTIVE());
}

#-----------------------------------------------------------------------------
# ACL/PERMISSION MANAGEMENT ROUTINES
#-----------------------------------------------------------------------------

sub getACL
{
	my XAP::Component::Controller $self = shift;
	return $self->{acl} ? $self->{acl} : ($self->{acl} = new Security::AccessControl(xmlFile => $self->{file_AccessControlDefn}));
}

#-----------------------------------------------------------------------------
# PAGE PROCESSING ROUTINES
#-----------------------------------------------------------------------------

# applyFilters - does replacements for #pageMethod.argument# style templates
#
# This includes #session.xxx#, #URL.xxx# #property.xxx# #field.xxx# and
# any other page method that returns a single value and takes 0 or 1 parameter
#
# It can be called with a reference to a scalar string or a scalar string.  It will return
# the string in the same type it was called with.  It is preferred to call using
# scalar references for performance and memory

sub applyFilters
{
	my XAP::Component::Controller $self = shift;
	my ($src, $page, $flags) = @_;

	my $data = ref($src) ? $src : \$src;
	my $count = 1;
	my $configData = $self->{arbitraryConfigData};
	my $mainComp = $page ? $page->{mainComponent} : undef;

	while($count)
	{
		if($page)
		{
			$count = ($$data =~ s/\#(\w+)\.?([\w\-\.]*)\#/
				if(my $method = $page->can($1))
				{
					&$method($page, $2);
				}
				elsif($1 eq 'config')
				{
					exists $configData->{$2} ? $configData->{$2} :
						(exists $FIELDS{$2} ? $self->[$FIELDS{$2}] :
						 (($method = $self->can($2)) ? &$method($self, $2) : "config.$2 not found in $self"));
				}
				elsif($method = $mainComp->can($2))
				{
					&$method($mainComp, $2);
				}
				else
				{
					$1 . $2;
				}
				/ge);
		}
		else
		{
			my $method;
			$count = ($$data =~ s/\#(\w+)\.?([\w\-\.]*)\#/
				if($1 eq 'config')
				{
					exists $configData->{$2} ? $configData->{$2} :
						(exists $FIELDS{$2} ? $self->[$FIELDS{$2}] :
						 (($method = $self->can($2)) ? &$method($self, $2) : "config.$2 not found in $self"));
				}
				else
				{
					$1 . $2;
				}
				/ge);
		}
	}

	return ref($src) ? $data : $$data;
}

1;