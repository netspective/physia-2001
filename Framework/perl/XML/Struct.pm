#
# This package takes a well-formed XML file and converts it into a perl-accessible
# set of hashes and lists. Has not been optimized for performance.
#
# * elements get converted to a hash (with _attrs, _name, _text default attributes)
#   element's children get converted into values with name of tag as key name
# * any tag with only a text value becomes a single scalar
# * any tags in a child list with common names are put into a list
# * any tags with child tags with the same name and just scalar values become a simple list
#
# Thus, the following are equivalent:
#
# <root attr="value">				| $data = { _attrs => { 'attr' => 'value'},
# 	<child>ChildValue1</child>		|			_name => 'root',
# 	<child>ChildValue2</child>		|			_text => '',
# 	<phones>						|			'child' => ['ChildValue1', 'ChildValue2'],
# 		<phone>one</phone>			|			'phones' => ['one', 'two', 'three']
# 		<phone>two</phone>			|			}
# 		<phone>three</phone>		|
# 	</phones>						|
# </root>							|
#
# Remember, the behavior of whether simple lists are created depends upon tag names,
# their equivalence, and whether they have attributes or not. A good way to understand
# the structure is to call importFile and then pass the result to the Dumpvalue module.
#
# The expected method of operation is to have a DTD validate an XML file, then call this
# package's methods to convert the data into perl.

package XML::Struct;

use strict;
use XML::DOM;
use enum qw(BITMASK:XMLSTRUCTFLAG_ ATTRSAREKEYS);

sub trackChildType
{
	my ($importOptions, $childInfoRef, $childName, $data) = @_;

	if(! exists $childInfoRef->{$childName})
	{
		$childInfoRef->{$childName} =
		{
			totalOfType => 0,
			scalarsList => [],
		};
	}
	my $childInfo = $childInfoRef->{$childName};

	$childInfo->{totalOfType}++;
	push(@{$childInfo->{scalarsList}}, $data) if ! ref $data;

	# track this for efficiency sake
	$childInfoRef->{_lastChildInfo} = $childInfo;
}

sub importElement
{
	my ($importOptions, $parentElem) = @_;

	my $attrsOnly = {};
	my $textOnly = '';
	my $data = { };
	my $flags = $importOptions->{flags};

	my $children = $parentElem->getChildNodes();
	my $childMax = $children->getLength();

	# this keeps track of our children type so that we can do list consolidations
	my $childTypesInfo = {};

	my $attrsMap = $parentElem->getAttributes();
	if($attrsMap)
	{
		foreach my $val ($attrsMap->getValues())
		{
			$attrsOnly->{$val->getName()} = $val->getValue();
		}
	}

	for(my $c = 0; $c < $childMax; $c++)
	{
		my $element = $children->item($c);
		my $elemName = $element->getNodeName();
		my $elemType = $element->getNodeType();

		if($elemType == TEXT_NODE)
		{
			$textOnly .= $element->getNodeValue() . ' ';
		}
		elsif($element->getNodeType() == ELEMENT_NODE)
		{
			# do recursive processing of children now
			my $childData = importElement($importOptions, $element);
			trackChildType($importOptions, $childTypesInfo, $elemName, $childData);

			if(exists $data->{$elemName})
			{
				# if there is already data for this node name, then we should
				# convert it into a list type
				if(ref $data->{$elemName} ne 'ARRAY')
				{
					my $existingData = $data->{$elemName};
					$data->{$elemName} = [];
					push(@{$data->{$elemName}}, $existingData);
				}

				push(@{$data->{$elemName}}, $childData);
			}
			else
			{
				$data->{$elemName} = $childData;
			}
		}
	}

	# Normalize the text
	# 1. replace multiple blanks, newlines, tabs with single space
	# 2. trim leading and trailing spaces
	$textOnly =~ tr/\n\r\t\f/ /d;
	$textOnly =~ s/\s+/ /g;
	$textOnly =~ s/^\s+//;
	$textOnly =~ s/\s+$//;

	# if there are no children and no attributes, the text is all there is (simplified)
	if(scalar(keys %{$data}) == 0 && scalar(keys %$attrsOnly) == 0)
	{
		$data = $textOnly;
	}
	else
	{
		# if the current node has no attributes or text value and there is only a single
		# child type that is comprised of a simple list of scalars, take on its value
		#
		if(
			scalar(keys %{$attrsOnly}) == 0 &&
			$textOnly eq '' &&
			(scalar(keys %{$childTypesInfo}) - 1) == 1 &&
			$childTypesInfo->{_lastChildInfo}->{totalOfType} == scalar(@{$childTypesInfo->{_lastChildInfo}->{scalarsList}})
		  )
		{
			$data = $childTypesInfo->{_lastChildInfo}->{scalarsList};
		}
		else
		{
			$data->{_name} = $parentElem->getNodeName();
			if($flags & XMLSTRUCTFLAG_ATTRSAREKEYS)
			{
				foreach(keys %$attrsOnly)
				{
					$data->{$_} = $attrsOnly->{$_};
				}
			}
			else
			{
				$data->{_attrs} = $attrsOnly;
			}
			$data->{_text} = $textOnly;
			$data->{_childTypesInfo} = $childTypesInfo if exists $importOptions->{debug} && $importOptions->{debug};
		}
	}

	return $data;
}

sub domNodeToStruct
{
	my ($node) = @_;
	my $importOptions =
		{
			debug => 0,
			flags => XMLSTRUCTFLAG_ATTRSAREKEYS,
		};
	my $allData = importElement($importOptions, $node);
	return $allData;
}

sub xmlToStruct
{
	my ($fileName) = @_;

	my $parser = new XML::DOM::Parser;
	return &domNodeToStruct($parser->parsefile($fileName)->getDocumentElement());
}

1;