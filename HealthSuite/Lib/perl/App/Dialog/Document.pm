##############################################################################
package App::Dialog::Document;
##############################################################################

use strict;
use App::Universal;
use Digest::MD5 qw(md5_hex);
use CGI::Validator::Field;
use CGI::Dialog;
use base qw(CGI::Dialog);

use vars qw(%RESOURCE_MAP);
%RESOURCE_MAP = (
	'document' => {},
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
	);

	$self->addFooter(new CGI::Dialog::Buttons());

	return $self;
}


sub makeStateChanges
{
	my ($self, $page, $command, $activeExecMode, $dlgFlags) = @_;

	$self->SUPER::makeStateChanges($page, $command, $activeExecMode, $dlgFlags);
}


sub execute
{
	my ($self, $page, $command, $flags) = @_;
	
	my $fileName = $page->param('_f_filedata');
	my $fileInfo = $page->uploadInfo($fileName);
	my $fh = $page->upload('_f_filedata');
	my $fileContents = join '', <$fh>;
	
	my $smallBuffer;
	my $largeBuffer;
	
	if (length($fileContents) > 3999)
	{
		$largeBuffer = \$fileContents;
	}
	else
	{
		$smallBuffer = \$fileContents;
	}

	my $documentId = $page->schemaAction(
		'Document', $command,
		doc_mime_type => 'text/plain',
		doc_message_digest => md5_hex($fileName, (stat($fh))[9]),
		doc_spec_type => App::Universal::DOCSPEC_MIME,
		doc_source_system => 'PHYSIA',
		doc_source_type => App::Universal::DOCSRCTYPE_PERSON,
		doc_source_id => $page->session('person_id'),
		doc_name => $page->field('doc_name') || undef,
		doc_description => $page->field('doc_description') || undef,
		doc_orig_stamp => undef,
		doc_recv_stamp => undef,
		doc_content_small => ref $smallBuffer ? $$smallBuffer : undef,
		doc_content_large => ref $largeBuffer ? $$largeBuffer : undef,
		_debug => 0
	);
}


1;
