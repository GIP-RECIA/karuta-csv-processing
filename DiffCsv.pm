#!/usr/bin/perl
use strict;
use utf8;
use open qw( :encoding(utf8) :std );

#use FindBin;                    
#use lib $FindBin::Bin;  

use MyLogger;

package DiffCsv;

sub sort {
	my $file = shift;
	my $enteteSize = shift;

	my @entete ;
	my @data;
	rename ($file, "$file.org") || FATAL! "mv $file, $file.org " . $!;
	open (OUT , ">$file")  || FATAL! "write $file " . $!;  
	open (IN , "$file.org") || FATAL! "$file " .$!;
	my $lineNo = 0;
	while (<IN>) {
		if ($lineNo++ < $enteteSize) {
			push (@entete , $_);
		} else {
			push (@data, $_);
		}
	}
	close IN;

	map({print (OUT $_);} @entete );
	map({print (OUT $_);} sort(@data) );
	close OUT;
	
}

1;
