# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'Finance::Bank::DE::SpardaBank' ); }

my $object = Finance::Bank::DE::SpardaBank->new ();
isa_ok ($object, 'Finance::Bank::DE::SpardaBank');


