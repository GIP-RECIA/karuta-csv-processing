use strict;
use utf8;
use Text::CSV; # sudo apt-get install libtext-csv-perl
use open qw( :encoding(utf8) :std );
use MyLogger;


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

sub new {
	my ($class, $codeEtap , $libEtap, $libCourt, $site) = @_;
	my $cohorte;

	DEBUG!  "$codeEtap , $libEtap, $libCourt, $site";
	
	if ($libCourt) {
		$cohorte = $libCourt;
	} else {
		$cohorte = $codeEtap;
	}

	$cohorte =~ s/(\W|_)+/_/g;
	my $codeFormation = uc($cohorte);
	$codeFormation =~ s/_\d+_/_/g;
	$codeFormation =~ s/_+/_/g;
	$codeFormation =~ s/_\d+$//;

	my $label = uc($libEtap) ;
	$label =~ s/((ANNÉE\s\d+$)|\d|\s)+/ /g;
    $label =~ s/\s+$//;

	
	my $self;
	
	if ($codeFormation =~ m/\w+/) {

		my $formation = new  Formation($codeFormation, $label);

		if ($formation) {
			DEBUG! "Create etape : $codeEtap, $libEtap, $libCourt, $site, $cohorte ";
			$self = {
				etap => $codeEtap,
				lib => $libEtap,
				court => $libCourt,
				site => $site,
				cohorte => $cohorte,
				formation => $formation,
				files => {}
			};

			bless $self, $class;

			$formation->etapes($self);

			$codeEtap2etap{$codeEtap} = $self;
			
			return $self;
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

my $csv = Text::CSV->new({ sep_char => ',', binary    => 1, auto_diag => 0});

# ATTENTION code donne une et une seule formation , mais une formation paut avoir plusieurs etapes.

sub init{
	%code2Formation = ();
	Etape::init();
}


sub getByCode {
	my $code = shift;
	return $code2Formation{$code};
}

sub readFile {
	my $path = shift;
	my $fileName = shift;
	my $sepChar = shift;

	init();

	
	my $fileNameLog = "${path}.log";
	DEBUG! "open  $path/$fileName \n";

	open (FORMATION, "<$path/$fileName") || FATAL!  "$path/$fileName " . $! . "\n";
	<FORMATION>; # 1er ligne : nom de colonne

	open (LOG, ">>$fileNameLog") || FATAL!  "$fileNameLog " . $!;
	
	#$csv->sep_char($sepChar);
	my $nbline = 1;
	while (<FORMATION>) {
		$nbline++;
		s/\"\;\"/\"\,\"/g; #on force les ,
		if ($csv->parse($_) ){
			unless (new Etape($csv->fields())){
				WARN! "formation ligne $nbline : create object error !";
				print LOG "formation $nbline rejet : $_\n";
			}
		} else {
			WARN! "formation ligne  $nbline could not be parsed: $_";
			print LOG "formation ($nbline) rejet : $_\n";
		} 
	}
	close LOG;
}

sub writeFile {
	
	my $univ = shift;
	my $dateFile = shift;
	
	my $file;
	my $path =  $univ->path;
	my $fileName = sprintf("%s_%s_%s.csv", $univ->id, 'FORMATIONS', $dateFile);

	my $tmp = "${path}_tmp/";
	$fileName = $tmp . $fileName;

	INFO! "write $fileName";
	unless ( -d $tmp) {
		mkdir $tmp, 0775;
	}
	open ($file , "> $fileName") || FATAL!  "$fileName " . $!;
	
	$csv->print($file, ['formation', 'formation_label']);
	print $file "\n";

	foreach my $formation  (values %code2Formation) {
		my @info = ($univ->id() . '_' . $formation->code(), $univ->id() . ' - ' . $formation->label );
		$csv->print($file, \@info );
		print $file "\n";
	}
	close $file;
}

sub new {
	my ($class, $code , $label) = @_;

	my $formation = getByCode($code);
	if ($formation) {
		if ($formation->label ne $label) {
				WARN! "formation ($code) avec plusieurs label: $label ", $formation->label;
			}
		return $formation;
	} 

	if ($code =~ m/\S/) {
		# on peut rencontrer plusieurs fois la même formation avec des codes etape differents
		$formation = {
			code => $code,
			label => $label,
			etapes => [],
			files => {}
		};
		
	} else {
		WARN! ("Erreur codeForamation $code : $label");
		return 0;
	}
	bless $formation, $class;
	$code2Formation{$code} = $formation;

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
