use MyLogger ; #'DEBUG';
#use Filter::sh "tee " . __FILE__ . ".pl";
§package Univ;

§PARAM id;
§PARAM ftpRep;
§PARAM path;
§PARAM zipPrefix;
§PARAM prefix;
§PARAM dateFile;
§PARAM sepChar;
§PARAM filtreEtap;
§PARAM testEtap;
§PARAM lastPath;
§PARAM listFormationOk;

my %UNIVS;



# normalise les codes etapes d'orleans
# return true ssi son entré a été modifié 
sub orleansEtapEquiv {
	return $_[0] =~ s/^(\w{3})[^I]/$1I/;
}


sub new {
	my §NEW;
	my ($id, $ftpRep, $path, $filePrefix, $zipFilePrefix) = @_;

	unless ($zipFilePrefix) {
		$zipFilePrefix = $filePrefix;
	}
	
	§id = $id;
	§ftpRep = $ftpRep;
	§path = $path;
	§zipPrefix = $zipFilePrefix;
	§prefix = $filePrefix;
	§dateFile = '00000000';
	§sepChar = ',';
	§listFormationOk = {};

	if ($id eq "orleans") {
		my $fileFormationOk = "$path/$id".'FormationList';
		open my $FORMATION , $fileFormationOk or §WARN $fileFormationOk,": ", $! ;
		if ($FORMATION) {
			§DEBUG $fileFormationOk, " existe !"; 
			while (<$FORMATION>) {
				chop ;
				next if /^\s*(#.*)?$/;
				
				orleansEtapEquiv($_);
				§listFormationOk()->{$_}=1;
				#§DEBUG "add formtion $_";
			}
			§filtreEtap ( 
				sub {
					return map({ orleansEtapEquiv($_); §listFormationOk()->{$_} ? $_ : ()}  @_);
				} );
			§testEtap (
				sub {
					return !orleansEtapEquiv($_[0]) && §listFormationOk()->{$_[0]};
				}
			);
			close($FORMATION);
		} else {
			§DEBUG $fileFormationOk, " n'existe pas !"; 
			§filtreEtap ( 
			sub {
				return map({ orleansEtapEquiv($_); $_; }  @_);
			} );
			§testEtap (
				sub {
					return !orleansEtapEquiv($_[0]);
			});
		}
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
