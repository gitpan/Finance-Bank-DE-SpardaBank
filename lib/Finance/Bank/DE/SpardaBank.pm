package Finance::Bank::DE::SpardaBank;

use strict;
use vars qw($VERSION);
use base qw(Class::Accessor);
Finance::Bank::DE::SpardaBank->mk_accessors(qw(BASE_URL BLZ CUSTOMER_ID PASSWORD AGENT_TYPE AGENT ACCOUNT));
use WWW::Mechanize;
use HTML::TreeBuilder;
use Text::CSV_XS;
use Encode;

$|++;

$VERSION = "0.04";

sub Version { 
    return $VERSION;
}

sub new {
    my $proto  = shift;
    my %values = (
		  BASE_URL => "https://www.bankingonline.de/sparda-banking/view/",
		  BLZ => "70090500",         # Sparda Bank Muenchen
		  CUSTOMER_ID => "demo",     # Demo Login
		  PASSWORD => "",            # Demo does not require a password
		  ACCOUNT => "2777770",      # Demo Account Number (Kontonummer)
		  AGENT_TYPE => "Internet Explorer 6",
		  , @_);

    if ($values{'CUSTOMER_ID'} ne "demo" && $values{'ACCOUNT'} eq "2777770") {
	$values{'ACCOUNT'} = $values{'CUSTOMER_ID'};
    }

    my $class  = ref($proto) || $proto;
    my $parent = ref($proto) && $proto;

    my $self = {};
    bless($self, $class);

    foreach my $key (keys %values) {
	$self->$key("$values{$key}");
    }
    return $self;
}


sub connect {
    my $self = shift;
    my $url = $self->BASE_URL() . "index.jsp?blz=" . $self->BLZ();
    my $agent = WWW::Mechanize->new(
				    agent => $self->AGENT_TYPE(),
				    );
    $agent->get($url);
    $self->AGENT($agent);
}


sub login {
    my $self = shift;
    my %values = (
                  CUSTOMER_ID => $self->CUSTOMER_ID(),
                  PASSWORD => $self->PASSWORD(),
    		  , @_);
    
    my $agent = $self->AGENT();
    $agent->field("kundennummer", $values{'CUSTOMER_ID'});
    $agent->field("pin", $values{'PASSWORD'});
    $agent->click();
}


sub saldo {
    my $self = shift;
    my %values = (
		  ACCOUNT => $self->ACCOUNT(),
		  , @_);

    my $agent = $self->AGENT();
    my $content = $agent->content();
    my $tree = HTML::TreeBuilder->new();
    my $saldo;

    $tree->parse($content);
 
    my @input = $tree->find_by_tag_name('tr');
    my @kids;

    foreach my $node (@input) {
	@kids = $node->content_list();
	if ($node->attr('class') && $node->attr('class') =~ m/fieldbackground/i) {
	    $kids[2]->as_text =~ m/(\d+,\d{2})/ig;
	    $saldo = $1;
	    $saldo =~ tr/,/\./;
	}
    }
    $tree->delete();
    return $saldo;
}


sub statement {
    my $self = shift;
    my %values = (
                  TIMEFRAME => "30", # 1 or 30 days || "alle" = ALL || "variabel" = between START_DATE and END_DATE only
		  START_DATE => 0,   # dd.mm.yyyy
		  END_DATE => 0,     # dd.mm.yyyy
		  ACCOUNT => $self->ACCOUNT(),
		  , @_);

    my $agent = $self->AGENT();

    binmode(STDOUT, ":encoding(iso-8859-15)");

    $agent->field("kontonummer", $values{'ACCOUNT'});
    $agent->field("zeitraum", $values{'TIMEFRAME'});

    if ($values{'TIMEFRAME'} eq "variabel" && $values{'START_DATE'} && $values{'END_DATE'}) {
		$agent->field("startdatum", $values{'START_DATE'});
		$agent->field("enddatum", $values{'END_DATE'});
    }

    $agent->click();
    $agent->get($self->BASE_URL() . "/umsatzdownload.do");
    my $content = $agent->content();
    my $csv_content = $self->_parse_csv($content);
    return $csv_content;
}


sub logout {
    my $self = shift;
    my $agent = $self->AGENT();
    my $url = $self->BASE_URL();
    $agent->get($url . "logout.do");
}


sub _parse_csv {
    my $self = shift;
    my $csv_content = shift;
    $csv_content =~ s/\r//gmi;
    $csv_content =~ s/\f//gmi;
    my @lines = split("\n",$csv_content);
    my %data;

    my $csv = Text::CSV_XS->new({
	sep_char => "\t",
	binary => 1, ### german umlauts...
	});
    
    my $line_count = 0;

    foreach my $line (@lines) {
	my $status = $csv->parse($line);
	my @columns = $csv->fields();
	$line_count++;

	### Account Details ########################
	
	if ($line_count > 3 && $line_count < 6) {
	    $columns[0] =~ s/://;
	    $data{"ACCOUNT"}{uc($columns[0])} = $columns[1];
	}

	### Statement Details ######################

	if ($line_count == 9) {
            $data{"STATEMENT"}{"START_DATE"} = $columns[0];
	    $data{"STATEMENT"}{"END_DATE"}   = $columns[1];
	    $data{"STATEMENT"}{"ACCOUNT_ID"} = $columns[2];
	    $data{"STATEMENT"}{"SALDO"}      = $columns[3];
	    $data{"STATEMENT"}{"WAEHRUNG"}   = $columns[4];
        }

	### Transactions ###########################

	if ($line_count > 12 && $line_count <= $#lines) {
	    my $row = $line_count - 12;
	    $data{"TRANSACTION"}[$row]{"BUCHUNGSTAG"} = $columns[0];
	    $data{"TRANSACTION"}[$row]{"WERTSTELLUNGSTAG"} = $columns[1];
	    $data{"TRANSACTION"}[$row]{"VERWENDUNGSZWECK"} = $columns[2];
	    $data{"TRANSACTION"}[$row]{"UMSATZ"} = $columns[3];
	    $data{"TRANSACTION"}[$row]{"WAEHRUNG"} = $columns[4];
	    $data{"TRANSACTION"}[$row]{"NOT_YET_FINISHED"} = $columns[5] if 
		( defined($columns[5]) && $columns[5] =~ m/^[^\s]$/ig );
	}
    }
    
    return \%data;
}



1;
__END__
# Below is the stub of documentation for your module. You better edit it!


=head1 NAME

Finance::Bank::DE::SpardaBank - Check your SpardaBank Bank Accounts with Perl

=head1 SYNOPSIS

 use Finance::Bank::DE::SpardaBank;
 my $account = Finance::Bank::DE::SpardaBank->new(
						 CUSTOMER_ID => "12345678",
						 ACCOUNT_ID => "12345678",
						 PASSWORD => "ROUTE66",
                                                 BLZ => "70090500",
                                                 );
 $account->connect(); 
 $account->login();
 print $account->saldo();
 $account->logout();

=head1 DESCRIPTION


This module provides a very limited interface to the webbased online banking
interface of the German "SpardaBank e.G." operated by Sparda-Datenverarbeitung e.G..
It will only work with German SpardaBank accounts - e.g. the Austrian Sparda Bank 
Accounts will not work.

It uses OOD and doesn't export anything.

B<WARNING!> This module is neither offical nor is it tested to be 100% save! 
Because of the nature of web-robots, B<everything may break from one day to
the other> when the underlaying web interface changes.

This is code for B<online banking>, and that means B<your money>, and
that means B<BE CAREFUL>. You are encouraged, nay, expected, to audit
the source of this module yourself to reassure yourself that I am not
doing anything untoward with your banking data. This software is useful
to me, but is provided under B<NO GUARANTEE>, explicit or implied.

=head1 METHODS

=head2 new(%values) 

This constructor will set the default values and/or user provided values for
connection and authentication.

    my $account = Finance::Bank::DE::SpardaBank->new (
                  BASE_URL => "https://www.bankingonline.de/sparda-banking/view/",
                  BLZ => "70090500",        
                  CUSTOMER_ID => "demo",    
                  PASSWORD => "",      
                  ACCOUNT => "2777770",   
                  AGENT_TYPE => "Internet Explorer 6",
	      , @_);

If you don't provide any values the module will automatically use the demo account.

CUSTOMER_ID is your "Kundennummer" and ACCOUNT is the "Kontonummer" 
(if you have only one account you can skip that)

=head2 connect()

This method will create the user agent and connect to the online banking website.
Also this (done by WWW::Mechanize) automagically handles the session-id handling.

    $account->connect();



=head2 login(%values)

This method will try to log in with the provided authentication details. If
nothing is specified the values from the constructor or the defaults will be used.

    $account->login(ACCOUNT => "1234");

=head2 saldo(%values)

This method will return the current account balance called "Saldo".
The method uses the account number if previously set. 

You can override/set it:

    $account->saldo(ACCOUNT => "5555555");


=head2 statement(%values)

This method will retrieve an account statement (Kontoauszug) and return a hashref.

You can specify the timeframe of the statement by passing different arguments:
The value of TIMEFRAME can be "1" (last day only), "30" (last 30 days only), "alle" (all possible) or "variable" (between
START_DATE and END_DATE only).

    $account->statement(
                                 TIMEFRAME => "variabel",
                                 START_DATE => "10.04.2003",
                                 END_DATE => "02.05.2003",
			    );

=head2 logout()

This method will just log out the website and it only exists to keep the module logic clean ;-)

=head1 USAGE

 use Finance::Bank::DE::SpardaBank;
 use Data::Dumper;

 my $account = Finance::Bank::DE::SpardaBank->new(
                                                 BLZ => "70090500",
                                                 CUSTOMER_ID => "xxxxxxx",
                                                 ACCOUNT => "yyyyyyy",
                                                 PASSWORD => "zzzzzz",
                                                 );
 $account->connect();
 $account->login();
 print Dumper($account->statement(
                                 TIMEFRAME => "variabel",
                                 START_DATE => "10.04.2003",
                                 END_DATE => "02.05.2003",
 				 )
             );
 $account->logout();


=head1 BUGS

Please report bugs via 
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Finance-Bank-DE-SpardaBank>

=head1 SUPPORT

Support currently available via eMail to the author.

=head1 HISTORY

0.04 Mon May 27 15:00:00 2003
        - another try to fix POD :-)

0.03 Sun May 04 15:30:01 2003
        - Documentation fixes (thanks castrox :-))
        - Usability enhancements

0.02 Sat May 03 16:30:00 2003
        - first public CPAN release

0.01 Sat Apr 19 02:22:15 2003
        - original version;

=head1 CREDITS

 Thomas Eibner 
 Casey West
 Andy Lester for WWW::Mechanize

 ... and all the people I forgot to mention :-)

=head1 AUTHOR

 Roland Moriz
 rmoriz at cpan dot org / roland at moriz dot de
 http://www.roland-moriz.de/

=begin HTML
<form action="https://www.paypal.com/cgi-bin/webscr" method="post">
<input type="hidden" name="cmd" value="_xclick">
<input type="hidden" name="business" value="roland@moriz.de">
<input type="hidden" name="item_name" value="Roland Moriz's Open Source Activities">
<input type="hidden" name="no_note" value="1">
<input type="hidden" name="currency_code" value="EUR">
<input type="hidden" name="tax" value="0">
<input type="image" src="https://www.paypal.com/images/x-click-but21.gif" border="0" name="submit" alt="Make payments with PayPal - it's fast, free and secure!">

=end HTML

Disclaimer stolen from Simon Cozens' Finance::Bank::LloydsTSB without asking for permission %-)


=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

Finance::Bank::DE::NetBank, WWW::Mechanize, Finance::Bank::LloydsTSB

=cut



