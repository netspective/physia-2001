################################################################
package App::Billing::Input::SuperBillDBI;
################################################################

use strict;
use Carp;
use DBI;

use App::Universal;
use App::Billing::SuperBill::SuperBill;
use App::Billing::SuperBill::SuperBillComponent;

sub new
{
	my ($type, %params) = @_;

	$params{UID} = undef;
	$params{PWD} = undef;
	$params{connectStr} = undef;
	$params{dbiCon} = undef;

	return bless \%params, $type;
}

sub connectDb
{
	my ($self, %params) = @_;

	$self->{UID} = $params{UID};
	$self->{PWD} = $params{PWD};
	$self->{conectStr} = $params{connectStr};

	my $user = $self->{UID};
	my $dsn = $self->{conectStr};
	my $password = $self->{PWD};

	# For Oracle 8
	$self->{dbiCon} = DBI->connect($dsn, $user, $password, { RaiseError => 1, AutoCommit => 0 }) || die "Unable To Connect to Database... $dsn ";

}

sub populateSuperBill
{
	my ($self, $superBill, $superBillID, $orgInternalID, %params) = @_;

	$self->makeStatements;

	my $handle = $params{dbiHdl};

	if($handle)
	{
		$self->{dbiCon} = $handle;
	}
	else
	{
		$self->connectDb(%params);
	}

	$self->populateSuperBillAndPatient($superBill, $superBillID, $orgInternalID);

	unless($handle)
	{
		$self->dbDisconnect;
	}

	return 1;
}

sub populateSuperBillAndPatient
{

	my ($self, $superBill, $superBillID, $orgInternalID) = @_;

	my $sth;
	my @row;

	$sth = $self->prepareStatement('orgInternalID');
	$sth->execute($orgInternalID);

	@row = $sth->fetchrow_array();

	$superBill->setOrgName($row[0]);
	$superBill->setTaxId($row[1]);

	$self->populateSuperBillComponent($superBill, $superBillID);
}

sub populateSuperBillComponent
{
	my ($self, $superBill, $superBillID) = @_;

	my $sth = $self->prepareStatement('catalogEntryHeader');
	my $sthCount = $self->prepareStatement('catalogEntryCount');
	my $sthComp = $self->prepareStatement('catalogEntries');


	$sth->execute($superBillID);
	while(my @row = $sth->fetchrow_array())
	{
		my $superBillComponent = new App::Billing::SuperBill::SuperBillComponent;

		$superBillComponent->setHeader($row[1]);

		$sthCount->execute($superBillID, $row[0]);
		my @rowCount = $sthCount->fetchrow_array();
		$superBillComponent->setCount($rowCount[0]);

		$sthComp->execute($superBillID, $row[0]);
		while(my @rowComp = $sthComp->fetchrow_array())
		{
			$superBillComponent->addCpt($rowComp[1]);
			$superBillComponent->addDescription($rowComp[2]);
		}

		$superBill->addSuperBillComponent($superBillComponent)
	}

}

sub dbDisconnect
{
	my $self = shift;
	$self->{dbiCon}->disconnect;
}

sub makeStatements
{
	my $self = shift;

	$self->{statements} =
	{
		'orgInternalID' => qq
		{
			select name_primary, tax_id
			from org
			where org_internal_id = ?
		},

		'catalogEntryHeader' => qq
		{
			select entry_id, name
			from offering_catalog_entry
			where catalog_id = ?
			and parent_entry_id is null
			and entry_type = 0
			and status = 1
			and not name = 'main'
			order by entry_id
		},

		'catalogEntryCount' => qq
		{
			select count(*)
			from offering_catalog_entry
			where catalog_id = ?
			and parent_entry_id = ?
			and entry_type = 100
			and status = 1
		},

		'catalogEntries' => qq
		{
			select entry_id, code, name
			from offering_catalog_entry
			where catalog_id = ?
			and parent_entry_id = ?
			and entry_type = 100
			and status = 1
			order by entry_id
		},
	};
}

sub getStatement
{
	my ($self, $statementID) = @_;

	my $statements = $self->{statements};
	return $statements->{$statementID};
}

sub prepareStatement
{
	my ($self, $statementID) = @_;


	my $statements = $self->{statements};
	return $self->{dbiCon}->prepare($statements->{$statementID});
}


1;
