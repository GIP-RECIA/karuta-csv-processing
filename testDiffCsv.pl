#!/usr/bin/perl
use strict;
use utf8;
use open qw( :encoding(utf8) :std );

use FindBin;                    
use lib $FindBin::Bin;  

use MyLogger;

use DiffCsv;


DiffCsv::sort ('tours_ETU_IUT TOURS_BUT_Tech_de_co_prc_SME_2A_2022_20221006.csv', 3);
