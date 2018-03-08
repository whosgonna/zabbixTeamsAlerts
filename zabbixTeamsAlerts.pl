#!/usr/bin/env perl
use Modern::Perl;
use Getopt::Long;
use File::Basename;
use FindBin qw($Bin);
use Hash::Merge 'merge';
use Log::Log4perl;
use Config::Any;
use Pod::Usage;

use LWP::UserAgent;
use JSON;
use Zabbix::Tiny;

use Data::Printer;


### Bolierplate to setup loging.
my %opts;
GetOptions (
    "trigger=i" => \$opts{t},
    "conf=s"    => \$opts{c},
    "help"      => \$opts{h},
    "verbose:s" => \$opts{v},
);

# Get help contents from the POD
if ( $opts{h} ) {
    pod2usage({
        -verbose => 1,
        -exitval => -1,
        -noperldoc => 1,
        width => 132
    });
}

my $basename  = fileparse($0,'.pl');
my @confstems = (
	"$Bin/conf/$basename",
    "$Bin/conf/local_$basename",
);

my $conf_any = Config::Any->load_stems(
    {
        stems   => \@confstems,
        use_ext => 1,
    }
);


# If a config file was indicated on the commandline, add it now.
if ($opts{c}) {
    my $contents = Config::Any->load_files({
        files => $opts{c}, 
        use_ext => 1,
        flatten_to_hash => 1,
    });
    push ( @$conf_any, $contents );
}


# Merge the config files.
my $conf;
for (@$conf_any) {
    my ($filename, $sections) = %$_;
    $conf = merge($sections, $conf);
}

# Set up logging.
my $logdir   = $conf->{log}->{dir     } // "/$Bin/";
my $logname  = $conf->{log}->{name    } // "$basename.log";
my $logfile  = $opts{o} // $conf->{log}->{file    } // "/$logdir/$logname";
my $loglevel = $conf->{log}->{level   } // 'DEBUG';
my $appender = $conf->{log}->{appender} // 'File';
$appender    = 'File' if ( defined $opts{o} );

my @logger_list = ($loglevel, 'LOG1');
push (@logger_list, 'SCREEN') if ( defined $opts{v} );
my $logger_list = join( ', ' ,  @logger_list );
my $log_conf = qq(
    log4perl.rootLogger              = $logger_list
    log4perl.appender.LOG1           = Log::Log4perl::Appender::$appender
    log4perl.appender.LOG1.filename  = $logfile
    log4perl.appender.LOG1.mode      = append
    log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.LOG1.layout.ConversionPattern = %d{ISO8601} - %p %m %n
);

# If the -v option was passed, then also write the log to the console. By
# default this will be at the INFO level, however if
if (defined $opts{v}) {
    my $level = $opts{v} || 'INFO';
    $log_conf .= qq(
    log4perl.appender.SCREEN           = Log::Log4perl::Appender::Screen
    log4perl.appender.SCREEN.Threshold = $level
    log4perl.appender.SCREEN.stderr    = 0
    log4perl.appender.SCREEN.layout    = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.SCREEN.layout.ConversionPattern = %d{ISO8601} - %p %m %n
);
}

# Initialize the logger
Log::Log4perl::init( \$log_conf );
my $log = Log::Log4perl->get_logger();
$log->info("$basename has started");

#############  END BOILERPLATE ####################

unless (defined $opts{t}){
    my $warn = "No trigger ID declared (-t xxxxx). Exiting...";
    $log->info($warn);
    say "\n$warn\n";
    pod2usage({
        -verbose => 1,
        -exitval => -1,
        -noperldoc => 1,
        width => 132
    });
}
my $triggerid = $opts{t};

my $zabbix = Zabbix::Tiny->new($conf->{zabbix});

my $triggers = $zabbix->do(
    'trigger.get',
    output  => 'extend',
    expandExpression => 1,
    expandDescription => 1,
    expandComment => 1,
    selectHosts => [qw(hostid host name)],
    triggerids => $triggerid,
);
## trigger.get returns an array.  We only want the first element:
my $trigger = $triggers->[0];

my $problem      = $trigger->{value};
my $problem_text = "OK";
my $severity     = $trigger->{priority};

my $color = $conf->{alert_colors}->{ok};
if ( $problem ) {
    $color        = $conf->{alert_colors}->{$severity};
    $problem_text = "PROBLEM";
}

my @host_disp_names = map {$_->{name}  } @{ $trigger->{hosts} }; #->[0]->{name};
my $hosts_str = join ', ', @host_disp_names;


my $title = "$problem_text $hosts_str: $trigger->{description}";
my $text  = $trigger->{comments};

my $channel_url = $conf->{teams_channel_url};
my $ua = LWP::UserAgent->new;



my $msg = {
    title => $title,
    themeColor => $color,
    #correlationId => 'A947E42C-218E-11E8-8FFB-EC36E3E7E9F9',
    text => "<span style='color:#$color'>$text</span>",
    #sections => [
    #    {
    #        text  => 'Another test message',
    #        startGroup => 'true',        
    #    },
        #"potentialAction" => [{
        #    '@type' => "ActionCard",
        #    "id"    => "view",
        #    #'text'  => 'A big block\nof text\ncan go\nin here.',
        #}]
        #{
        #    title => 'Section 2',
        #    text  => 'Section 2 text',
        #    startGroup => 'true',
        #},
        #]
};

my $content = encode_json($msg);

my $req = HTTP::Request->new( 'POST', $channel_url );
$req->header( 'Content-Type' => 'application/json' );
$req->content( $content );

$ua->request( $req ); 






__END__

=head1 NAME

zabbixTeamsAlerts.pl

=head1 DESCRIPTION

Stream alerts to a Microsoft Teams channel

=head1 SYNOPSIS

zabbixTeamsAlerts.pl -t <trigger_id>


=cut

