use MyLogger;
#use Filter::sh "tee " . __FILE__ . ".pl";
package! Univ;


PARAM! id;
PARAM! ftpRep;
PARAM! path;
PARAM! zipPrefix;
PARAM! prefix;
PARAM! dateFile;
PARAM! sepChar;
PARAM! filtreEtap;
PARAM! testEtap;
PARAM! lastPath;

my %UNIVS;

# normalise les codes etapes d'orleans
# return true ssi son entré a été modifié 
sub orleansEtapEquiv {
	return $_[0] =~ s/^(\w{3})[^I]/$1I/;
}


sub new {
	my $self = NEW!;
	my ($id, $ftpRep, $path, $filePrefix, $zipFilePrefix) = @_;

	unless ($zipFilePrefix) {
		$zipFilePrefix = $filePrefix;
	}
	
	id! = $id;
	ftpRep! = $ftpRep;
	path! = $path;
	zipPrefix! = $zipFilePrefix;
	prefix! = $filePrefix;
	dateFile! = '00000000';
	sepChar! = ',';

	if ($id eq "orleans") {
		filtreEtap! ( 
			sub {
				return map({ orleansEtapEquiv($_); $_; }  @_);
			} );
		testEtap! (
			sub {
				return !orleansEtapEquiv($_[0]);
			}
		)
	} 
	
	$UNIVS{$id} = $self;

	return $self;
}

sub all {
	return values %UNIVS;
}

sub getById {
	my $class = shift;
	return $UNIVS{shift()};
}


1;
