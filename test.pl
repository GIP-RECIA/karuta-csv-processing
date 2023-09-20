#!/usr/bin/perl
use utf8;
use open qw( :encoding(utf8) :std );

use FindBin;                    
use lib $FindBin::Bin;  
use MyLogger;
use Dao;
MyLogger::file 'test.log';

#MyLogger::level(1 , 1);

# MyLogger::file 'workIn.log';
INFO! "test de info";
 DEBUG! "le debug";
 WARN! "une alerte", " avec plusieurs param";
# ERROR! "une erreur";

my $pathRep = 'Test';

SYSTEM!("ls -l");
#SYSTEM!("rm -v Test/Orleans_20220107*");
SYSTEM!("ls -l Test");

print "debut test dao \n";


my $dao = new Dao("test.db", "tours", "20230919");

$dao->addPerson('ETU', 'eppn1', 'Cunafo', 'Didier', 'didier.cunafo', '123');
$dao->addPerson('ETU', 'eppn1', 'Cunafo', 'Didier', 'didier.cunafo', '1234');
