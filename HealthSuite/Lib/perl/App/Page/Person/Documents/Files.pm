##############################################################################
package App::Page::Person::Documents::Files;
##############################################################################

use strict;
use App::Page::Person;
use base qw(App::Page::Person::Documents);

use CGI::Dialog::DataNavigator;
use CGI::ImageManager;
use SQL::GenerateQuery;
use App::Configuration;
use Data::Publish;

use vars qw(%RESOURCE_MAP $QDL %PUB_IMGFILES);
%RESOURCE_MAP = (
	'person/documents/images' => {
		_tabCaption => 'Images',
		_specSubType => App::Universal::FILESUBTYPE_IMAGE,
		},
	'person/documents/notes' => {
		_tabCaption => 'Dictation/Notes',
		_specSubType => App::Universal::FILESUBTYPE_NOTES,
		},
	'person/documents/auth' => {
		_tabCaption => 'Referral/Auth',
		_specSubType => App::Universal::FILESUBTYPE_AUTH,
		},
	'person/documents/corespondence' => {
		_tabCaption => 'Corespondence',
		_specSubType => App::Universal::FILESUBTYPE_CORESPONDENCE,
		},
	'person/documents/misc' => {
		_tabCaption => 'Misc',
		_specSubType => App::Universal::FILESUBTYPE_MISC,
		},
	);


$QDL = File::Spec->catfile($CONFDATA_SERVER->path_Database(), 'QDL', 'Document.qdl');


%PUB_IMGFILES = (
	name => 'imagefiles',
	banner => {
		actionRows => [
			{caption => 'Add Document', url => '/person/#param.person_id#/dlg-add-document/#param._specSubType#?home=#homeArl#',},
		],
	},
	columnDefn => [
		{head => '#', dataFmt => '#{auto_row_number}#',},
		{head => '', colIdx => '#{doc_mime_type}#', dataFmt => \&iconCallback,},
		{head => 'Name', colIdx => '#{name}#',},
		{head => 'Description', colIdx => '#{description}#',},
		{head => 'Date', colIdx => '#{created}#', dformat => 'stamp',},
		{head => 'Source', colIdx => '#{source_person_id}#',},
	],
	dnQuery => \&imageFilesQuery,
	dnSelectRowAction => '/person/#session.person_id#/dlg-view-document/#{doc_id}#?home=#homeArl#',
);


sub iconCallback
{
	my $value = $_[0]->[$_[1]];
	if (exists $IMAGETAGS{"icons/mime/$value"})
	{
		return $IMAGETAGS{"icons/mime/$value"};
	}
	else
	{
		return $IMAGETAGS{"icons/default"};
	}
}

sub imageFilesQuery
{
	my $self = shift;
	my $sqlGen = new SQL::GenerateQuery(file => $QDL);

	my $cond1 = $sqlGen->WHERE('owner_id', 'is', $self->param('person_id'));
	my $cond2 = $sqlGen->WHERE('spec_type', 'is', App::Universal::DOCSPEC_MIME);
	my $cond3 = $sqlGen->WHERE('spec_subtype', 'is', $self->param('_specSubType'));
	my $cond4 = $sqlGen->AND($cond1, $cond2, $cond3);
	$cond4->outColumns(
		'doc_id',
		'doc_mime_type',
		'name',
		'created',
		'source_person_id',
		'description',
	);
	return $cond4;
}


########################################################
# Handle the page display
########################################################

sub prepare_view
{
	my $self = shift;

	# Create html file tabs for each document type
	my $tabsHtml = $self->setupTabs();

	my $resource = $self->property('resourceMap');
	$self->param('_specSubType', $resource->{'_specSubType'});

	# Create the work list dialog
	my $dlg = new CGI::Dialog::DataNavigator(publDefn => \%PUB_IMGFILES, topHtml => $tabsHtml, page => $self);
	my $dlgHtml = $dlg->getHtml($self, 'add');

	$self->addContent($dlgHtml);
}


1;
