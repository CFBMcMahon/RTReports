=pod

=head1 FEATURE REQUESTS

=item ntickets

specify the number of tickets to be listed. This value would override the value in the config file.

=item $ioa 

variabile should not be hardwired since this is too specific to current project


=item 

need to review the name of this program e.g. RTLastContact would be
a possibility

=item

Joint review of the documentation to clarify text

=head1 RTtoldspan

RTtoldspan - Produces creates a summary report written to 
a text file of the contact time  with the requestor for each
different ticket owner. The default text file has a datestamp
in the filename.

Include name of file as a command line argument if you desire a 
different filename to be used.  This is useful if you want different 
queries to be made without each report overwriting the previous on 
that day or if you just want more informative file names. 

Please be aware that if no path/folder is provided, the output path/folder 
will be created in the current working directory.

=head1 SYNOPSIS

Options:

-h --h -help    --help brief help message listing these options

-m --m -man     --man full documentation based on all pod material

-v --v -verbose --verbose Prints certain details to screen for debugging

--q                enables 'IOA' to be used as a queue limiter for query building. Has priority over config file queue variable.

        --queue    (deprecated) Give a string to be used as queue in query building

         --f       Do not create a folder for report

         --d       Use database as basis for owner names

A configuration file by the name of "RTconfig.ini" is required, the contents 
of which need to look like this:

=over 1

=item comments start with a hash(#) and must be on their own seperate line

=item Outpath requires a forward slash at the end, otherwise the ending directory will have naming issues

=over 4

=item outpath    '/home/documents/RTreports/'

=item host    'therevolutionwillnotbeprogrammed.ast.raprecords.uk'

=item database    'rtfivethousand'

=item username    'cbh'

=item password     'Rg*19J$3'

=item queue     'ioa'

=item type     'mysql'

=item logdir   '/home/documents/RTreports' 

=item lib	 '/usr/share/request-tracker4/lib/'

=item #seperate values with commas

=item owners  "%,adb,gbell,nrm,sc,atb,hss,rmj,nobody" 

=item exclude_statuses    "deleted,resolved" 

=item include_statuses     "open,waiting,stalled,@owner,@requestor,testing,@3rdparty,@oversight,rejected"

number_of_tickets    10

=back


=head1 DEPENDENCIES

Requires the the following modules before running this programme:

=over 2

=item Config::Simple

=back


=head1 COMMON ERRORS

RT couldn't load RT config file /opt/rt4/etc/RT_Config.pm as:
    user: jane
    group: dream

The file is owned by user root and group _www.  

This usually means that the user/group your webserver is running
as cannot read the file.  Be careful not to make the permissions
on this file too liberal, because it contains database passwords.
You may need to put the webserver user in the appropriate group
(_www) or change permissions be able to run succesfully.

If you see this try sudo perl ....

=head1 OPTIONS

=over 2

=item help

print help message without running programme

=item man

Gives full documentation based on all pod material without running programme

=item verbose

Runs programme with details printed to screen, this includes

=over 4

=item Owners to be used in query

=item Statuses to be EXCLUDED in query counts

=item Full queries that have been constructed to be used in report

=back

=item q  used to specify a queue for the query. This queue takes precedence over the queue specified in the config file. Currently only one queue can be used to limit the query.

=item queue

(DEPRECATED) String can be entered on command line of which to use in query building. If user wants to change the queue being used, please change the respective value in 'RTconfig.ini'.

=item f

prevents the folder that the report is placed in from being created

=item d

use database for owner names


=head1 AUTHOR

Conall McMahon (email address here)


=head1 ACKNOWLEDGMENTS


=head1 SEE ALSO


=head1 CHANGES


20120916-cfm: create RTreport.pm module for support functions
20120917-cfm: create $outfile variable 
20120917-cfm: create $outfile_format variable and added html support

=back

=cut

#!/home/conall/perl5/lib

use strict;
use DBI;
use Getopt::Long;
use DateTime;
use Config::Simple;
use Pod::Usage;
use Date::Calc qw(:all);
use DateTime;

#Change lib path to working directory of RT
use lib '/usr/share/request-tracker4/lib/'; 
#use lib '/opt/rt4/lib/'; 
#use lib '/local/rt4/lib/'; 

use RT;

use RTreport;

use File::Path;
use Sys::Hostname;
my $client_host = hostname();
print "local client hostname: $client_host\n";

=pod

=head1 Methods

=over 2

=item owner("query", "owner_name")

Returns beginning argument with owner placed at beginning

=item not_requestors("query", @requestors_to_be_excluded)

Returns a query string appended with excluded requestor(s). 

=item limit_by_time("query", @time_span_string_list)

Returns query string with appended time span, to know which arguments will work, see the method itself.
Unless you know what you are changing, just leave the programme alone. 

=item not_status("query", @status_string_list)

Returns query string with appended statuses to be excluded. Please change arguments in config file

=item add_queue("query", @queue_string_list)

Returns query string with queue limiter appended. Currently only one queue can be specified and used

=item add_status("query", @status_string_list)

Returns query string with appended statuses to be included. Please change arguments in config file

=item spec_status("query", "status to be included", @status_string_list)

Returns query string with one appended status to be included and any number of statuses to be excluded. Avoid this method unless absolutely necessary

=back

=cut


=pod

=head1 Variables

=over 2

=item %config

hash which stores configuration file information to later be stored in variables. Configuration file is to be called RTconfig.ini

=item $ioa

true/false value which dictates whether to include 'ioa' queue in query over value in config file

=item @queue

holds queue values taken from config file to be used in query. Used to be specified in options, but this has since been deprecated.

=item $outpath

string value to be used as output pathway, this value is taken from config file

=item $verbose

causes specific information to be written to screen in the interest of debugging

=item $date_time

datetime reference variable for date object for getting the current date in an easy to use format

=item $date_stamp

timestamp value for use in report filename

=item $host

server host name string value for connecting to RT database, value taken from config file. Included in report.

=item $database_name

database RT type string value for connecting to RT database, value taken from config file. Included in report.

=item $user

username string value for connecting to server host, value taken from config file

=item $password

password string value fo connecting to server host, value taken from config file

=item $type

string value containing database language used server uses

=item $logdir

RT log directory to be included in report

=item $sqltickets

the bread and butter of this script, an object amalgam of ticket objects which allows us to prune this amalgam untill we have the nnumbers we need to show in the report. See tickets.pm for more info

=item @user

array of ticket owners to be used in queries, i.e. Members of tech support, taken from config file, with each name seperated by commas

=item @exclude_statuses

array of statuses to be excluded in ticket counts. Taken from config file

=item @dates

timespans to be used as row heading and are used as arguments for limit_by_time. Do not change this array without making sure the method can still produce the required results

=item @stats

numerical statistics to be used in print statements which write the report's table to screen

=item $temp_query

local variable which is used as query which is built up through the use of several methods

=item $no_folder

true/false value which, if true, will cause a folder to not be created

=item $use_database

true/false value which, if true, will use the databse to retrieve owner names, rather than using the config file

=back

=cut

my %config;
my $ioa = '';
my $specific_owner = '';
my $outpath;
my $verbose;
my ($date_stamp, $date_time);
my $no_folder;
my $queue;
my $use_database;
my $outpathforall;
my $owner;
$date_time = DateTime->from_epoch( epoch => time );
$date_stamp = $date_time->ymd('');

my $help;
my $man;

GetOptions('help|?' => \$help, man => \$man,
           'q' => \$ioa,
           'noqueue' => \$queue,
           'owner=s' => \$specific_owner,
           'verbose' => \$verbose,
           'f' => \$no_folder,
           'd' => \$use_database,
           'owner' => \$owner) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

Config::Simple->import_from( 'RTconfig.ini', \%config) or die Config::Simple->error();

$outpath = $config{outpath};

# retrieve Config values
my $host = $config{host};
my $database_name = $config{database};
my $user = $config{username};
my $password = $config{password};
my $type = $config{type};
my $logdir = $config{logdir};
my $num_tickets = $config{number_of_tickets};
my $rturl = $config{rturl};
#my $lib = $config{lib};

print "RT server hostname: $host\n";

#Set the RT config values
RT->Config->Set( DatabaseType => $type );
RT->Config->Set( DatabaseHost => $host );
RT->Config->Set( DatabaseName => $database_name );
RT->Config->Set( DatabaseUser => $user);
RT->Config->Set( DatabasePassword => $password);;
RT->Config->Set( LogDir => $logdir );
RT::LoadConfig();

#Create the output pathway for report if it doesn't already exist
$outpath .= "RTreports/" unless $no_folder;
if (-e $outpath) {print 'Directory already exists: ' . $outpath . "\n"};

unless (-e $outpath) {
    print "Creating: $outpath\n";
    unless (mkpath($outpath)) {die "Unable to create $outpath\n"};
  }

RT::Init();

my $html=1;

my $urlTicket = "${rturl}Ticket/Display.html?id";

#File to be used for output
my $fh;
my $outfile;
if ($ARGV[0]){
    $outfile = "$outpath$ARGV[0]";
    print "Output file for main: ", $outfile;
    open $fh, ">", "$outfile";
  } else {
    my $outfile_format = "txt";  
    if ($html) {$outfile_format = "html"};
    $outfile = "${outpath}RTLastContact_$date_stamp.$outfile_format";
    print "Output file for main: ", $outfile,"\n";
    open $fh, ">", "$outfile";
  }
$outpathforall = $outfile;

print "Printing regular RT details to main file\n";
#Give contextual details for report
if ($html) {print $fh "<pre>\n"};
print $fh "User: " . getlogin() . "\n";
print $fh "Server Host: $host \n"; 
print $fh "RTLastContact v4\n";
print $fh "RT version: $RT::VERSION\n";
print $fh localtime() . "\n"; #Date used to inform reader of when report was written
print $fh "Logdir: ",RT->Config->Get( 'LogDir' ),"\n";
print $fh "DatabaseType: ", RT->Config->Get( 'DatabaseType' ),"\n";

#Figure out whether to include a queue or not and whether it is a result of the getopt feature or the config file

my @queue = split(',', $config{queue});
foreach (@queue){
    s/\A\s+//;
    s/\s+\z//;
}
if($ioa){
    print $fh "Queue: IOA\n"; #IOA is enabled
} else {
   print $fh "Queues: " . $config{queue} ."\n"; #Value taken from config
}

print "Queues: " . $config{queue} ."\n" if $verbose;

#Construct our tickets object

my $sqltickets = new RT::Tickets($RT::SystemUser);

print "Generating arrays composed of owners and other query details\n";
#Retrieve owner names from database or config file
my @users;
if ($use_database){
    my $Users = RT::Users->new( RT->SystemUser );
$Users->WhoHaveRight(
        Right               => 'OwnTicket',
    );
    while (my $User = $Users->Next()){
	push(@users, $User->Name);
    }
    unshift(@users, '%');

}else{
    @users = split(',', $config{owners});
    foreach (@users){
	s/\A\s+//;
	s/\s+\z//;
    } 
    print "Owners to be used: " . $config{owners} . "\n" if $verbose; 
}

my @not_requestors;
@not_requestors = split(',', $config{not_requestor});
foreach (@not_requestors){
	s/\A\s+//;
	s/\s+\z//;
    } 
print "additional requestors to be excluded: " . $config{not_requestor} . "\n" if $verbose;

my @exclude_statuses = split(',', $config{exclude_statuses});
foreach (@exclude_statuses){
    s/\A\s+//;
    s/\s+\z//;
}
print "Statuses to be excluded: ". $config{exclude_statuses} . "\n" if $verbose;

print $fh "Statuses to be excluded: ". $config{exclude_statuses} . "\n";

print "Printing basic table details to main file\n";

print $fh "Tickets where requestor has not been contacted for more than the specified time\n";

my @dates = ( "total", "7 days", "14 days", "21 days", "28 days", "2 mon", "3 mon", "1 year");

printf $fh ("%-9s %-7s %-7s %-7s %-7s %-7s %-7s %-7s %-7s\n", "owner", @dates);

foreach my $user(@users){
    if(!$owner && $user ne '%'){
	next;
    }
    print "Generating query for $user and printing to main file\n";
    my @stats; 
    my $tempuser = substr($user, 0, 9);
    foreach my $time(@dates){
	 my $temp_query; 
	 $temp_query = RTreport::owner($temp_query, $user);
	 $temp_query = RTreport::not_requestors($temp_query, @users);
         $temp_query = RTreport::not_requestors($temp_query, @not_requestors);
	 $temp_query = RTreport::not_status($temp_query, @exclude_statuses);
	 $temp_query = RTreport::limit_by_time($temp_query, $time);
	 if($ioa){
	     $temp_query = RTreport::add_queue($temp_query, 'IOA');
	 } elsif ($queue){
	     #exclude queue
	 } else {
	     $temp_query = RTreport::add_queue($temp_query, @queue)
	 }
	 if ($verbose){
	     print "$temp_query\n";
	 }
	 $sqltickets->FromSQL($temp_query);
	 push(@stats, $sqltickets->Count());
    }
   
    printf $fh ("%-9s %-7s %-7s %-7s %-7s %-7s %-7s %-7s %-7s\n", $tempuser, @stats);
}

=pod

=head2 Part Two: retrieving the oldest open tickets and
showing them in a report format, I won't bother explaining all the
variables this time since all except one are self explanatory. Making
each variable is sometimes easy as querying the ticket count, while
others require taking a specific number from one table and looking it
up in another. A new datetime object was constructed to calculate how
long ago a ticket was created, the number given may be up to a week
off target. Currently, there is no way to edit the output through the
config, so play around with the query building below if you're
dissatisfactory results. All of the variables here are self
explanatory, except ones specified

=over 2

=item $num_tickets

number of tickets taken from config file

=back

=cut

#Make a list of n number of tickets that are oldest

close $fh;
unless ($num_tickets < 1){
    
    print "Now generating individual list of tickets for each owner\n\n";

#Modify this area to change the query
    my $query;
    my $count;
    my $spec_space = " " x 25;

    foreach my $user(@users){
	$query = "";
	unless($user eq "%"){
	    if(!$owner){
		next;
	    }
	    $query = RTreport::owner($query, $user);
	    if ($ARGV[0]){
		$outfile = "$outpath$user$ARGV[0]";
		open $fh, ">", "$outfile";
	    } else {
		my $outfile_format = "txt";  
		if ($html) {$outfile_format = "html"};
		$outfile = "${outpath}RTLastContact_${date_stamp}_$user.$outfile_format";
		open $fh, ">", "$outfile";
	    }
	    #Give contextual details for report
	    if ($html) {print $fh "<pre>\n"};
	    print $fh "User: " . getlogin() . "\n";
	    print $fh "Server Host: $host \n"; 
	    print $fh "RTLastContact v4\n";
	    print $fh "RT version: $RT::VERSION\n";
	    print $fh localtime() . "\n"; #Date used to inform reader of when report was written
	    print $fh "Logdir: ",RT->Config->Get( 'LogDir' ),"\n";
	    print $fh "DatabaseType: ", RT->Config->Get( 'DatabaseType' ),"\n";
	    print $fh "\n\nOwner to be detailed: $user\n";

       }else{
	    #Assume that we are appending onto a currently used file
	   open $fh, ">>", "$outpathforall";
	}
	print "Generating ticket report for owner $user with oldest tickets: $outfile\n";
	$query = RTreport::not_requestors($query, @users);
	$query = RTreport::not_requestors($query, @not_requestors);
	$query = RTreport::not_status($query, @exclude_statuses);
	if($ioa){
	     $query = RTreport::add_queue($query, 'IOA');
	 } elsif ($queue){
	     #exclude queue
	 } else {
	     $query = RTreport::add_queue($query, @queue)
	 }

	print $fh "-" x 79 . "\n";
	printf $fh ("|%-25s|%-51s|\n|%-25s|%-25s|%-25s|\n|%-25s|%-25s|%-25s|\n|%-25s|%-25s|%-25s|\n|%-25s|%-25s|$spec_space|\n", 
		"ID", "Subject", 
		"Queue", "Status","Problem Type",
		"Owner", "Creator", "Requestor", 
		"Created", "Last Updated", "Last Contacted", "Due", "Last Contacted (days)"); 
	print $fh "-" x 79 . "\n";

	print $query . "\n" if $verbose;
	$sqltickets->FromSQL($query);
	$sqltickets->OrderBy(FIELD => 'Told', 
		     ORDER => 'ASC');
	if ($num_tickets > $sqltickets->Count()){
	    $count =  $sqltickets->Count();
	} else {
	    $count = $config{number_of_tickets}
	};
	my $User_name = RT::User->new($RT::SystemUser);
	my $queue_database = new RT::Queue($RT::SystemUser);
#my $CustomFields = RT::CustomField->new($RT::SystemUser); # store custom fields

	my $counter=0;
	print $fh "No tickets present\n" if $count < 1;
	foreach (1..$count){
	    #Variables are self explanatory 
	    $counter++;
	    my $ticket = $sqltickets->Next();
	    my $id = $ticket->Id;
	    my $subject = $ticket->Subject;
	    $subject = substr($subject, 0, 50);
	    my $requestor = join(' ',($ticket->Requestors->MemberEmailAddresses));
	    $User_name->Load($ticket->Owner);
	    my $owner = $User_name->Name;
	    my $queue = $ticket->QueueObj->Name;
	    my $created = $ticket->Created;
	    $created =~ m/(\d\d\d\d)-(\d\d)-(\d\d)/;
	    my $status = $ticket->Status;
	    my $difference = "unknown";
	    my $created_date = DateTime->new(
		year =>$1,
		month => $2,
		day =>$3);
	    if($created eq "1970-01-01 00:00:00"){
		$created = "(Not set)";
	    }	
	    my $told = $ticket->Told;
	    $told =~ m/(\d\d\d\d)-(\d\d)-(\d\d)/;
	    my $told_date = DateTime->new(
		year =>$1,
		month => $2,
		day =>$3);
	    if($told eq "1970-01-01 00:00:00"){
		$told = "(Not set)";
		$difference = "(Not set)";
	    }else{
		$difference = abs(Delta_Days($date_time->year, $date_time->month, $date_time->day, 
					 $told_date->year, $told_date->month, $told_date->day));
	    }
	    my $updated = $ticket->LastUpdated;
	    if($updated eq "1970-01-01 00:00:00"){
		$updated = "(Not set)";
	    }
    #$told = "Not told since created" if $told eq "1970-01-01 00:00:00";
	    $User_name->Load($ticket->Creator);
	    my $creator = $User_name->Name;    

	    my $CustomFields = $ticket->QueueObj->TicketCustomFields();
	    my $CustomField = $CustomFields->Next(); 
	    my $CFname1 = $CustomField->Name;
    #my $CFvalue1 = 'test';
	    my $CFvalue1 = $ticket->FirstCustomFieldValue($CFname1); 
    
    # needs some formatting using the number of characters in $id
	    my $nchars = 25 - length($id);
	    if ($html) {$id = "<a href=\"$urlTicket=$id \">$id</a>" . " " x $nchars};

	    my $due = $ticket->Due;
	    if($due eq "1970-01-01 00:00:00"){
		$due = "(Not set)";
	    }

	    printf $fh ("|%-8s${spec_space}${spec_space}                   |\n|%-25s|%-51s|\n|%-25s|%-25s|%-25s|\n|%-25s|%-25s|%-25s|\n|%-25s|%-25s|%-25s|\n|%-25s|%-25s$spec_space |\n", $counter, $id, $subject, $queue, $status, $CFvalue1, $owner, $creator, $requestor, $created, $updated, $told, $due, "$difference day(s) ago");
	    print $fh "-" x 79 . "\n";
	}
	print $fh "</pre>\n" if ($html);
	close $fh;
    }
}


print "Programme was successful.\n";
		     
