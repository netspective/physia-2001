##############################################################################
package App::Component::Navigate::FileSys;
##############################################################################

use strict;
use CGI::Layout;
use CGI::Component;
use File::Spec;
use App::Configuration;
use Data::Publish;
use Exporter;
use enum qw(BITMASK:NAVGPATHFLAG_ STAYATROOT);
use vars qw(@ISA @EXPORT %MODULE_FILE_MAP %FILE_MODULE_MAP %RESOURCE_MAP);
@ISA   = qw(Exporter CGI::Component);
@EXPORT = qw(NAVGPATHFLAG_STAYATROOT);

%MODULE_FILE_MAP = ();
%FILE_MODULE_MAP = ();

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

	my ($fsPath, $urlPath) = ($rootFS, $rootURL);
	if($style eq 'tree')
	{
		my @items = ();
		my $level = 0;
		if(my $caption = $styleOptions->{rootCaption})
		{
			push(@items, qq{ <IMG SRC='/resources/icons/folder-orange-open.gif'> <A HREF='$urlPath'>$caption</A>});
			$level = 1;
		}
		foreach (@$activePath)
		{
			$fsPath = File::Spec->catfile($fsPath, $_);
			last unless -d $fsPath;
			$urlPath .= '/' . $_;
			push(@items, qq{@{[ '&nbsp;&nbsp'x$level ]} <IMG SRC='/resources/icons/folder-orange-open.gif'> <A HREF='$urlPath'>$_</A>});
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
	my ($flags, $rootFS, $rootURL, $activePath, $style, $highlight) = @_;

	my ($fsPath, $urlPath) = ($rootFS, $rootURL . '/');
	unless($flags & NAVGPATHFLAG_STAYATROOT)
	{
		$fsPath = File::Spec->catfile($rootFS, ref $activePath eq 'ARRAY' ? @$activePath : $activePath);
		$urlPath = $rootURL . '/' . (ref $activePath eq 'ARRAY' ? join('/', @$activePath) : $activePath);
	}

	my @items = ();
	if(opendir(ACTIVEPATH, $fsPath))
	{
		my @dirs = ();
		my @files = ();
		grep
		{
			unless(m/^\./) # skip hidden files or subdirectories
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
			push(@items, ["$urlPath$_", $_, '/resources/icons/folder-orange-closed.gif']);
		}
		foreach (sort @files)
		{
			my $moduleFile = "$fsPath/$_";
			my $fileName = $_;
			require $moduleFile;
			open(MODFILE, $moduleFile) || return;
			while(<MODFILE>)
			{
				if (/^ *package +(\S+);/)
				{
					my $moduleName = $1;
					$FILE_MODULE_MAP{$moduleFile} = $moduleName;
					$MODULE_FILE_MAP{$moduleName} = $moduleFile;

					# get rid of extension
					$fileName =~ s/\..*$//;
					my $icon = $highlight eq $fileName ? '/resources/icons/arrow-double-cyan.gif' : '/resources/icons/report-yellow.gif';

					no strict 'refs';
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
			return getActivePathContents($flags, $rootFS, $rootURL, $activePath, $style, $highlight);
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
			borderColor => '#CCCCCC',
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
	my $fileData = getActivePathContents($self->{flags}, $rootFS, $rootURL, \@activePath);

	return createHtmlFromData($page, $self->{flags}, $fileData, $self->{publishDefn},
				{ activePath => getActivePathInfo($self->{flags}, $rootFS, $rootURL, \@activePath, { style => 'tree', rootCaption => $self->{rootCaption} }) }
				);
}

1;
