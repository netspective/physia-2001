##############################################################################
package App::Component::Navigate::FileSys;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;
use File::Spec;
use File::Basename;
use App::Configuration;
use Data::Publish;
use Exporter;
use Date::Manip;
use enum qw(BITMASK:NAVGPATHFLAG_ STAYATROOT REVERSESORT);
use enum qw(BITMASK:NAVGFILEFLAG_ PERLOBJECT RAWTEXT HTML XML PASSTHROUGH TRANSLATEUNDL TRANSLATEDATES ORGLOCKDOWN);
use vars qw(@ISA @EXPORT %MODULE_FILE_MAP %FILE_MODULE_MAP %FILE_TYPE_MAP %RESOURCE_MAP);
@ISA   = qw(Exporter CGI::Component);
@EXPORT = qw(NAVGPATHFLAG_STAYATROOT NAVGFILEFLAG_PERLOBJECT NAVGFILEFLAG_RAWTEXT NAVGFILEFLAG_HTML NAVGFILEFLAG_XML);

%MODULE_FILE_MAP = ();
%FILE_MODULE_MAP = ();

use constant FILEEXTNINFO_FLAGS		=> 0;
use constant FILEEXTNINFO_ICON		=> 1;
use constant FILEEXTNINFO_ICONHIGHL	=> 2;
use constant FILEFLAGS_DEFAULT	=> NAVGFILEFLAG_TRANSLATEUNDL | NAVGFILEFLAG_TRANSLATEDATES;

use constant FILETYPEID_DEFAULT		=> 'DEFAULT';
use constant FILETYPEID_DIROPEN		=> 'DIRECTORY_OPEN';
use constant FILETYPEID_DIRCLOSED	=> 'DIRECTORY_CLOSED';

use constant ICONGRAPHIC_SELARROW	=> '/resources/icons/arrow-double-cyan.gif';
use constant ICONGRAPHIC_PAGE		=> '/resources/icons/report-yellow.gif';

%FILE_TYPE_MAP = (
	'.pm' => [NAVGFILEFLAG_PERLOBJECT, ICONGRAPHIC_PAGE, ICONGRAPHIC_SELARROW],
	'.log' => [NAVGFILEFLAG_RAWTEXT | FILEFLAGS_DEFAULT, ICONGRAPHIC_PAGE, ICONGRAPHIC_SELARROW],
	'.txt' => [NAVGFILEFLAG_RAWTEXT | FILEFLAGS_DEFAULT, ICONGRAPHIC_PAGE, ICONGRAPHIC_SELARROW],
	'.pdf' => [NAVGFILEFLAG_PASSTHROUGH | FILEFLAGS_DEFAULT | NAVGFILEFLAG_ORGLOCKDOWN, ICONGRAPHIC_PAGE, ICONGRAPHIC_SELARROW],
	'.claims' => [FILEFLAGS_DEFAULT | NAVGFILEFLAG_ORGLOCKDOWN, ICONGRAPHIC_PAGE, ICONGRAPHIC_SELARROW],
	
	FILETYPEID_DIROPEN() => [NAVGFILEFLAG_TRANSLATEUNDL, '/resources/icons/folder-orange-open.gif', ICONGRAPHIC_SELARROW],
	FILETYPEID_DIRCLOSED() => [NAVGFILEFLAG_TRANSLATEUNDL, '/resources/icons/folder-orange-closed.gif', ICONGRAPHIC_SELARROW],
	FILETYPEID_DEFAULT() => [NAVGFILEFLAG_RAWTEXT | FILEFLAGS_DEFAULT, ICONGRAPHIC_PAGE, ICONGRAPHIC_SELARROW],
);

%RESOURCE_MAP = (
	'navigate-reports' => {
		_class => new App::Component::Navigate::FileSys(
			heading => 'View Report',
			rootFS => File::Spec->catfile($CONFDATA_SERVER->path_OrgReports(), 'General'),
			rootURL => '/report',
			rootCaption => 'View Reports',
			),
		},
	'navigate-reports-root' => {
		_class => new App::Component::Navigate::FileSys(
			heading => 'View Report',
			rootFS => File::Spec->catfile($CONFDATA_SERVER->path_OrgReports(), 'General'),
			rootURL => '/report',
			rootCaption => 'View Reports',
			flags => NAVGPATHFLAG_STAYATROOT,
			),
		},
	'navigate-directory-panel' => {
		_class => new App::Component::Navigate::FileSys(
			heading => 'Directory',
			rootFS => File::Spec->catfile($CONFDATA_SERVER->path_OrgDirectory(), 'General'),
			rootURL => '/directory',
			rootCaption => 'Directory',
			),
		},
	'navigate-directory-root' => {
		_class => new App::Component::Navigate::FileSys(
			heading => 'Directory',
			rootFS => File::Spec->catfile($CONFDATA_SERVER->path_OrgDirectory(), 'General'),
			rootURL => '/directory',
			rootCaption => 'Directory',
			flags => NAVGPATHFLAG_STAYATROOT,
			),
		},
	'navigate-directory-transparent' => {
		_class => new App::Component::Navigate::FileSys(
			heading => 'Directory',
			rootFS => File::Spec->catfile($CONFDATA_SERVER->path_OrgDirectory(), 'General'),
			rootURL => '/directory',
			style => 'panel.transparent',
			rootCaption => 'Directories',
			),
		},
	);

#
# the following methods are STATIC (no instance required)
#
sub getModuleNameForFile
{
	my ($rootFS, $activePath) = @_;
	my $fileName = File::Spec->catfile($rootFS, ref $activePath eq 'ARRAY' ? @$activePath : $activePath) . '.pm';

	if(-f $fileName)
	{
		unless(exists $FILE_MODULE_MAP{$fileName})
		{
			require $fileName;
			open(MODFILE, $fileName) || return;
			while(<MODFILE>)
			{
				if (/^ *package +(\S+);/)
				{
					$FILE_MODULE_MAP{$fileName} = $1;
					$MODULE_FILE_MAP{$1} = $fileName;
				}
			}
			close(MODFILE);
		}
	}

	return exists $FILE_MODULE_MAP{$fileName} ? $FILE_MODULE_MAP{$fileName} : '';
}

sub getActivePathInfo
{
	my ($flags, $rootFS, $rootURL, $activePath, $style) = @_;

	my $styleOptions = {};
	if(ref $style eq 'HASH')
	{
		$styleOptions = $style;
		$style = exists $styleOptions->{style} ? $styleOptions->{style} : undef;
	}
	$style ||= 'tree';

	unless(ref $activePath eq 'ARRAY')
	{
		my @activePath = split(/\//, $activePath);
		$activePath = \@activePath;
	}

	my ($fsPath, $urlPath, $typeInfo) = ($rootFS, $rootURL, $FILE_TYPE_MAP{FILETYPEID_DIROPEN()});
	my ($dirFlags, $openDirIcon) = ($typeInfo->[FILEEXTNINFO_FLAGS], $typeInfo->[FILEEXTNINFO_ICON]);
	if($style eq 'tree')
	{
		my @items = ();
		my $level = 0;
		if(my $caption = $styleOptions->{rootCaption})
		{
			push(@items, qq{ <IMG SRC='$openDirIcon'> <A HREF='$urlPath'>$caption</A>});
			$level = 1;
		}
		foreach (@$activePath)
		{
			$fsPath = File::Spec->catfile($fsPath, $_);
			last unless -d $fsPath;
			$urlPath .= '/' . $_;
			s/_/ /g if $dirFlags & NAVGFILEFLAG_TRANSLATEUNDL;
			push(@items, qq{@{[ '&nbsp;&nbsp'x$level ]} <IMG SRC='$openDirIcon'> <A HREF='$urlPath'>$_</A>});
			$level++;
		}
		return join('<BR>', @items);
	}
	elsif($style eq 'locator')
	{
		my @items = ();
		foreach (@$activePath)
		{
			$fsPath = File::Spec->catfile($fsPath, $_);
			last unless -d $fsPath;
			$urlPath .= '/' . $_;
			push(@items, [$_, $urlPath]);
		}
		return @items;
	}
}

sub getActivePathContents
{
	my ($page, $flags, $rootFS, $rootURL, $activePath, $style, $highlight) = @_;
	
	my ($fsPath, $urlPath) = ($rootFS, $rootURL . '/');
	unless($flags & NAVGPATHFLAG_STAYATROOT)
	{
		$fsPath = File::Spec->catfile($rootFS, ref $activePath eq 'ARRAY' ? @$activePath : $activePath);
		$urlPath = $rootURL . '/' . (ref $activePath eq 'ARRAY' ? join('/', @$activePath) : $activePath);
	}

	my @items = ();
	my $orgInternalId = $page->session('org_internal_id');

	my $addPathEntry = sub
	{
		my ($entryName, $isDirectory) = @_;
		
		my $fullNameAndPath = "$fsPath/$entryName";
		my ($fileName, $filePath, $fileExtn) = fileparse($_, '\..*');
		my $fileTypeInfo = $isDirectory ? 
			$FILE_TYPE_MAP{FILETYPEID_DIRCLOSED()} : 
			($FILE_TYPE_MAP{$fileExtn} || $FILE_TYPE_MAP{FILEFLAGS_DEFAULT()});
		my $fileTypeFlags = $fileTypeInfo->[FILEEXTNINFO_FLAGS];
		my $myOrgFile;
		
		if($fileTypeFlags & NAVGFILEFLAG_PERLOBJECT)
		{
			require $fullNameAndPath;
			open(MODFILE, $fullNameAndPath) || return;
			while(<MODFILE>)
			{
				if (/^ *package +(\S+);/)
				{
					my $moduleName = $1;
					$FILE_MODULE_MAP{$fullNameAndPath} = $moduleName;
					$MODULE_FILE_MAP{$moduleName} = $fullNameAndPath;

					no strict 'refs';
					my $icon = $highlight eq $fileName ? $fileTypeInfo->[FILEEXTNINFO_ICONHIGHL] : $fileTypeInfo->[FILEEXTNINFO_ICON];
					if(my $instance = ${"$moduleName\::INSTANCE"}) {
						push(@items, ["$urlPath/$fileName", $instance->heading(), $icon]);
					} else {
						push(@items, ["$urlPath/$fileName", $fileName, $icon]);
					}
					last;
				}
			}
			close(MODFILE);
		}
		else
		{
			my $icon = $highlight eq $entryName ? $fileTypeInfo->[FILEEXTNINFO_ICONHIGHL] : $fileTypeInfo->[FILEEXTNINFO_ICON];
			if($fileTypeFlags & NAVGFILEFLAG_TRANSLATEDATES)
			{
				if ($fileTypeFlags & NAVGFILEFLAG_ORGLOCKDOWN)
				{
					$fileName =~ s/^(\d*?)\_(\d\d\d\d)\-(\d\d)\-(\d\d)\_(\d\d)\-(\d\d)/UnixDate("$3\/$4\/$2 $5:$6", '%F (%T)') || "Invalid Date"/e;
					$myOrgFile = ($1 == $orgInternalId) ? 1 : 0;
				}
				else
				{
					$fileName =~ s/^(\d\d\d\d)\-(\d\d)\-(\d\d)\_(\d\d)\-(\d\d)/UnixDate("$2\/$3\/$1 $4:$5", '%F (%T)') || "Invalid Date"/e;
				}
			}
			if($fileTypeFlags & NAVGFILEFLAG_TRANSLATEUNDL)
			{
				$fileName =~ s/_/ /g;
			}
			push(@items, 
				[	$isDirectory ? "$urlPath$entryName" : ($fileTypeFlags & NAVGFILEFLAG_PASSTHROUGH ? 
					"$urlPath/$entryName" : "$urlPath?enter=$fullNameAndPath&ecaption=$fileName&eflags=$fileTypeFlags"), 
					$fileName, $icon
				]
			) if (($fileTypeFlags & NAVGFILEFLAG_ORGLOCKDOWN) && $myOrgFile) 
					|| !($fileTypeFlags & NAVGFILEFLAG_ORGLOCKDOWN);
		}
	};

	if(opendir(ACTIVEPATH, $fsPath))
	{
		my @dirs = ();
		my @files = ();
		grep
		{
			unless(m/^\./) # skip hidden files and subdirectories
			{
				if(-d "$fsPath/$_")	{
					push(@dirs, $_);
				} else {
					push(@files, $_);
				}
			}
		} readdir(ACTIVEPATH);
		closedir(ACTIVEPATH);

		foreach (sort @dirs)
		{
			&$addPathEntry($_, 1) unless $_ eq 'CVS';
		}

		if ($flags & NAVGPATHFLAG_REVERSESORT)
		{
			foreach (reverse sort @files)
			{
				&$addPathEntry($_, 0);
			}
		}
		else
		{
			foreach (sort @files)
			{
				&$addPathEntry($_, 0);
			}
		}
	}
	else
	{
		# truncate the last item and try again
		unless(ref $activePath eq 'ARRAY')
		{
			my @activePath = split(/\//, $activePath);
			$activePath = \@activePath;
		}
		if(scalar(@$activePath))
		{
			my $highlight = pop @$activePath;
			return getActivePathContents($page, $flags, $rootFS, $rootURL, $activePath, $style, $highlight);
		}
		else
		{
			push(@items, ['', "'$fsPath' is not a directory", '']);
		}
	}
	return \@items;
}

#
# instance methods now follow
#

sub init
{
	my $self = shift;
	$self->{publishDefn} =
	{
		flags => PUBLFLAG_HIDEHEAD,
		bodyFontOpen => '<FONT FACE="Verdana,Arial,Helvetica" SIZE=2>',
		rowSepStr => '',
		frame =>
		{
			headColor => '#EEEEEE',
			borderColor => exists $self->{style} ? ($self->{style} eq 'panel.transparent' ? '#FFFFFF' : '#CCCCCC') : '#CCCCCC',
			contentColor => '#FFFFFF',
			heading => '#my.activePath#',
			width => '100%',
		},
		columnDefn => [
			{ dataFmt => '<A HREF="#0#"><IMG SRC="#2#" BORDER=0></A>' },
			{ dataFmt => '<A HREF="#0#">#1#</A>' }
			],
	};
	die 'rootFS and heading are required' unless $self->{rootFS} && $self->{heading};
}


sub getHtml
{
	my ($self, $page) = @_;

	my @activePath = $page->param('arl_pathItems');
	my $rootFS = $self->{rootFS};
	my $rootURL = $self->{rootURL} || ('/' . $page->param('arl_resource'));
	my $fileData = getActivePathContents($page, $self->{flags}, $rootFS, $rootURL, \@activePath);

	return createHtmlFromData($page, $self->{flags}, $fileData, $self->{publishDefn},
		{ activePath => getActivePathInfo($self->{flags}, $rootFS, $rootURL, \@activePath, 
			{ style => 'tree', rootCaption => $self->{rootCaption} }) 
		}
	);
}

1;
