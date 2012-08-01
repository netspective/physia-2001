##############################################################################
package App::Dialog::Field::RovingResource;
##############################################################################

use strict;
use DBI::StatementManager;

use CGI::Validator::Field;
use CGI::Dialog;
use Schema::Utilities;
use vars qw(@ISA);

@ISA = qw(CGI::Dialog::Field);

sub new
{
	my ($type, %params) = @_;
	return CGI::Dialog::Field::new($type, %params);
}

sub getHtml
{
	my ($self, $page, $dialog, $command, $dlgFlags) = @_;
	my $javascript = qq{
		<SCRIPT>
			function setValue(field, rovingField, rovingNum, appendMode)
			{
				var newValue = '';

				if (rovingField.value.search(/^ /) == -1) {
					newValue = rovingField.value + '_' + rovingNum.value;
				}

				if (appendMode == 1) {
					if (newValue != '') {
						if (field.value) {
							field.value = field.value + ',' + newValue;
						} else {
							field.value = newValue;
						}
					}
				} else {
					field.value = newValue;
			 	}
			}
		</SCRIPT>
	};

	my $updatePhysician;
	if (my $field = $self->{physician_field})
	{
		$updatePhysician = "setValue(this.form.$field, this.form._f_roving_physician, this.form._f_roving_num, @{[$self->{appendMode} || 0]})";
	}

	my $html = $self->select_as_html($page, $dialog, $command, $dlgFlags);
	$html =~ s/_\(.*?\)//g;
	$html =~ s/select name/select onChange="$updatePhysician" name/;

	my $html2 = qq{
		<select name='_f_roving_num' size=1 onChange="$updatePhysician">
			<option value='1' >1</option>
			<option value='2' >2</option>
			<option value='3' >3</option>
			<option value='4' >4</option>
			<option value='5' >5</option>
		</select>
	};

	$html =~ s/<\/select>/<\/select> $html2/;

	return $javascript . $html;
}

1;
