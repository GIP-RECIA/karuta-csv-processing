use strict;
use utf8;
use Text::CSV; 
use open qw( :encoding(utf8) :std );
use MyLogger;
use Dao;


package HaveFiles;

sub getFile {
	my $self = shift;
	my $type = shift;
	my $files = $self->{files};
	my $file = $$files{$type};
	return $file;
}

sub setFile {
	my $self = shift;
	my $file = shift;
	my $type = shift;
	my $files = $self->{files};
	
	$$files{$type} = $file;
}




package Etape;
use base qw(HaveFiles);

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
		$formation = new Formation($univ, $codeFormation, $labelFormation, $site);
	}
	if ($formation) {
		
		$self = {
			etap => $codeEtap,
			lib => $libEtap,
			site => $site,
			cohorte => $cohorte,
			formation => $formation,
			files => {}
		};

		bless $self, $class;

		$formation->etapes($self);

		byCode($codeEtap,$self);
			
		return $self;
	}
	return 0;
}

sub create {
	# Attention on peut créer plusieurs etap on renvoie donc le nombre d'étap créés
	# on creer aussi les formations correspondantes aux etapes.
	# my ($class, $codeEtap , $libEtap, $libCourt, $site) = @_;

	my ($class, $univ, $codesEtaps, $libEtap, $codeSISE, $typeDiplome, $intituleDiplome, $site) = @_;
	
	my $cohorte;

	unless ($site) {
		ERROR! "Etape ($codesEtaps) sans site\n";
		foreach my $elem (@_) {
			DEBUG! "newEtap:  $elem";
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
	
	my $self;
	
	if ($codeFormation =~ m/\w+/) {
		
		my $formation = create Formation($univ, $codeFormation, $label, $site);
		
		if ($formation) {
			my $nbEtap = 0;
			foreach my $codeEtap (split('@',$codesEtaps)) {
				$self = byCode($codeEtap);
				unless ($self) {
					$self = new Etape ($univ, $codeEtap,  $libEtap,  $site, $cohorte, $codeFormation, $label, $formation);
					if ($self) {
						Dao->dao->addEtape($codeEtap, $libEtap, $codeFormation, $site, $cohorte);
					}
				}

				$nbEtap++;
			}
			return $nbEtap;
		}
		return 0;
	} else {
		ERROR! " codeCormation ", $codeFormation;
		return 0;
	}
}

sub site {
	my $self = shift;
	return $self->{site};
}
sub lib {
	my $self = shift;
	return $self->{lib};
}
sub cohorte {
	my  $self = shift;
	return $self->{cohorte}
}
sub formation {
	my  $self = shift;
	return $self->{formation}
}


package Formation;
use base qw(HaveFiles);

my %code2Formation;

my $csv = Text::CSV->new({ sep_char => ',', binary    => 1, auto_diag => 0, always_quote => 1 });

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
	if ($formation) {
		return $code2Formation{$cle};
	}
	$code2Formation{$cle} = $formation;
}

sub readFile {
	my $path = shift;
	my $fileName = shift;
	my $univ = shift;
	my $sepChar = $univ->sepChar();

	init();

	
	my $fileNameLog = "${path}.log";
	DEBUG! "open  $path/$fileName \n";

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
			unless (create Etape($univ->id, @fields)){
				WARN! "formation ligne $nbline : create object error !";
				foreach my $elem (@fields) {
					INFO! $elem;
				}
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
		Dao->dao->updateFormation($formation->code(), $formation->site(), @info);
		$csv->print($file, \@info );
		print $file "\n";
	}
	close $file;
	return $fileName;
}

sub new {
	my ($class, $univId, $code , $label, $site) = @_;
	
	my $formation = byCle($site, $code);

	if ($formation) {
		if ($label && $formation->label ne $label) {
				WARN! "formation ($site, $code) avec plusieurs label: $label ", $formation->label;
			}
		return $formation;
	}
	unless ($label) {
		WARN! "formation $formation sans label";
		return 0
	}
	
	$formation = {
		CODE => $code,
		LABEL => $label,
		etapes => [],
		SITE => $site,
		files => {},
		FORMATIONCODE => $univId . '_' . $site. '_' . $code,
		FORMATIONLABEL => $univId . '_' . $site. ' - ' . $label,
	};

	bless $formation, $class;
	byCle($site, $code, $formation);

	return $formation;
}

PARAM! formationCode;
PARAM! formationLabel;
PARAM! code;
PARAM! site;
PARAM! label;

sub create {
	my ($class, $univ, $code , $label, $site) = @_;

	my $formation;
	if ($code =~ m/\S/) {

		$formation = new Formation($class, $univ, $code , $label, $site);
		
	} else {
		WARN! ("Erreur codeForamation $code : $label");
		return 0;
	}
	
	Dao->dao->addFormation($code, $site, $label);

	return $formation;
}

sub etapes {
	my $self = shift;
	if (@_ > 0) {
		push @{$self->{etapes}}, @_;
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
