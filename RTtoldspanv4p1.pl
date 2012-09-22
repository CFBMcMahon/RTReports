=pod

=head1 RTtoldspan

RTtoldspan - Produces a text file report which informs the reader on how many tickets a specific ticket 
owner (the column headings) has where the requestor has not been contacted for more than the specified time (the row headings). Include name of file as a command 
line argument if you desire a different filename to be used. 
This is useful if you want different queries to be made without each report overwriting the previous on that day or if you just want more informative file names. 
Please be aware that if no pathway is provided, the output folder will be created in the current working directory (where the programme was run, presumably)

=head1 SYNOPSIS

   Options:
      -h --h -help    --help brief help message listing these options
      -m --m -man     --man full documentation based on all pod material
      -v --v -verbose --verbose Prints certain details to screen for debugging
         --q                enables 'IOA' to be used as a queue limiter for query building. Has priority over config file queue variable.
        --queue             (deprecated) Give a string to be used as queue in query building
         --f                Do not create a folder for report

A configuration file by the name of "RTconfig.ini" is required, the contents of which need to look like this:

=over 1
#comments start with a hash and must be on their own seperate line
#Outpath requires a forward slash at the end, otherwise the ending directory will have naming issues
outpath    '/home/documents/RTreports/'
host    'therevolutionwillnotbeprogrammed.ast.raprecords.uk'
database    'rtfivethousand'
username    'cbh'
password     'Rg*19J$3'
queue     'ioa'
type     'mysql'
logdir   '/home/documents/RTreports' 
lib	 '/usr/share/request-tracker4/lib/'
#seperate values with commas
owners  "%,adb,gbell,nrm,sc,atb,hss,rmj,nobody" 
exclude_statuses    "deleted,resolved" 
include_statuses     "open,waiting,stalled,@owner,@requestor,testing,@3rdparty,@oversight,rejected"
number_of_tickets    10
=back

Remember to install the following modules before running this programme:

=over 2

item=Config::Simple

=back

=head2 Option

=over 2

=item help

print help message without running programme

=item man

Gives full documentation based on all pod material without running programme

=item verbose

Runs programme with details printed to screen, this includes

over 4

=item Owners to be used in query

=item Statuses to be EXCLUDED in query counts

=item Full queries that have been constructed to be used in report

=back

=item q

Has highest priority over queue making, preventing config file variable from being used. Currently only one queue can be used to limit the query.

=item queue

(DEPRECATED) String can be entered on command line of which to use in query building. If user wants to change the queue being used, please change the respective value in 'RTconfig.ini'.

=item f

prevents the folder that the report is placed in from being created

=back

=cut

#!/home/conall/perl5/lib
use strict;
use DBI;
use Getopt::Long;
use DateTime;
use Config::Simple;

#Change lib path to working directory of RT
#use lib '/usr/share/request-tracker4/lib/'; 
#use lib qw( /opt/rt4/local/lib /opt/rt4/lib );
use lib qw( /local/rt4/local/lib /local/rt4/lib );

use RT;
use File::Path;

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

sub owner {
    my($query, $new_owner) = ($_[0], $_[1]);
    #print $new_owner , "\n";
    if ($new_owner =~ m/^%$/){
	$query =~ s/^/owner LIKE '%'/;
    } else {
	$query =~ s/^/owner = '$new_owner'/;
    }
    $query;
}

sub not_requestors {
    my $query;
    $query = shift(@_);
    foreach my $subject (@_){
       if ($query eq ""){
	   unless($subject eq '%'){
	       $query = "Requestor.Name != '$subject'";
	   }
       } else {
	   unless($subject eq '%') {
	       $query .= " AND Requestor.Name != '$subject'";
	   }
       }
    }
    $query;
} 

sub limit_by_time {
    my($query, $time) = (@_[0] , @_[1]);
    if ($time eq "total") {
	     #do nothing
    } elsif ($time eq "7 days") {
	     $query .= " AND Told < '1 weeks ago'";
    } elsif ($time eq "14 days") {
	     $query .= " AND Told < '2 weeks ago'";
    } elsif ($time eq "21 days") {
	     $query .= " AND Told < '3 weeks ago'";
    } elsif ($time eq "28 days") {
	     $query .= " AND Told < '4 weeks ago'";
    } elsif ($time eq "2 mon") {
	     $query .= " AND Told < '2 months ago'";
    } elsif ($time eq "3 mon") {
	     $query .= " AND Told < '3 months ago'";
    } elsif ($time eq "1 year") {
	     $query .= " AND Told < '1 year ago'";
    } else {
	print "Warning, query time was not recognised: $time\n";
    }
    $query;
}

sub not_status {
    my $query = shift(@_);
    foreach(@_){
	unless ($query eq ""){ $query .= " AND status != '$_'";}
    }
    $query;
}

sub add_status {
    my $query = shift(@_);
    foreach(@_){
	unless ($query eq ""){ $query .= " AND status = '$_'";}
    }
    $query;
}

sub add_queue {
     my $query = shift(@_);
    foreach(@_){
	unless ($query eq ""){ $query .= " AND queue = '$_'";}
    }
    $query;
}
    
sub spec_status {
    my $query = shift(@_);
    my $add = shift(@_);
    $query = &add_status($query, $add);
    $query = &not_status($query, @_);
    $query;
}

=pod

=head 1 Variables

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
$date_time = DateTime->from_epoch( epoch => time );
$date_stamp = $date_time->ymd('');

GetOptions('q' => \$ioa,
          'queue' => \$queue,
          'owner=s' => \$specific_owner,
          'verbose' => \$verbose,
          'f' => \$no_folder,
          'd' => \$use_database);

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
#my $lib = $config{lib};

#Set the RT config values
RT->Config->Set( DatabaseType => $type );
RT->Config->Set( DatabaseHost => $host );
RT->Config->Set( DatabaseName => $database_name );
RT->Config->Set( DatabaseUser => $user);
RT->Config->Set( DatabasePassword => $password);;
RT->Config->Set( LogDir => $logdir );
RT::LoadConfig();

#Create the output pathway for report if it doesn't already exist
$outpath .= "RTtoldspan/" unless $no_folder;
if (-e $outpath) {print 'Directory already exists: ' . $outpath . "\n"};
unless (-e $outpath) {
  print "Creating: $outpath\n";
  unless (mkpath($outpath)) {die "Unable to create $outpath\n"};
}

RT::Init();

#File to be used for output
my $fh;
if ($ARGV[0]){
    open $fh, ">", "$outpath$ARGV[0]";
} else {
    open $fh, ">", "${outpath}RTtimespan_$date_stamp.txt";
}

#Give contextual details for report
print $fh "User: " . getlogin() . "\n";
print $fh "Server Host: $host \n"; 
print $fh "RT toldspan v4\n";
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

my @exclude_statuses = split(',', $config{exclude_statuses});
foreach (@exclude_statuses){
    s/\A\s+//;
    s/\s+\z//;
}
print "Statuses to be excluded: ". $config{exclude_statuses} . "\n" if $verbose;

print $fh "Statuses to be excluded: ". $config{exclude_statuses} . "\n";

print $fh "Tickets where requestor has not been told in more than the specified time\n";

my @dates = ( "total", "7 days", "14 days", "21 days", "28 days", "2 mon", "3 mon", "1 year");

printf $fh ("%-9s %-7s %-7s %-7s %-7s %-7s %-7s %-7s %-7s\n", "owner", @dates);

foreach my $user(@users){
    my @stats; 
    foreach my $time(@dates){
	 my $temp_query; 
	 $temp_query = &owner($temp_query, $user);
	 $temp_query = &not_requestors($temp_query, @users);
	 $temp_query = &not_status($temp_query, @exclude_statuses);
	 $temp_query = &limit_by_time($temp_query, $time);
	 if($ioa){
	     $temp_query = &add_queue($temp_query, 'IOA');
	 } else {
	     $temp_query = &add_queue($temp_query, @queue);
	 }
	 if ($verbose){
	     print "$temp_query\n";
	 }
	 $sqltickets->FromSQL($temp_query);
	 push(@stats, $sqltickets->Count());
    }
   
    printf $fh ("%-9s %-7s %-7s %-7s %-7s %-7s %-7s %-7s %-7s\n", $user, @stats);
}

=pod

=head2 Part Two
Part two, retrieving the oldest open tickets and showing them in a report format, I won't bother explaining all the variables this time since  all except one are self explanatory. Making each variable is sometimes easy as querying the ticket count, while others require taking a specific number from one table and looking it up in another. A new datetime object was created to calculate how long ago a ticket was created, the number given may be up to a week off target. Currently, there is no way to edit the output through the config, so play around with the query building below if you're dissatisfactory results.

=over 2

=item $num_tickets

number of tickets taken from config file

=back

=cut

#Make a list of n number of tickets that are oldest
unless ($num_tickets < 1){
print $fh "-" x 105 . "\n";
printf $fh ("|%-25s|%-25s|%-25s|%-25s|\n|%-25s|%-25s|%-25s|                         |\n|%-51s|%-51s|\n", "Ticket ID", "Queue", "Status", "Subject", "Owner", "Creator", "Requestor", "Created", "Last Contacted"); 
print $fh "-" x 105 . "\n";

#Modify this area to change the query
my $query;
my $count;
$query = &not_requestors($query, @users);
$query = &not_status($query, "resolved", "rejected", "deleted");
print $query . "\n";
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
foreach (1..$count){
    #Variables are self 
    my $ticket = $sqltickets->Next();
    my $id = $ticket->Id;
    my $subject = $ticket->Subject;
    my $requestor = join(' ',($ticket->Requestors->MemberEmailAddresses));
    $User_name->Load($ticket->Owner);
    my $owner = $User_name->Name;
    my $queue = $ticket->QueueObj->Name;
    my $created = $ticket->Created;
    $created =~ m/(\d\d\d\d)-(\d\d)-(\d\d)/;
    my $status = $ticket->Status;
    my $created_date = DateTime->new(
	year =>$1,
	month => $2,
	day =>$3);
    my $told = $ticket->Told;
    my $difference = $created_date->delta_days($date_time);
    $told = "Not told since created" if $told eq "1970-01-01 00:00:00";
    $created .= $difference->weeks;
    $User_name->Load($ticket->Creator);
    my $creator = $User_name->Name;    
    printf $fh ("|%-25s|%-25s|%-25s|%-25s|\n|%-25s|%-25s|%-25s|                         |\n|%-51s|%-51s|\n", $id, $queue, $status, $subject, $owner, $creator, $requestor, $created, $told);
    print $fh "-" x 105 . "\n";
    
}
}

if ($ARGV[0]) {
    print "Programme was successful, output can be found in $outpath$ARGV[0]\n";
} else {
    print "Programme was successful, output can be found in ${outpath}RTtimespan_$date_stamp.txt\n";
}


    
		     
