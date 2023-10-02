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

sub getByCodeEtap {
	my $codeEtap = shift;
	return $codeEtap2etap{$codeEtap};
}

#cohorte = $typeFormation_$sigleFormation_$parcoursFormation_$anneeFormation
#new cohorte = ${typeFormation}_*${sigleFormation}_*${parcoursFormation}_${anneeFormation}~~ (on applique le formatage défini) ~~ou~~
#new cohorte = ${libelleEtape}
#formation_code = $typeFormation_$sigleFormation
#new formation*code = ${formation*label}

#formation_label = $libelle_etape je me demande si on ne fera pas = formation_code
# new formation_label = ${typeFormation} ${sigleFormation} (attention à l'espace entre les deux variables)

sub new {
	# Attention on peut créer plusieurs etap on renvoie donc le nombre d'étap créés
	# on creer aussi les formations correspondantes aux etapes.
	# my ($class, $codeEtap , $libEtap, $libCourt, $site) = @_;

	my ($class, $codesEtaps, $libEtap, $codeSISE, $typeDiplome, $intituleDiplome, $site) = @_;
	
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


	
	my $self;
	
	if ($codeFormation =~ m/\w+/) {

		my $formation = new  Formation($codeFormation, $label, $site);

		if ($formation) {
			my $nbEtap = 0;
			foreach my $codeEtap (split('@',$codesEtaps)) {
				$self = {
					etap => $codeEtap,
					lib => $libEtap,
					site => $site,
					cohorte => $cohorte,
					formation => $formation,
					files => {}
				};

				bless $self, $class;

				Dao->dao->addEtape($codeEtap, $libEtap, $formation, $site );
				$formation->etapes($self);

				$codeEtap2etap{$codeEtap} = $self;
				$nbEtap++;
			}
			return $nbEtap;
		}
		return 0;
	} else {
		ERROR! " codeFormation ", $codeFormation;
		return 0;
	}
}

sub site {
	my $self = shift;
	return $self->{site};
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
sub getByCle {
	my $cle = shift;
	return $code2Formation{$cle};
}

sub readFile {
	my $path = shift;
	my $fileName = shift;
	my $sepChar = shift;

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
			unless (new Etape(@fields)){
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
		my @info = ($univ->id() . '_' . $formation->site(). '_' . $formation->code(), $univ->id() .'_' . $formation->site(). ' - ' . $formation->label );
		$csv->print($file, \@info );
		print $file "\n";
	}
	close $file;
	return $fileName;
}

sub new {
	my ($class, $code , $label, $site) = @_;

	my $cle="${site}_${code}";
	my $formation = getByCle($cle);
	if ($formation) {
		if ($formation->label ne $label) {
				WARN! "formation ($cle) avec plusieurs label: $label ", $formation->label;
			}
		return $formation;
	} 
	
	if ($code =~ m/\S/) {
		# on peut rencontrer plusieurs fois la même formation avec des codes etape differents
		$formation = {
			code => $code,
			label => $label,
			etapes => [],
			site => $site,
			files => {}
		};
		
	} else {
		WARN! ("Erreur codeForamation $code : $label");
		return 0;
	}

	Dao->dao->addFormation($code, $site, $label);
	
	bless $formation, $class;
	$code2Formation{$cle} = $formation;

	return $formation;
}

sub etapes {
	my $self = shift;
	if (@_ > 0) {
		push @{$self->{etapes}}, @_;
	}
}



sub code {
	my $self = shift;
	return $self->{code};
}

sub site {
	my $self = shift;
	return $self->{site};
}
sub label {
	my $self = shift;
	return $self->{label};
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
