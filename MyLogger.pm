
#

package MyLogger;
use Filter::Simple;

FILTER {
	s/\sINFO\s/ MyLogger::info __FILE__,' (', __LINE__,'): ', /g;
	s/\sDEBUG\s/ MyLogger::debug __FILE__,' (', __LINE__,'): ', /g;
	s/\sWARN\s/ MyLogger::erreur 'WARN: ',  __FILE__,' (', __LINE__,'): ', /g;
	s/\sERROR\s/ MyLogger::erreur 'ERROR: ', __FILE__,' (', __LINE__,'): ', /g;
	s/\sFATAL\s/ MyLogger::fatal 'FATAL: die at ', __FILE__,' (', __LINE__,'): ', /g;
	s/\sTRACE\s/ MyLogger::trace /g; 
};

my $file;
my $mod;
sub file {
	if ($file) {
		close MyLoggerFile;
	}
	$file = shift;
	$file =~ s/^\>//;
	open (MyLoggerFile, ">$file" ) or die $file . " $!" ;
}

sub mod {
	$mod = shift;
}


sub trace {
	if ($file ) {
		print MyLoggerFile "\t", @_;
	};
	if ($mod & 2) {
		print "\t", @_;
	}
}

sub debug {
	if ($file ) {
		unshift (@_, lastname (shift));
		push @_, "\n";
		print MyLoggerFile dateHeure(), 'DEBUG: ', @_;
	}
	
	if ($mod & 2) {
		print 'DEBUG: ', @_;
	}
	
}

sub info {
	unshift (@_, lastname (shift));
	push @_, "\n";
	if ($file) {
		print MyLoggerFile dateHeure(), 'INFO: ', @_;
		if ($mod & 1) {
			print 'INFO ', @_;
		}
	} else {
		print 'INFO ', @_;
	}
}

sub erreur {
	my $type = shift;
	my $file = lastname(shift);
	
	push @_, "\n";
	if ($file) {
		print MyLoggerFile dateHeure(), $type, $file, @_; 
	}
	print STDERR  $type, $file, @_; 
}

sub fatal {
	erreur @_;
	close MyLoggerFile;
	exit 1;
}

sub dateHeure {
	my @local = localtime(time);
	return sprintf "%d/%02d/%02d %02d:%02d:%02d " , $local[5] + 1900,  $local[4]+1, $local[3], $local[2], $local[1], $local[0];
}


sub lastname {
	my $file = shift;
	$file =~ s/^.*\///g;
	return $file ;
}
1;
