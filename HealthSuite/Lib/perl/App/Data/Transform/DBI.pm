##############################################################################
package App::Data::Transform::DBI;
##############################################################################

use strict;
use Carp;
use App::Data::Manipulate;
use App::Data::Transform;

use vars qw(@ISA);
@ISA = qw(App::Data::Transform);

sub getInsertStatement
{
	my ($self, $flags, $collection, $params, $dbh) = @_;
	$self->abstract();
}

sub execSql
{
	my ($self, $actions, $flags, $collection, $params, $dbh) = @_;
	#
	# actions is either an array of strings or a single string
	# actions can end with "// blah blah blah" to show a message prior to execution
	#
	if(ref $actions eq 'ARRAY')
	{
		foreach(@$actions)
		{
			if(s!//\s*(.*)$!!)
			{
				$self->reportMsg($1) if $1 && ($flags & DATAMANIPFLAG_SHOWPROGRESS);
			}
			$self->reportMsg("execSql: $_") if $flags & DATAMANIPFLAG_VERBOSE;
			$dbh->do($_);
		}
	}
	else
	{
		$actions =~ s!//\s*(.*)$!!;
		$self->reportMsg($1) if $1 && ($flags & DATAMANIPFLAG_SHOWPROGRESS);
		$self->reportMsg("execSql: $actions") if $flags & DATAMANIPFLAG_VERBOSE;
		$dbh->do($actions);
	}
}

sub beforeInsert
{
	my ($self, $flags, $collection, $params, $dbh) = @_;
	$self->showCount($flags, $collection, $params, $dbh);
	if(my $actions = $params->{doBefore})
	{
		$self->reportMsg("Executing beforeInsert actions.") if $flags & DATAMANIPFLAG_VERBOSE;
		$self->execSql($actions, $flags, $collection, $params, $dbh);
	}
}

sub showCount
{
	my ($self, $flags, $collection, $params, $dbh) = @_;
	if(my $verifyStmt = $params->{verifyCountStmt})
	{
		my $vsth = $dbh->prepare($verifyStmt);
		if(my $bind = $params->{verifyCountBind})
		{
			if(ref $bind eq 'ARRAY')
			{
				$vsth->execute(@$bind);
			}
			else
			{
				$vsth->execute($bind);
			}
		}
		else
		{
			$vsth->execute();
		}
		my $result = $vsth->fetch()->[0];
		$self->reportMsg("There are $result rows in the database.");
	}
}

sub insert
{
	my ($self, $flags, $collection, $params, $dbh) = @_;
	my $statement = $params->{insertStmt} || $self->getInsertStatement($flags, $collection, $params, $dbh);
	my $updateCount = $params->{progressUpdateCnt} || 25;
	unless($statement)
	{
		$self->addError("No insert statement found");
		return;
	}

	$self->reportMsg("Performing inserts.") if $flags & DATAMANIPFLAG_VERBOSE;
	my $data = $collection->getDataRows();
	eval
	{
		$self->reportMsg("prepare: $statement.") if $flags & DATAMANIPFLAG_VERBOSE;
		my $sth = $dbh->prepare($statement);
		my $rowCount = 0;
		my $totalRows = scalar(@$data);
		$self->reportMsg("do inserts: $statement.") if $flags & DATAMANIPFLAG_VERBOSE;
		foreach(@$data)
		{
			$rowCount++;
			$self->updateMsg("inserted $rowCount of $totalRows")
				if ($rowCount % $updateCount == 0) && ($flags & DATAMANIPFLAG_SHOWPROGRESS);

			next unless $_;
			eval
			{
				$sth->execute(@$_);
			};
			$self->addError('DBI Error processing data "' . join(', ', @$_) . "\"\n" . $@) if $@;
		}
		$self->reportMsg("Inserted $totalRows rows into the database.") if $flags & DATAMANIPFLAG_SHOWPROGRESS;
	};
	$self->addError($@) if $@;
	$self->showCount($flags, $collection, $params, $dbh);
}

sub afterInsert
{
	my ($self, $flags, $collection, $params, $dbh) = @_;
	if(my $actions = $params->{doAfter})
	{
		$self->reportMsg("Executing afterInsert actions.") if $flags & DATAMANIPFLAG_VERBOSE;
		$self->execSql($actions, $flags, $collection, $params, $dbh);
	}
}

sub process
{
	my ($self, $flags, $collection, $params) = @_;
	$flags = $self->setupFlags($flags);

	if(my $connect = $params->{connect})
	{
		my ($un, $pw, $connectStr) = $connect =~ m/\s*(.*?)\/(.*?)\@(.*)\s*/;
		if($un && $pw && $connectStr)
		{
			$self->reportMsg("Connecting to $connectStr as $un.") if $flags & DATAMANIPFLAG_VERBOSE;
			if(my $dbh = DBI->connect($connectStr, $un, $pw))
			{
				$dbh->{RaiseError} = 1;
				eval
				{
					$self->beforeInsert($flags, $collection, $params, $dbh);
					$self->insert($flags, $collection, $params, $dbh);
					$self->afterInsert($flags, $collection, $params, $dbh);
				};
				$dbh->disconnect();
				undef $dbh;
				$self->reportMsg("Disconnecting from $connectStr as $un.") if $flags & DATAMANIPFLAG_VERBOSE;
				$self->addError($@) if $@;
			}
			else
			{
				$self->addError("unable to connect to $connectStr as $un (pw $pw)");
			}
		}
		else
		{
			$self->addError("invalid connection string: expected -connect username/password\@dbserver");
		}
	}
	elsif(my $dbh = $params->{dbh})
	{
		$self->beforeInsert($flags, $collection, $params, $dbh);
		$self->insert($flags, $collection, $params, $dbh);
		$self->afterInsert($flags, $collection, $params, $dbh);
	}
	else
	{
		$self->addError("either connect or dbh parameters are required");
	}
}

1;