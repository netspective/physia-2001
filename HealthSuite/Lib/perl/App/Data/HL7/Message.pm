##############################################################################
package App::Data::HL7::Message;
##############################################################################

use strict;
use base qw(Exporter);
use fields qw(allSegments sendingApp activeSegment activeSegmentsMap structuredSegments);
use App::Data::HL7::Segment;
use App::Data::HL7::Dictionary;

sub new
{
	my $class = shift;
		
	no strict 'refs';
	my $self = bless [\%{"$class\::FIELDS"}], $class;
	use strict 'refs';
	$self->init(@_);
	
	$self;
}

sub init
{
	my App::Data::HL7::Message $self = shift;
	my %params = @_;

	$self->{allSegments} = exists $params{allSegments} ? $params{allSegments} : [];
	$self->{sendingApp} = undef;
	$self->{activeSegmentsMap} = {};
	$self->{structuredSegments} = [];
	$self->{activeSegment} = undef;

	$self;
}

sub getSendingApp
{
	my App::Data::HL7::Message $self = shift;
	return $self->{sendingApp} ? $self->{sendingApp} : ($self->{sendingApp} = $self->getSegmentField('MSH', 3));
}

sub getCaption
{
	my App::Data::HL7::Message $self = shift;
	
	my $msgType = $self->getField('Message Type');
	if($msgType eq 'ORU')
	{
		return "Observation Results for @{[ $self->getField('Patient Name') ]}";
	}
	return "Uknown message type '$msgType'";
}

sub getHeaderSegment
{
	my App::Data::HL7::Message $self = shift;
	return $self->{allSegments}->[0];
}

sub getAllSegments
{
	my App::Data::HL7::Message $self = shift;
	return $self->{allSegments};
}

sub getStructuredSegments
{
	my App::Data::HL7::Message $self = shift;
	return $self->{structuredSegments};
}

sub getSegmentField
{
	my App::Data::HL7::Message $self = shift;
	my ($segmentId, $fieldNum, $fieldItemNum) = @_;

	if(my @segments = grep { $_->id() eq $segmentId } @{$self->{allSegments}})
	{
		# we'll work with only the first one and ignore the rest
		return $segments[0]->getField($fieldNum, $fieldItemNum);
	}
}

sub getField
{
	my App::Data::HL7::Message $self = shift;
	my ($fieldId, $defaultValue, $defaultCompare) = @_;
	
	#
	# if the $fieldId is a human-readable field id, then find the HL7 segment/field num
	#
	if(my $fieldDefn = App::Data::HL7::Dictionary::getFieldInfo($self->{sendingApp}, $fieldId))
	{
		$fieldId = $fieldDefn->[HL7_FIELDDEFN_LOCATION];
	}
	$defaultValue = '' unless defined $defaultValue;
	$defaultCompare = '' unless defined $defaultCompare;
	
	#
	# $fieldId looks like SID-5-2 where SID is segment ID, 5 is field number, 2 is subfield num
	#
	my ($segmentId, $fieldNum, $fieldItemNum) = split(/\-/, $fieldId);
	my $value = $self->getSegmentField($segmentId, $fieldNum, $fieldItemNum);
	
	return defined $value && $value ne $defaultCompare ? $value : $defaultValue;
}

sub addSegment
{
	my App::Data::HL7::Message $self = shift;
	my $structureMap = shift;
	
	my $allSegments = $self->{allSegments};
	my $structuredSegments = $self->{structuredSegments};
	foreach my $segment (@_)
	{
		my $segmentId = $segment->id();
		$self->{activeSegmentsMap}->{$segmentId} = [] unless exists $self->{activeSegmentsMap}->{$segmentId};
		$self->{activeSegmentsMap}->{$segmentId} = $segment;
		
		$segment->sequenceNumInMsg(scalar(@$allSegments));
		push(@$allSegments, $segment);

		if($segmentId eq 'NTE')
		{
			$self->{activeSegment}->addChildSegment($segment);			
		}
		else
		{
			if($segment->id() eq 'MSH')
			{
				$self->{sendingApp} = $segment->getField(3);
			}
			
			if(my $parentSegmentId = $structureMap->{$segmentId})
			{
				my App::Data::HL7::Segment $parentSegment = $self->{activeSegmentsMap}->{$parentSegmentId};
				if($parentSegment)
				{
					$parentSegment->addChildSegment($segment);
				}
				else
				{
					warn "parent segment '$parentSegmentId' not found\n";
				}
			}
			else
			{
				push(@$structuredSegments, $segment); 
			}

			$self->{activeSegment} = $segment;
		}
	}
}

sub exportString
{
	my App::Data::HL7::Message $self = shift;
	
	my @segmentStrings = ();
	foreach my $segment (@{$self->{allSegments}})
	{
		push(@segmentStrings, $segment->exportString());
	}
	return join("\n", @segmentStrings);
}

sub exportXML
{
	my App::Data::HL7::Message $self = shift;
	my ($xmlWriter) = @_;
	
	$xmlWriter->startTag("hl7-message");
	foreach my $segment (@{$self->{structuredSegments}})
	{
		$segment->exportXML($xmlWriter);
	}
	$xmlWriter->endTag();
}

1;
