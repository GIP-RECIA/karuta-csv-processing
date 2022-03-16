use strict;
use utf8;
use Text::CSV; # sudo apt-get install libtext-csv-perl
use open qw( :encoding(utf8) :std );
use MyLogger;

package Formation;

my $csv = Text::CSV->new({ sep_char => ',', binary    => 1, auto_diag => 0});
my %code2Formation;


sub get {
	my $code = shift;
	return $code2Formation{$code};
}

sub readFile {
	my $path = shift;
	my $fileName = shift;
	my $sepChar = shift;

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
			unless (new Formation($csv->fields())){
				#WARN! "formation ligne $nbline : create object error !";
				print LOG "formation $nbline rejet : $_\n";
			}
		} else {
			WARN! "formation ligne  $nbline could not be parsed: $_";
			print LOG "formation ($nbline) rejet : $_\n";
		} 
	}
	close LOG;
}

sub new {
	my ($class, $codeEtap , $libEtap, $libCourt) = @_;
	if ($libCourt) {
		$libCourt =~ s/(\W|_)+/_/g;

	} else {
		$libCourt = $codeEtap;
	}
	my $self;
	if ($libEtap =~ m/^(\S+)\s.+$/) {
		$self = {
			code => $codeEtap,
			lib => $libEtap,
			diplome => $1,
			court => $libCourt,
			files => {}
		};
	} else {
		$self = {
			code => $codeEtap,
			lib => $libEtap,
			diplome => $libEtap,
			court => $libCourt,
			files => {}
		};
		WARN! ("$codeEtap erreur libEtape : $libEtap");
		return 0;
	}
	bless $self, $class;
	$code2Formation{$self->{code}} = $self;
	return $self;
}
sub code {
	my $self = shift;
	return $self->{code};
}
sub diplome {
	my $self = shift;
	return $self->{diplome};
}

sub lib {
	my $self = shift;
	return $self->{lib};
}

sub court {
	my $self = shift;
	return $self->{court};
}

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
