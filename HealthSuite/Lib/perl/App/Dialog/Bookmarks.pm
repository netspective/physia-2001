##############################################################################
package App::Dialog::Bookmarks;
##############################################################################

use strict;
use Carp;
use CGI::Dialog;
use CGI::Validator::Field;
use App::Universal;
use App::Statements::Org;
use App::Statements::Person;

use DBI::StatementManager;

use App::Universal;
use vars qw(@ISA %RESOURCE_MAP);
@ISA = qw(CGI::Dialog);

%RESOURCE_MAP = (
	'book-marks' => {
		heading => '$Command Bookmarks',
		_arl => ['person_id'],
		_arl_modify => ['item_id']
	},
);

sub new
{
 	my ($self, $command) = CGI::Dialog::new(@_, id => 'book-marks', heading => '$Command Bookmarks');
	my $schema = $self->{schema};
	delete $self->{schema};  # make sure we don't store this!

	croak 'schema parameter required' unless $schema;

	$self->addContent(

		new CGI::Dialog::Field (
			caption => 'Caption',
			name => 'caption',
			options => FLDFLAG_REQUIRED,
			hints => 'Please provide a friendly name of the bookmark',
		),

		new CGI::Dialog::Field (
			caption => 'URL',
			name => 'url',
			options => FLDFLAG_REQUIRED,
			hints => 'Please type in a URL',
		),

	);

	$self->{activityLog} =
	{
		level => 1,
		scope =>'person_attribute',
		key => "#param.person_id#",
		data => "Bookmarks <a href='/person/#param.person_id#/profile'>#param.person_id#</a>"
	};

	$self->addFooter(new CGI::Dialog::Buttons(cancelUrl => $self->{cancelUrl} || undef));
	return $self;
}

sub populateData
{
	my ($self, $page, $command, $activeExecMode, $flags) = @_;


	my $itemId = $page->param('item_id');

	$STMTMGR_PERSON->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selBookmarkById', $itemId) if $itemId;

	return unless $flags & CGI::Dialog::DLGFLAG_UPDORREMOVE_DATAENTRY_INITIAL;
}

sub execute
{
	my ($self, $page, $command, $flags) = @_;

	my $itemId = $page->param('item_id');

	$page->schemaAction(
		'Person_Attribute',
		$command,
		item_id => $itemId || undef,
		parent_id => $page->param('person_id') || undef,
		item_name => 'Bookmarks',
		value_type => 50,
		value_text => $page->field('url') || undef,
		value_textB => $page->field('caption') || undef,
		_debug => 0
	);

	$self->handlePostExecute($page, $command, $flags);
	return "\u$command completed.";
}



1;
