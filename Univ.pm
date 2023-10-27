use MyLogger;
#use Filter::sh "tee " . __FILE__ . ".pl";
package Univ;


PARAM! id;
PARAM! ftpRep;
PARAM! path;
PARAM! zipPrefix;
PARAM! prefix;
PARAM! dateFile;
PARAM! sepChar;
PARAM! filtreEtap;
PARAM! lastPath;

my %UNIVS;



sub new {
	my ($class, $id, $ftpRep, $path, $filePrefix, $zipFilePrefix) = @_;

	unless ($zipFilePrefix) {
		$zipFilePrefix = $filePrefix;
	}
	
	my $self = bless {}, $class;
	
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
				return map({ s/^(\S{3})\S/$1I/; $_; }  @_);
			} );
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
