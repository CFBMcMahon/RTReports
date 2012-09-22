=pod

=head1 RTunresolved

RTunresolved - Produces a text file report which informs the reader on how many tickets a specific ticket 
owner (the column headings) has in each status (specified in config file). Include name of file as a command
 line argument if you desire a different filename to be used. This is useful if you want different queries 
to be made without each report overwriting the previous on that day or if you just want more informative 
file names. Please be aware that if no pathway is provided, the output folder will be created in the current
 working directory (where the programme was run, presumably)

=head1 SYNOPSIS

   Options:
      -h --h -help    --help brief help message listing these options
      -m --m -man     --man full documentation based on all pod material
      -v --v -verbose --verbose Prints certain details to screen for debugging
         --q                enables 'IOA' to be used as a queue limiter for query building. Has priority over config file queue variable.
        --queue             (deprecated) Give a string to be used as queue in query building
         --f                Do not create a folder for report
         --d                Use database as basis for owner names
      

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
=back

Remember to install the following modules before running this programme:

=over 2

item=Config::Simple

=back

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
use lib '/usr/share/request-tracker4/lib/'; 
use RT;
use File::Path;
use Sys::Hostname;
my $client_host = hostname();
print "hostname: $client_host\n";


=pod

=head1 Methods

=over 2

=item owner("query", "owner_name")

Returns beginning argument with owner placed at beginning

=item not_requestors("query", @requestors_to_be_excluded)

Returns a query string appended with excluded requestor(s). 

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

sub not_status {
    my $query = shift(@_);
    foreach(@_){
	unless ($query eq ""){ $query .= " AND status != '$_'";}
	else{ $query .= "status != '$_'";}
    }
    $query;
}

sub add_status {
    my $query = shift(@_);
    foreach(@_){
	unless ($query eq ""){ $query .= " AND status = '$_'";}
	else{ $query .= "status = '$_'";}
    }
    $query;
}

sub add_queue {
     my $query = shift(@_);
    foreach(@_){
	unless ($query eq ""){ $query .= " AND queue = '$_'";}
	else{ $query .= "status = '$_'";}
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

=item @include_statuses

array of statuses to be included in ticket counts. Taken from config file. PLease be careful that any to be excluded won't also be included, since they will then be included rather than excluded

=item @dates

timespans to be used as row heading and are used as arguments for limit_by_time. Do not change this array without making sure the method can still produce the required results

=item @numbers

numerical statistics to be used in print statements which write the report's table to screen

=item $included_number

holds number of array items in order to prevent unwanted artefacts in print statements

=item $temp_query

local variable which is used as query which is built up through the use of several methods

=item $no_folder

true/false value which, if true, will cause a folder to not be created

=back

=cut

my %config;	    
my $ioa = '';
my $queue = '';
my $specific_owner = '';
my $outpath;
my $verbose;
my ($date_stamp, $date_time);
my $no_folder;
my $client_host = hostname;
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
#my $lib = $config{lib};

#Set the RT config values
RT->Config->Set( DatabaseType => $type );
RT->Config->Set( DatabaseHost => $host );
RT->Config->Set( DatabaseName => $database_name);
RT->Config->Set( DatabaseUser => $user);
RT->Config->Set( DatabasePassword => $password);;
RT->Config->Set( LogDir => $logdir );
RT::LoadConfig();

#Create the output pathway for report if it doesn't already exist
$outpath .= 'RTunresolved/' unless $no_folder;
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
    open $fh, ">", "${outpath}RTownerstats_$date_stamp.txt";
}

#Give contextual details fo report
print $fh "User: " . getlogin() . "\n";
print $fh "Server Host: $host \n"; 
print $fh "RT ownerstats v4\n";
print $fh "RT version: $RT::VERSION\n";
print $fh localtime() . "\n"; #Date used to inform reader of when report was written
print $fh "Logdir: ",RT->Config->Get( 'LogDir' ),"\n";
print $fh "DatabaseType: ", RT->Config->Get( 'DatabaseType' ),"\n";

#Figure out whether to include a queue or not and whether it is a taken from the getopt feature or the config file

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

my $sqltickets = new RT::Tickets($RT::SystemUser);;

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

#Statuses to be included for add_status method; taken from config file, seperated by commas.

my @included_statuses = split(',', $config{include_statuses});
foreach (@included_statuses){
    s/\A\s+//;
    s/\s+\z//;
}
print "Statuses to be included: " . $config{include_statuses}. "\n" if $verbose;

print $fh "Statuses to be included: " . $config{include_statuses}. "\n";

my $included_number = @included_statuses; #Retrieve number of items in array in order to get printf to give the right output

$included_number += 2; #increment to include owner and total

print $fh "Number of tickets each owner has under each status\n";

#Column headings, making use of statuses.
printf $fh ("%-11s" x $included_number . "\n", "owner", "total", @included_statuses); 

foreach my $user (@users){    
    my @numbers = (); # holds numbers to be used in print statement statistics   
    $user = substr($user, 0, 11);
    push(@numbers, $user); #Add owner name to array
    my($query, $temp_query); 
    $query = &owner($query, $user); 
    $query = &not_requestors($query, @users); #Make basic query for total 
    if($ioa){
	$query = &add_queue($query, 'IOA');
    } else {
	$query = &add_queue($query, @queue);
    }
    $query = &not_status($query, @exclude_statuses);

    $temp_query = $query; #create a restart point for each individual query in the for loop
    print "$query\n" if $verbose;
    $sqltickets->FromSQL($temp_query) or die "SQL query failed, probably due to faulty queue name";
    push(@numbers, $sqltickets->Count());
    #Go through each individual status
    foreach my $status (@included_statuses) {
	$query = $temp_query; 
	$query = &add_status($query, $status);
	print "$query\n" if $verbose;
	$sqltickets->FromSQL($query) or die "SQL query failed, probably due to faulty queue name";
	push(@numbers, $sqltickets->Count());
    }
    printf $fh ("%-11s" x @numbers . "\n", @numbers);
}

if ($ARGV[0]){
    printf "Programme was successful, output can be found in $outpath$ARGV[0]\n";
} else {
    print "Programme was successful, output can be found in ${outpath}RTownerstats_$date_stamp.txt\n";
}







