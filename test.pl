#!/usr/bin/perl
use utf8;
use open qw( :encoding(utf8) :std );

use FindBin;                    
use lib $FindBin::Bin;  
use MyLogger;
MyLogger::file 'workIn.log';

MyLogger::level(1 , 1);

# MyLogger::file 'workIn.log';
INFO! "test de info";
 DEBUG! "le debug";
 WARN! "une alerte", " avec plusieurs param";
 ERROR! "une erreur";

my $pathRep = 'Test';

SYSTEM!("ls -l");
#SYSTEM!("rm -v Test/Orleans_20220107*");
SYSTEM!("ls -l Test");
