package Schema::Utilities;

use strict;

sub wrapListItems
{
	my ($listRef, $leftSide, $rightSide) = @_;
	if(ref $listRef eq 'ARRAY')
	{
		grep
		{
			$_ = "$leftSide$_$rightSide";
		} @{$listRef};
		return $listRef;
	}
	else
	{
		return $listRef;
	}
}

sub addSingleQuotes
{
	my ($data) = @_;
	if(ref $data eq 'ARRAY')
	{
		grep
		{
			$_ =~ s/'/''/g;
			$_ = "'$_'";
		} @{$data};
		return $data;
	}
	else
	{
		$data =~ s/'/''/g;
		return "'$data'";
	}
}

sub mergeWhereConditions
{
	my $operator = shift;
	my @conds = ();
	foreach (@_)
	{
		push(@conds, "($_)") if $_;
	}

	return join(" $operator ", @conds);
}

sub createInclusionExclusionConds
{
	my ($colName, $inclList, $exclList, $upperCase) = @_;
	$upperCase = 0 if ! defined $upperCase;

	my ($inclCount, $exclCount) = ($inclList ? scalar(@$inclList) : 0, $exclList ? scalar(@$exclList) : 0);
	my ($restrictList, $excludeList);

	if($upperCase)
	{
		$colName = "upper($colName)" if $upperCase;
		$restrictList = $inclCount ? uc(join(',', @{addSingleQuotes($inclList)})) : '';
		$excludeList = $exclCount ? uc(join(',', @{addSingleQuotes($exclList)})) : '';
	}
	else
	{
		$restrictList = $inclCount ? join(',', @{addSingleQuotes($inclList)}) : '';
		$excludeList = $exclCount ? join(',', @{addSingleQuotes($exclList)}) : '';
	}

	my $cond = '';
	if($inclCount && $exclCount)
	{
		$cond = $inclCount > 1 ? "$colName in ($restrictList) " : "$colName = $restrictList ";
		$cond .= $exclCount > 1 ? "and $colName not in ($excludeList)" : "$colName != $excludeList";
	}
	elsif($inclCount)
	{
		$cond = $inclCount > 1 ? "$colName in ($restrictList)" : "$colName = $restrictList";
	}
	elsif($exclCount)
	{
		$cond .= $exclCount > 1 ? "$colName not in ($excludeList)" : "$colName != $excludeList";
	}
	return $cond;
}

1;