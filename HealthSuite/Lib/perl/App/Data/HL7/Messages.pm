##############################################################################
package App::Data::HL7::Messages;
##############################################################################

use strict;
use base qw(Exporter);
use fields qw(srcFile messages msgStructure segmentOwnersMap segmentsMap);

use App::Data::HL7::Segment;
use App::Data::HL7::Message;
use XML::Writer;
use IO;

use constant DEFAULT_STRUCTURE => 
{
	'MSH' => 
	{
		'PID' => 
		{
			'PV1' => { },
			'ORC' => { },
			'OBR' => 
			{
				'OBX' => {},
				'ZPS' => {},
			},
		}
	},
};

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
	my App::Data::HL7::Messages $self = shift;
	my %params = @_;

	$self->{messages} = exists $params{messages} ? $params{messages} : [];
	$self->{segmentOwnersMap} = exists $params{segmentOwnersMap} ? $params{segmentOwnersMap} : {};
	$self->{segmentsMap} = exists $params{segmentsMap} ? $params{segmentsMap} : {};
	
	my $msgStruct = exists $params{msgStructure} ? $params{msgStructure} : DEFAULT_STRUCTURE;
	$self->defineStructure(%$msgStruct);
	
	$self;
}

sub populateRelationship
{
	my App::Data::HL7::Messages $self = shift;
	my ($id, $relationship, $parentId) = @_;
	
	$self->{segmentOwnersMap}->{$id} = $parentId if $parentId;
	while(my ($key, $value) = each(%$relationship))
	{
		$self->populateRelationship($key, $value, $id);
	}
}

sub defineStructure
{
	my App::Data::HL7::Messages $self = shift;
	my %params = @_;
	
	while(my ($key, $value) = each(%params))
	{
		$self->populateRelationship($key, $value);
	}
}

sub defineParent
{
	my App::Data::HL7::Messages $self = shift;
	my %params = @_;
	
	while(my ($key, $value) = each(%params))
	{
		$params{segmentOwnersMap}->{$key} = $value;
	}
}

sub importFile
{
	my App::Data::HL7::Messages $self = shift;
	my ($srcFile) = @_;
	
	if(open(SRC, $srcFile))
	{
		$self->{srcFile} = $srcFile;

		my $activeMessage = undef;
		my $messages = $self->{messages};
		my $ownersMap = $self->{segmentOwnersMap};
		
		while(<SRC>)
		{
			chomp;
			my $segment = new App::Data::HL7::Segment(srcString => $_);
			
			# ignore every segment starting with a 'Z' because these are "vendor-specific"
			next if substr($segment->id(), 0, 1) eq 'Z';
			
			if($segment->id() eq 'MSH')
			{
				$activeMessage = new App::Data::HL7::Message;
				push(@$messages, $activeMessage);
			}
			$activeMessage->addSegment($ownersMap, $segment);
		}
		close(SRC);
		
		#
		# create a dictionary of all segment IDs and the segment instance for each ID
		#
		my $segmentsMap = $self->{segmentsMap};
		foreach my $message (@$messages)
		{
			foreach my $segment (@{$message->getAllSegments()})
			{
				my $id = $segment->id();
				$segmentsMap->{$id} = [] unless exists $segmentsMap->{$id};
				push(@{$segmentsMap->{$id}}, $segment);
			}
		}
	}
}

sub getMessagesList
{
	my App::Data::HL7::Messages $self = shift;
	return $self->{messages};
}

sub getSegments
{
	my App::Data::HL7::Messages $self = shift;	
	
	#
	# given one or more segment IDs, return all the segments that match those IDs
	# (in the order that the IDs are provided)
	#
	
	my $segmentsMap = $self->{segmentsMap};
	my @segments = ();
	foreach (@_)
	{
		if(my $segments = $segmentsMap->{$_})
		{
			push(@segments, @$segments);
		}
	}
	
	return \@segments;
}

sub getMessagesCount
{
	my App::Data::HL7::Messages $self = shift;	
	return scalar(@{$self->{messages}});
}

sub exportXML
{
	my App::Data::HL7::Messages $self = shift;	
	my $destFile = shift;
	
	my $output = new IO::File(">$destFile");

	my $writer = new XML::Writer(OUTPUT => $output);
	$writer->startTag("mdl");
	foreach my $message (@{$self->{messages}})
	{
		$message->exportXML($writer);
	}
	$writer->endTag();
	$writer->end();
	$output->close();	
}

1;
