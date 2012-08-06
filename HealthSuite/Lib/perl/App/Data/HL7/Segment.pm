##############################################################################
package App::Data::HL7::Segment;
##############################################################################

use strict;
use Date::Manip;
use Exporter;
use base qw(Exporter);
use fields qw(id fields sequenceNumInMsg srcString structuredChildSegments);

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
	my App::Data::HL7::Segment $self = shift;
	my %params = @_;

	$self->{id} = exists $params{id} ? $params{id} : undef;
	$self->{fields} = exists $params{fields} ? $params{fields} : undef;

	$self->importString($params{srcString}) if $params{srcString};
	$self;
}

sub sequenceNumInMsg
{
	my App::Data::HL7::Segment $self = shift;
	$self->{sequenceNumInMsg} = $_[0] if defined $_[0];
	return $self->{sequenceNumInMsg};
}

sub getChildren
{
	my App::Data::HL7::Segment $self = shift;
	return $self->{structuredChildSegments};
}

sub getChildCount
{
	my App::Data::HL7::Segment $self = shift;
	return $self->{structuredChildSegments} ? scalar(@{$self->{structuredChildSegments}}) : 0;
}

sub getField
{
	my App::Data::HL7::Segment $self = shift;
	my ($fieldNum, $fieldItemNum) = @_;
	
	#
	# $fieldNum and $fieldItemNum are 1-based (not zero-based)
	#

	my $field = $self->{fields}->[$fieldNum-1];
	return ref $field eq 'ARRAY' ? (defined $fieldItemNum ? $field->[$fieldItemNum-1] : join(',', @$field)) : $field;
}

sub importString
{
	my App::Data::HL7::Segment $self = shift;
	my $src = shift;
	
	chop($src) if substr($src, length($src)-1, 1) eq "\r";
	$self->{srcString} = $src;
	
	#
	# each field is delimited by '|'
	#
	my @fields = split(/\|/, $self->{srcString});	
	my $isMSH = $fields[0] eq 'MSH';
	
	for(my $f = 0; $f <= $#fields; $f++)
	{
		my $notDelimiterDefn = ($isMSH && $f == 1) ? 0 : 1;
		#
		# if any of the fields contain '^' then they have components
		#
		if($notDelimiterDefn && index($fields[$f], '^') >= 0)
		{
			my @components = split(/\^/, $fields[$f]);
			for(my $c = 0; $c <= $#components; $c++)
			{
				if(index($components[$c], '&') >= 0)
				{
					my @subComponents = split(/\&/, $components[$c]);
					$components[$c] = \@subComponents;
				}
			}
			$fields[$f] = \@components;
		}

		#
		# if any of the fields contain '~' then they are repeated
		#
		if($notDelimiterDefn && index($fields[$f], '~') >= 0)
		{
			my @components = split(/\~/, $fields[$f]);
			$fields[$f] = \@components;
		}
	}
	
	$self->{fields} = \@fields;
	$self->{id} = $fields[0];
}

sub exportString
{
	my App::Data::HL7::Segment $self = shift;
	
	return $self->{srcString} if $self->{srcString};
	die "TODO: exportString from non-imported HL7 document not implemented yet";
}

sub addChildSegment
{
	my App::Data::HL7::Segment $self = shift;
	$self->{structuredChildSegments} = [] unless $self->{structuredChildSegments};
	push(@{$self->{structuredChildSegments}}, @_);	
}

sub exportXML
{
	my App::Data::HL7::Segment $self = shift;
	my ($xmlWriter) = @_;
	
	my $id = $self->id();
	my $fieldNum = 0;
	
	$xmlWriter->startTag($id);
	foreach (@{$self->{fields}})
	{
		$fieldNum++;
		if(ref $_ eq 'ARRAY')
		{
			$xmlWriter->startTag("$id-$fieldNum");
			my $componentNum = 0;
			
			foreach (@$_)
			{
				$componentNum++;
				if(ref $_ eq 'ARRAY')
				{
					$xmlWriter->startTag("$id-$fieldNum-$componentNum");
					my $subCompNum = 0;
					
					foreach (@$_)
					{
						$subCompNum++;
						$xmlWriter->dataElement("$id-$fieldNum-$componentNum-$subCompNum", $_) unless $_ eq '';
					}
					$xmlWriter->endTag();
				}
				else
				{
					$xmlWriter->dataElement("$id-$fieldNum-$componentNum", $_) unless $_ eq '';
				}
			}
			$xmlWriter->endTag();
		}
		else
		{
			$xmlWriter->dataElement("$id-$fieldNum", $_) unless $_ eq '';
		}
	}
	
	if($self->{structuredChildSegments})
	{
		foreach my $segment (@{$self->{structuredChildSegments}})
		{
			$segment->exportXML($xmlWriter);
		}
	}
	$xmlWriter->endTag();
}

sub id
{
	my App::Data::HL7::Segment $self = shift;
	
	$self->{fields}->[0] = $_[0] if $_[0];
	return $self->{fields}->[0];
}

1;
