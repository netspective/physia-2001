##############################################################################
package App::Dialog::Document;
##############################################################################

use strict;
use App::Universal;
use Digest::MD5 qw(md5_hex);
use CGI::Validator::Field;
use CGI::Dialog;
use base qw(CGI::Dialog);
use App::Page;
use DBI::StatementManager;
use App::Statements::Document;
use App::Dialog::Field::Person;
use App::Configuration;

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'document' => {
		_arl => ['doc_id'],
		_arl_add => ['spec_subtype'],
		_modes => ['add', 'update', 'remove', 'view'],
	},
);

sub new
{
	my $self = CGI::Dialog::new(
		@_,
		id => 'template',
		heading => '$Command Document',
		formAttrs => 'enctype="multipart/form-data"',
	);

	$self->addContent(
		new CGI::Dialog::Field(
			name => 'doc_id',
			options => FLDFLAG_READONLY,
			invisibleWhen => CGI::Dialog::DLGFLAG_ADD,
		),
		new App::Dialog::Field::Person::ID(
			name => 'owner_id',
			caption => 'Owner ID',
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(
			name => 'doc_name',
			caption => 'Name',
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(
			name => 'doc_description',
			caption => 'Description',
			type => 'memo',
		),
		new CGI::Dialog::Field(
			name => 'filedata',
			caption => 'File',
			type => 'file',
			options => FLDFLAG_REQUIRED,
		),
		new CGI::Dialog::Field(name => 'doc_mime_type', type => 'hidden'),
	);

	$self->addFooter(new CGI::Dialog::Buttons());

	return $self;
}


sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
}


sub populateData
{
	my $self = shift;
	my ($page, $command, $activeExecMode, $flags) = @_;

	return unless $flags & CGI::Dialog::DLGFLAG_DATAENTRY_INITIAL;
	$page->field('owner_id', $page->param('person_id'));
	return if $command eq 'add';
	$STMTMGR_DOCUMENT->createFieldsFromSingleRow($page, STMTMGRFLAG_NONE, 'selDocumentById', $page->param('doc_id'));

	if ($command eq 'view')
	{
		my $newReadLen = $CONFDATA_SERVER->db_BlobLongReadLength();
		my $oldReadLen = $page->{db}->{LongReadLen};
		$page->{db}->{LongReadLen} = $newReadLen;
		my $content = $STMTMGR_DOCUMENT->getRowAsArray($page, STMTMGRFLAG_NONE, 'selDocumentContentById', $page->param('doc_id'));
		$page->{db}->{LongReadLen} = $oldReadLen;
		my $buffer = $content->[0] ? $content->[0] : $content->[1];
		my $mime = $page->field('doc_mime_type');

		# Output the file directly to the broswer
		$page->setFlag(PAGEFLAG_CUSTOM);
		print $page->header(-type => $mime);
		print $buffer;
	}
}


sub customValidate
{
	my $self = shift;
	my ($page) = @_;

	my $maxSize = $CONFDATA_SERVER->db_BlobLongReadLength();
	my $fileName = $page->param('_f_filedata');
	my $fileInfo = $page->uploadInfo($fileName);
	my $fh = $page->upload('_f_filedata');
	my $fileSize = (stat($fh))[7];
	
	if ($fileSize >= $maxSize)
	{
		my $fileDataField = $self->getField('filedata');
		$fileDataField->invalidate($page, "Specified file is too big. Cannot be larger than $maxSize bytes.");
	}
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	my $fileName = $page->param('_f_filedata');
	my $fileInfo = $page->uploadInfo($fileName);
	my $fh = $page->upload('_f_filedata');
	my $fileContents = join '', <$fh>;
	my $fileSize = (stat($fh))[7];
	
	my $smallBuffer;
	my $largeBuffer;
	
	if ($fileSize >= 4000)
	{
		$largeBuffer = \$fileContents;
	}
	else
	{
		$smallBuffer = \$fileContents;
	}

	my $documentId = $page->schemaAction(
		'Document', $command,
		doc_mime_type => $fileInfo->{'Content-Type'},
		doc_message_digest => md5_hex($fileName, (stat($fh))[9]),
		doc_orig_stamp => $page->getTimeStamp(),
		doc_spec_type => App::Universal::DOCSPEC_MIME,
		doc_spec_subtype => $page->param('spec_subtype'),
		doc_source_system => 'PHYSIA',
		doc_source_type => App::Universal::DOCSRCTYPE_PERSON,
		doc_source_id => $page->session('person_id'),
		doc_name => $page->field('doc_name') || undef,
		doc_description => $page->field('doc_description') || undef,
		doc_recv_stamp => undef,
		doc_content_small => ref $smallBuffer ? $$smallBuffer : undef,
		doc_content_large => ref $largeBuffer ? $$largeBuffer : undef,
		doc_data_a => $page->field('owner_id') || undef,
		_debug => 0
	);
	$self->handlePostExecute($page, $command, $flags);
}


1;
