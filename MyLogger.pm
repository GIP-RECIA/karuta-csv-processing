use IPC::Open3;
use IO::Select;
use Symbol 'gensym';

#

package MyLogger;
use Filter::Simple;

FILTER {
	s/INFO!/MyLogger::info __FILE__,' (', __LINE__,'): ',/g;
	s/DEBUG!/MyLogger::debug __FILE__,' (', __LINE__,'): ',/g;
	s/WARN!/MyLogger::erreur 'WARN: ',  __FILE__,' (', __LINE__,'): ',/g;
	s/ERROR!/MyLogger::erreur 'ERROR: ', __FILE__,' (', __LINE__,'): ',/g;
	s/FATAL!/MyLogger::fatal 'FATAL: die at ', __FILE__,' (', __LINE__,'): ',/g;
	s/TRACE!/MyLogger::trace/g;
	s/SYSTEM!/MyLogger::traceSystem/g;   
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
sub traceSystem {
	my $commande = shift;
	my $COM;
	my $ERR = Symbol::gensym();
	my $select = new IO::Select;

	my $pid;
	eval {
	  $pid = IPC::Open3::open3(undef, $COM, $ERR, $commande);
	};
	die $@ if $@;
	
	$select->add($COM, $ERR);

	my $flagC = 1;
	my $flagE =1;
	while (my @ready = $select->can_read) {
		foreach my $fh (@ready) {
			my $line;
			my $len = sysread $fh, $line, 4096;
			if ($len == 0){
				$select->remove($fh);
			} else {
				$line =~ s/\n(.)/\n\t\1/mg;
				if ($fh == $COM) {
					if ($flagC) {
						debug (' system ', $commande);
						$flagC = 0;
						$flagE = 1;
					}
					trace($line);
				} elsif ($fh == $ERR) {
					if ($flagE) {
						erreur ( 'ERROR',  ' system ', $commande);
						$flagC = 1;
						$flagE = 0;
					}
					trace($line) ;
				}
			}
		}
	}
	waitpid $pid, 0;
	close $ERR;
	close $COM;
}
1;
