use strict;
use utf8;
use Text::CSV; 
use open qw( :encoding(utf8) :std );

use Dao;
use Univ;
use Data::Dumper;
use MyLogger ; #'DEBUG';  #use Filter::sh "tee " . __FILE__ . ".pl";

package HaveFiles;

sub getFile {
	my $self = shift;
	my $type = shift;
	my $files = files! ;
	my $file = $$files{$type};
	return $file;
}

sub setFile {
	my $self = shift;
	my $file = shift;
	my $type = shift;
	my $files = files! ;
	
	$$files{$type} = $file;
}

package Etape;
use base qw(HaveFiles);

PARAM! code;
PARAM! univId;
PARAM! lib;
PARAM! site;
PARAM! cohorte;
PARAM! formation;
PARAM! files;

my %codeEtap2etap;

sub init {
	%codeEtap2etap = ();
}

sub byCode {
	my $codeEtap = shift;
	my $etap = shift;
	unless ($etap) {
		return $codeEtap2etap{$codeEtap};
	} 
	$codeEtap2etap{$codeEtap} = $etap;
}

#cohorte = $typeFormation_$sigleFormation_$parcoursFormation_$anneeFormation
#new cohorte = ${typeFormation}_*${sigleFormation}_*${parcoursFormation}_${anneeFormation}~~ (on applique le formatage défini) ~~ou~~
#new cohorte = ${libelleEtape}
#formation_code = $typeFormation_$sigleFormation
#new formation*code = ${formation*label}

#formation_label = $libelle_etape je me demande si on ne fera pas = formation_code
# new formation_label = ${typeFormation} ${sigleFormation} (attention à l'espace entre les deux variables)

sub new {
	my ($class, $univ, $codeEtap, $libEtap, $site, $cohorte, $codeFormation, $labelFormation, $formation) = @_;
	my $self;
	unless ($formation) {
		unless ($labelFormation) {
			$labelFormation = "";
		}
		($formation) = new Formation($univ, $codeFormation, $labelFormation, $site);
	}
	if ($formation) {
		
		$self = bless {}, $class;
		
		univId! = $univ;
		code! = $codeEtap;
		lib! = $libEtap;
		site! =  $site;
		cohorte! = $cohorte;
		formation! = $formation;
		files! = {};

		$formation->addEtapes($self);

		byCode($codeEtap,$self);
			
		return $self;
	}
	return 0;
}




sub create {
	# on peut ne pas creer l'etape (filtre par univ)
	# on creer aussi les formations correspondantes aux etapes.
	# my ($class, $codeEtap , $libEtap, $libCourt, $site) = @_;

	my ($class, $univ, $codeEtape, $libEtap, $codeSISE, $typeDiplome, $intituleDiplome, $site) = @_;
	my $cohorte;

	unless ($site) {
		ERROR! "Etape ($codeEtape) sans site\n";
		foreach my $elem (@_) {
		}
		return 0;
	}
	
	
	my $label = uc("${typeDiplome} ${intituleDiplome}");
	$label =~ s/\//-/;
	
	$cohorte = $libEtap;
	$cohorte =~ s/(\W|_)+/_/g;

		
	my $codeFormation = $label;
	$codeFormation =~ s/(\W|_)+/_/g;

	$site =~ s/\W+/-/g;

	
	$cohorte = $univ . '_'. $site . "_" . $cohorte;
	#$cohorte =  $site . "_" . $cohorte;

	
	
	my $self;
	
	if ($codeFormation =~ m/\w+/) {
		my $formation = create Formation($univ, $codeFormation, $label, $site);
		
		if ($formation) {
			my $testEtap = Univ->getById($univ)->testEtap;
			
			if (!$testEtap || &$testEtap($codeEtape)) {
				$self = byCode($codeEtape);
				unless ($self) {
					$self = new Etape ($univ, $codeEtape,  $libEtap,  $site, $cohorte, $codeFormation, $label, $formation);
					if ($self) {
						Dao->dao->addEtape($codeEtape, $libEtap, $codeFormation, $site, $cohorte);
					}
					return 1 ;
				}
				
			}
			#DEBUG! "codeFormation rejeté par testEtap ";
		} else {
			#DEBUG! "create Formation return 0";
		}
		return 0;
	} else {
		ERROR! " codeCormation ", $codeFormation;
		return 0;
	}
}


sub diffEtapFormation {
	my  $self = shift;
	my  $autre = shift;
	if ( code! eq $autre->code) {
		if ( formation!->formationCode eq $autre->formation->formationCode) {
			return 0;
		}
		return 1;
	}
	return -1;
}


package Formation;
use base qw(HaveFiles);
use Data::Dumper;
my %code2Formation;

my $csv = Text::CSV->new({ sep_char => ',', binary    => 1, auto_diag => 0, always_quote => 1 });

PARAM! formationCode;
PARAM! formationLabel;
PARAM! code;
PARAM! site;
PARAM! label;
PARAM! etapes;
PARAM! files;

sub new {
	my ($class, $univId, $code , $label, $site) = @_;
	
	my $formation = byCle($site, $code);

	if ($formation) {
		if ($label && $formation->label ne $label) {
				WARN! "formation ($site, $code) avec plusieurs label: $label ", $formation->label;
			}
		return ($formation, 0);
	}
	unless ($label) {
		WARN! "formation $code sans label";
		FATAL! "$univId, $code , $label, $site";
		return 0
	}
	
	my $self  = bless {} , $class;
	code! = $code;
	label!  = $label;
	etapes! = [];
	site! = $site;
	files! = {};
	formationCode! = $univId . '_' . $site. '_' . $code;
	formationLabel! = $univId . '_' . $site. ' - ' . $label;

	byCle($site, $code, $self);
	return ($self, 1);
}



sub create {
	my ($class, $univ, $code , $label, $site) = @_;
	my $formation;
	my $isNew = 0;
	if ($code =~ m/\S/) {

		($formation, $isNew) = new Formation($univ, $code , $label, $site);
		
	} else {
		WARN! ("Erreur codeForamation $code : $label");
		return 0;
	}
	
	Dao->dao->addFormation($code, $site, $label) if $isNew;

	return $formation;
}


# ATTENTION code donne une et une seule formation , mais une formation peut avoir plusieurs etapes.

sub init {
	%code2Formation = ();
	Etape::init();
}


#la cle est $site_$code
sub byCle {
	my $site = shift;
	my $code = shift;
	my $formation = shift;
	my $cle = "${site}_${code}";
	unless ($formation) {
		return $code2Formation{$cle};
	}
	return $code2Formation{$cle} = $formation;
}

sub readFile {
	my $path = shift;
	my $fileName = shift;
	my $univ = shift;
	my $sepChar = $univ->sepChar();

	init();

	
	my $fileNameLog = "${path}.log";

	open (FORMATION, "<$path/$fileName") || FATAL!  "$path/$fileName " . $! . "\n";
	binmode(FORMATION, ":encoding(utf8)");

	<FORMATION>; # 1er ligne : nom de colonne

	open (LOG, ">>$fileNameLog") || FATAL!  "$fileNameLog " . $!;
	
	my $nbline = 1;
	while (<FORMATION>) {
		$nbline++;
		s/\"\;\"/\"\,\"/g; #on force les ,
		s/(;|\s)+$//;
		if ($csv->parse($_) ){
			my @fields = $csv->fields();
			unless (create Etape($univ->id, @fields)){ #ERRROR
				WARN! "formation ligne $nbline : étape rejetée";
				print LOG "formation $nbline rejet : $_\n";
			}
		} else {
			WARN! "formation ligne  $nbline could not be parsed: $_";
			$csv->error_diag ();
			print LOG "formation ($nbline) rejet : $_\n";
		} 
	}
	close LOG;
}

sub writeFile {
	
	my $univ = shift;
	my $dateFile = shift;
	my $tmp = shift; #le repertoire temporaire de tavail
	
	my $file;
	my $path =  $univ->path;
	my $fileName = sprintf("%s_%s_%s.csv", $univ->id, 'FORMATIONS', $dateFile);

	
	my $fullFileName = $tmp . $fileName;

	INFO! "write $fullFileName";
	
	unless ( -d $tmp) {
		mkdir $tmp, 0775;
	}
	open ($file , "> $fullFileName") || FATAL!  "$fullFileName " . $!;
	
	$csv->print($file, ['formation_code', 'formation_label']);
	print $file "\n";

	foreach my $formation  (values %code2Formation) {
		my @info = ($formation->formationCode, $formation->formationLabel);
		Dao->dao->updateFormation($formation->code, $formation->site, @info);
		$csv->print($file, \@info );
		print $file "\n";
	}
	close $file;
	return $fileName;
}

sub addEtapes {
	my $self = shift;
	if (@_ > 0) {
		push @{etapes!}, @_;
	}
}









=begin

sub DESTROY{};

sub AUTOLOAD {
	our $AUTOLOAD; 
	my $self = shift;
	my $type = ref ($self);
	my $field = $AUTOLOAD;
	if ($type) {
		   # print "$field \n";
		$field =~ s/.*:://;
		if (exists $self->{$field}) {
			if (@_) {
				return $self->{$field} = shift;
			} else {
				return $self->{$field};
			}
		}
	}
	use Carp ();
	local $Carp::CarpLevel = 1;
   if ($type) {
	   Carp::croak ("$field does not exist in object/class $type");
   } else {
	   Carp::croak ("$field($self) is not an object");
   }
}

=cut

1;
