use ExtUtils::MakeMaker;

my $have_io_socket_ssl = eval { require IO::Socket::SSL; 1 };

WriteMakefile(
    NAME         => 'Finance::Bank::DE::SpardaBank',
    VERSION_FROM => 'lib/Finance/Bank/DE/SpardaBank.pm', # finds $VERSION
    ABSTRACT     => 'Check your SpardaBank Bank Accounts with Perl',
  
    PREREQ_PM    => {	
	"WWW::Mechanize" => "0.43",
	"Class::Accessor" => 0,
	"HTML::TreeBuilder" => 0,
	"Text::CSV_XS" => 0,
	"base" => 0,
	$have_io_socket_ssl ? () : (
				    'Crypt::SSLeay'=> 0,
				    ),
	},	      

    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/Finance/Bank/DE/SpardaBank.pm', # retrieve abstract from module
       AUTHOR        => 'Roland Moriz (rmoriz@cpan.org)') : ()),
	      

);
