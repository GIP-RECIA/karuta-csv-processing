#!/usr/bin/perl
use utf8;
use open qw( :encoding(utf8) :std );

use FindBin;                    
use lib $FindBin::Bin;  

use formation;
use traitementCsv;


Formation::readFile("Test/univ-tours/univ-tours_2021-12-07_formations.csv");

Traitement::parseFile('ETU', 'tours', "Test/univ-tours", "univ-tours_2021-12-07_ETU.csv", '2021-12-07', '2021');
Traitement::parseFile('STAFF', 'tours', "Test/univ-tours", "univ-tours_2021-12-07_STAFF.csv", '2021-12-07', '2021');
