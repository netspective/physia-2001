##############################################################################
package App::Dialog::Attribute::Allergy;
##############################################################################
use strict;
use DBI::StatementManager;
use App::Statements::Invoice;
use App::Statements::Person;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use Date::Manip;
use Devel::ChangeLog;
use vars qw(@ISA @CHANGELOG);
@ISA = qw(CGI::Dialog);

sub new
{
	my ($self, $command) = CGI::Dialog::new(@_, id => 'preventivecare');
	my $schema = $self->{schema};
	my $group = $self->{group};

	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(
		new CGI::Dialog::Field(name => 'attr_name', caption => $group, options => FLDFLAG_REQUIRED),
		new CGI::Dialog::Field(name => 'reactions',
				lookup => 'allergen_reaction',
				fKeyWhere => "group_name = '$group'",
				style => 'multicheck',
				caption => 'Reaction(s)'),
		new CGI::Dialog::Field(caption => 'Other Reactions', name => 'other_rxns', hints => 'You may choose more than one reaction.'),
		new CGI::Dialog::Field(caption => 'Comments', name => 'comments', type => 'memo'),

	);
	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Allergy '$group' to <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));

	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;

	return unless ($flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL);

	my $itemId = $page->param('item_id');
	my $data = $STMTMGR_PERSON->getAttribute($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);
	$page->fields($data);

	my $reactions = $STMTMGR_PERSON->getRowAsHash($page, STMTMGRFLAG_NONE, 'selAttributeById', $itemId);

	my @otherRxns = ();
	my @reactions = split(', ', $reactions->{value_text});

	foreach my $reaction (@reactions)
	{
		my $id = $STMTMGR_PERSON->getSingleValue($page, STMTMGRFLAG_NONE, 'selAllergicRxn', $reaction);

		if($id eq '')
		{
			push(@otherRxns, $reaction);
		}
	}

	my $lastItem = @otherRxns-1;
	my $otherRxnsField = '';
	foreach my $idx (0..$lastItem)
	{
		$otherRxnsField = $idx != $lastItem ? $otherRxnsField . "$otherRxns[$idx], " : $otherRxnsField . "$otherRxns[$idx]";
	}

	$page->field('reactions', @reactions);
	$page->field('other_rxns', $otherRxnsField);
	$page->field('comments', $reactions->{value_textb});
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $allergy = $page->field('attr_name');
	$allergy = "\u$allergy";
	my @reactions = $page->field('reactions');
	my @otherRxns = $page->field('other_rxns');

	foreach my $otherRxn (@otherRxns)
	{
		push(@reactions, $otherRxn);
	}

	$page->schemaAction(
		'Person_Attribute',	$command,
		parent_id => $page->param('person_id') || undef,
		item_id => $page->param('item_id') || undef,
		item_name => $allergy || undef,
		value_type => $self->{valueType} || undef,
		value_text => join(', ', @reactions) || undef,
		value_textB => $page->field('comments') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags | CGI::Dialog::DLGFLAG_IGNOREREDIRECT);
	return "\u$command completed.";
}


use constant PANEDIALOG_ALLERGY => 'Dialog/Allergy';

@CHANGELOG =
(
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '01/30/2000', 'MAF',
		PANEDIALOG_ALLERGY,
		'Created new dialog for allergies.'],
	[	CHANGELOGFLAG_SDE | CHANGELOGFLAG_NOTE, '03/14/2000', 'RK',
		PANEDIALOG_ALLERGY,
		'Removed Item Path from Item Name'],
);

1;
