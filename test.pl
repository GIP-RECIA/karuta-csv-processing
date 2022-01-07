#!/usr/bin/perl
use utf8;
use open qw( :encoding(utf8) :std );

use FindBin;                    
use lib $FindBin::Bin;  

use univ;
use formation;
use traitementCsv;

my $univ = new Univ('tours', 'Test' , 'univ-tours'); 

Formation::readFile("Test/univ-tours/univ-tours_2021-12-07_formations.csv");

Traitement::parseFile('ETU', $univ ,  '2021-12-07', '2021');
Traitement::parseFile('STAFF', $univ ,  '2021-12-07', '2021');
