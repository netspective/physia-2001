##############################################################################
package App::Data::Transform::OracleCTL;
##############################################################################

use strict;
use Carp;
use App::Data::Transform;

use vars qw(@ISA);
@ISA = qw(App::Data::Transform);

sub defineCtl
{
	my ($self, $flags, $collection, $params) = @_;
	$self->abstract();
}

sub createHeader
{
	my ($self, $flags, $collection, $params) = @_;
	my $ctlInfo = $params->{ctlInfo} || $self->defineCtl($flags, $collection, $params);

	my $fields = join(', ', @{$ctlInfo->{fields}});
	my $inFile = $ctlInfo->{dataFile} ? "'$ctlInfo->{dataFile}'" : '*';
	my $beginData = $inFile eq '*' ? "BEGINDATA" : '';
	my $header = <<"	END_HEADER";
	LOAD DATA
		INFILE $inFile
		$ctlInfo->{updateMethod}
	INTO TABLE $ctlInfo->{tableName}
		FIELDS TERMINATED BY "$ctlInfo->{fieldSeparator}"
		TRAILING NULLCOLS
	($fields)
	$beginData
	END_HEADER
	$header =~ s/^\t//gm;
	return $header;
}

sub process
{
	my ($self, $flags, $collection, $params) = @_;

	unless($params->{outFile})
	{
		$self->addError("outFile parameter not found");
		return;
	}

	my $ctlInfo = $params->{ctlInfo} || $self->defineCtl($flags, $collection, $params);
	my $fieldSep = $ctlInfo->{fieldSeparator};
	my $data = $collection->getDataRows();

	if(open(DEST, ">$params->{outFile}"))
	{
		print DEST $self->createHeader($flags, $collection, $params);
		foreach(@$data)
		{
			next unless $_;
			print DEST join($fieldSep, @$_) . "\n";
		}
		close(DEST);
	}
	else
	{
		$self->addError("Unable to create $params->{outFile}: $!");
	}
}

1;