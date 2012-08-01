##############################################################################
package XAP::Component::Command::Query;
##############################################################################

use strict;
use Exporter;
use Date::Manip;
use XAP::Component;
use XAP::Component::Command;
use Data::Publish;
use Storable;

use base qw(XAP::Component::Command Exporter);
use fields qw(action sql params dataSource storeOutput publishDefn);

XAP::Component->registerXMLTagClass('query', __PACKAGE__);
XAP::Component->registerXMLTagClass('cmd-query', __PACKAGE__);
XAP::Component->registerXMLTagClass('data-panel', __PACKAGE__);

use constant QUERYACTIONTYPE_PUBLISH         => 0;
use constant QUERYACTIONTYPE_POPULATEFIELDS  => 1;
use constant QUERYACTIONTYPE_RECORDEXISTS    => 2;
use constant QUERYACTIONTYPE_RECORDNOTEXISTS => 3;

use constant COMPQUERYFLAG_DYNAMICSQL => XAP::Component::Command::COMPCMDFLAG_FIRSTAVAIL;
use constant COMPQUERYFLAG_DATAPANEL  => COMPQUERYFLAG_DYNAMICSQL * 2;

use vars qw(%TAG_ACTION_MAP @EXPORT);
@EXPORT = qw(
	QUERYACTIONTYPE_PUBLISH
	QUERYACTIONTYPE_POPULATEFIELDS
	QUERYACTIONTYPE_RECORDEXISTS
	QUERYACTIONTYPE_RECORDNOTEXISTS
);

%TAG_ACTION_MAP = (
	'publish' => QUERYACTIONTYPE_PUBLISH,
	'populate-fields' => QUERYACTIONTYPE_POPULATEFIELDS,
	'record-exists' => QUERYACTIONTYPE_RECORDEXISTS,
	'record-not-exists' => QUERYACTIONTYPE_RECORDNOTEXISTS,
);

sub init
{
	my XAP::Component::Command::Query $self = shift;
	my %params = @_;

	$self->SUPER::init(@_);
	$self->{action} = exists $params{action} ? $params{action} : QUERYACTIONTYPE_PUBLISH;
	$self->{sql} = exists $params{sql} ? $params{sql} : undef;
	$self->{dataSource} = exists $params{dataSource} ? $params{dataSource} : undef;
	$self->{params} = exists $params{params} ? $params{params} : undef;
	$self->{storeOutput} = exists $params{storeOutput} ? $params{storeOutput} : undef;
	$self->{publishDefn} = exists $params{publishDefn} ? $params{publishDefn} : undef;
	
	$self;
}

sub applyXML
{
	my XAP::Component::Command::Query $self = shift;
	my ($tag, $content) = @_;

	$self->SUPER::applyXML(@_);

	my $sql = '';
	my ($childCount, $attrs) = (scalar(@$content), $content->[0]);
	$self->{dataSource} = $attrs->{'data-source'} if exists $attrs->{'data-source'};
	$self->{flags} |= COMPQUERYFLAG_DATAPANEL if $tag eq 'data-panel';
	$self->{flags} |= COMPQUERYFLAG_DYNAMICSQL if exists $attrs->{'type'} && $attrs->{'type'} eq 'dynamic';
	
	if(my $action = $attrs->{action})
	{
		$self->{action} = exists $TAG_ACTION_MAP{$action} ? $TAG_ACTION_MAP{$action} : QUERYACTIONTYPE_PUBLISH;
	}
	
	for(my $child = 1; $child < $childCount; $child += 2)
	{
		my ($chTag, $chContent) = ($content->[$child], $content->[$child+1]);

		# all text inside the <query> tag should be considered SQL
		unless($chTag)
		{
			$sql .= $chContent;
			next;
		}

		my $chAttrs = $chContent->[0];
		if($chTag eq 'publish')
		{
			$self->{publishDefn} = $self->getPublishDefnFromXML($chTag, $chContent);
		}
		elsif($chTag eq 'param-field')
		{
			$self->addParam('field', $chAttrs->{name});
		}
		elsif($chTag eq 'param-url')
		{
			$self->addParam('param', $chAttrs->{name});
		}
		elsif($chTag eq 'param-session')
		{
			$self->addParam('session', $chAttrs->{name});
		}
		elsif($chTag eq 'store-output')
		{
			$self->{storeOutput} = $chAttrs->{property} || 'query';
		}
	}
	
	my $controller = $self->getComponent('.../controller');
	$self->{sql} = $controller ? $controller->applyFilters($sql) : $sql;
	$self;

}

sub addParam
{
	my XAP::Component::Command::Query $self = shift;
	my ($source, $name) = @_;

	$self->{params} = [] unless $self->{params};
	push(@{$self->{params}}, [$source, $name]);
}

sub executeQuery
{
	my XAP::Component::Command::Query $self = shift;
	my ($page, $flags) = @_;

	my $sql = $self->{sql};
	if($self->{flags} & COMPQUERYFLAG_DYNAMICSQL)
	{
		my $controller = $self->getComponent('.../controller');
		$controller->applyFilters(\$sql, $page, 0);
	}
	
	my $debugOn = $page->debugShowSQL();
	my $debugInfo = $debugOn ? $sql : '';

	my $dbh = $page->getDbh($self->{dataSource});
	{
		# turn off RaiseError for this block only;
		local $dbh->{RaiseError};
		if(my $stmtHdl = $dbh->prepare($sql))
		{		
			if($self->{params})
			{
				my @paramValues = ();
				foreach (@{$self->{params}})
				{			
					my $method = $page->can($_->[0]);
					push(@paramValues, $method ? &$method($page, $_->[1]) : undef);
					$debugInfo .= "<br>bind param: <b>$paramValues[-1]</b>" if $debugOn;
				}
				$stmtHdl->execute(@paramValues);
			}
			else
			{
				$stmtHdl->execute();
			}

			$page->addDebugStmt($sql) if $debugOn;
			return $stmtHdl unless $dbh->errstr();
		}
		$page->addError($dbh->errstr() . '<br><pre>' . $sql .'</pre>') if $dbh->errstr();
	}
	return undef;
}

sub populateFields
{
	my XAP::Component::Command::Query $self = shift;
	my ($page, $flags) = @_;

	if(my $stmtHdl = $self->executeQuery($page, $flags))
	{
		if(my $row = $stmtHdl->fetch())
		{
			my $namesRef = $stmtHdl->{NAME_lc};
			my $colsCount = scalar(@{$namesRef});
			foreach (my $i = 0; $i < $colsCount; $i++)
			{
				$page->param('_f_' . $namesRef->[$i], $row->[$i]);
			}
			if(my $propertyName = $self->{storeOutput})
			{
				my @storeData = @$row;
				$page->property($propertyName, \@storeData);
			}

			if($row = $stmtHdl->fetch())
			{
				$page->addError("Expected only one row, got more than one for statement <code>$self->{sql}</code>");
			}
		}
		$stmtHdl->finish();
	}
}

sub recordExists
{
	my XAP::Component::Command::Query $self = shift;
	my ($page, $flags) = @_;

	my $recExists = 0;
	if(my $stmtHdl = $self->executeQuery($page, $flags))
	{
		if(my $row = $stmtHdl->fetch())
		{
			$recExists = 1;
			if(my $propertyName = $self->{storeOutput})
			{
				my @storeData = @$row;
				$page->property($propertyName, \@storeData);
			}
		}
		$stmtHdl->finish();
	}
	return $recExists;
}

sub execute
{
	my XAP::Component::Command::Query $self = shift;
	my $action = $self->{action};
	
	if($action == QUERYACTIONTYPE_PUBLISH)
	{
		return $self->getBodyHtml(@_);
	}
	elsif($action == QUERYACTIONTYPE_POPULATEFIELDS)
	{
		return $self->populateFields(@_);
	}
	elsif($action == QUERYACTIONTYPE_RECORDEXISTS)
	{
		return $self->recordExists(@_);
	}
	elsif($action == QUERYACTIONTYPE_RECORDNOTEXISTS)
	{
		return ! $self->recordExists(@_);
	}

	die "unknown query action type: $self->{action}";
}

sub getBodyHtml
{
	my XAP::Component::Command::Query $self = shift;
	my ($page, $flags) = @_;

	if(my $stmtHdl = $self->executeQuery($page, $flags))
	{
		my $publishDefn = $self->{publishDefn} ? Storable::dclone($self->{publishDefn}) : {};
		$publishDefn->{style} = $page->param('_mode') || ($self->{flags} & COMPQUERYFLAG_DATAPANEL ? 'panel' : 'report') unless exists $publishDefn->{style};
		
		unless(exists $publishDefn->{columnDefn} && scalar(@{$publishDefn->{columnDefn}}) > 0)
		{
			prepareStatementColumns($page, $flags, $stmtHdl, $publishDefn);
		}
		return createHtmlFromStatement($page, 0, $stmtHdl, $publishDefn);
	}
}

1;