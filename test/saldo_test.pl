#!/usr/bin/perl -w

use strict;
use lib "../lib";
use Finance::Bank::DE::SpardaBank;
use Data::Dumper;

my $account = Finance::Bank::DE::SpardaBank->new();
$account->connect();
$account->login();
print $account->saldo();
$account->logout();

print "\n";
