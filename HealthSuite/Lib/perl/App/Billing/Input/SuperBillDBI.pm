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


	my $handle = $params{dbiHdl};

	if($handle)
	{
		$self->{dbiCon} = $handle;
	}
	else
	{
		$self->connectDb(%params);
	}

	my $org_internal_id = $orgInternalID;

	my $queryStatement;
	my $sth;
	my @row;

	$queryStatement = qq
	{
		select name_primary, tax_id
		from org
		where org_internal_id = $org_internal_id
	};

	$sth = $self->{dbiCon}->prepare("$queryStatement");
	$sth->execute;

	@row = $sth->fetchrow_array();
	$sth = undef;

	$superBill->setOrgName($row[0]);
	$superBill->setTaxId($row[1]);

	$self->populateSuperBillComponent($superBill, $superBillID);

	unless($handle)
	{
		$self->dbDisconnect;
	}

	return 1;
}

sub populateSuperBillComponent
{
	my ($self, $superBill, $superBillID) = @_;

	my $queryStatement;
	my $sth;
	my @row;

	$queryStatement = qq
	{
		select caption, internal_catalog_id
		from offering_catalog
		where catalog_id = '$superBillID'
	};

	$sth = $self->{dbiCon}->prepare("$queryStatement");
	$sth->execute;

	@row = $sth->fetchrow_array();

	my $catalogCaption = $row[0];
	my $internalCatalogID = $row[1];

	$queryStatement = qq
	{
		select entry_id, name
		from offering_catalog_entry
		where catalog_id = $internalCatalogID
		and parent_entry_id is null
		and entry_type = 0
		and status = 1
		order by entry_id
	};

	$sth = $self->{dbiCon}->prepare("$queryStatement");
	$sth->execute;

	while(@row = $sth->fetchrow_array())
	{
		my $superBillComponent = new App::Billing::SuperBill::SuperBillComponent;

		$superBillComponent->setHeader($row[1]);

		my $queryStatement;
		my $sthComp;
		my @rowComp;

		$queryStatement = qq
		{
			select count(*)
			from offering_catalog_entry
			where catalog_id = $internalCatalogID
			and parent_entry_id = $row[0]
			and entry_type = 100
			and status = 1
		};

		$sthComp = $self->{dbiCon}->prepare("$queryStatement");
		$sthComp->execute;
		@rowComp = $sthComp->fetchrow_array();
		$superBillComponent->setCount($rowComp[0]);

		$queryStatement = qq
		{
			select entry_id, code, name
			from offering_catalog_entry
			where catalog_id = $internalCatalogID
			and parent_entry_id = $row[0]
			and entry_type = 100
			and status = 1
			order by entry_id
		};

		$sthComp = $self->{dbiCon}->prepare("$queryStatement");
		$sthComp->execute;

		while(@rowComp = $sthComp->fetchrow_array())
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

1;
