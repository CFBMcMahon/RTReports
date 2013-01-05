#!/usr/bin/perl
# $Source$	
#234567890123456789012345678901234567890
#
# $Id$	
#
# Calculate RT stats for web pages
#
#
# Customised to only show response times for the IOA queue excluding tickets 
# with requestor; COC Chair(rgm) and requestor members of the Computing/IT 
# support team. This is done by name but could be done by group ID.
# Tickets created by the CG where the requestor is a user are also excluded 
# since the creation time is the first contact time and inclusion of these 
# will skew results. For instance walkin tickets are created
# by the CG. Also account extension tickets.
#
# Also the original Oxford version presented the working day results at 
# 1hr, 2hr, 6hr 18hrs. These are computed as a fraction of a day. Since it 
# is the fraction of a working day, 6hrs is a quarter of a working
# day. The relevant changes are turned on with the $ioa variable
#
# Could include the contact and resolved results in terms of 'real' data 
# to show how results differ.
#
# TODO:
#    plot range of response rates for group; poorest; best
#    exclude; General and nobody but list these in a file 
# 
# IMPORTANT PARAMETERS
#  working day
#
#
# Issues
#   need to check the group ID for the computing group
#   get odd results when backthen increased >2yrs
#   get around it by changing the year to year2 as well
#
#
#  CHANGES
#  $webdir    changed to $outpath 
#
#
# MODIFICATION HISTORY
# Original provides "as is"  from Keith A. Gillow <Keith.Gillow@maths.ox.ac.uk>
#                            Fri, 02 Mar 2012 14:39:44 +0000
#
#
#
# 
#  $Id$
#
#  $Log$
#
#
# Login name of author of last revision:   $Author$ 
# Date and time (UTC) of revision:         $Date$
# Login name of user locking the revision: $Locker$ 
# CVS revision number:                     $Revision$ 
#


=head1 NAME
  
rtmetrics_times - Generate ticket response and resolution metrics
  
=head1 SYNOPSIS
  
sample [options] [file ...]

  Options:
    -help  brief help message
    -man   full documentation
    -user  user tickets only
    -test  test run on a single queue for a 2 month cycle
    -owner charts for a single or list of owners
    -init  read initialisation file in Windows INI format
  
=head1 OPTIONS
  
=over 8

=item B<-help>

Print a brief help message and exits.
  
=item B<-man>

Prints the manual page and exits.


=item B<-archive>

creates a copy of the output in a archivable directory tree structure
of form YYYY/MM/DD.

=item B<-user>

Analysis of tickets submitted by users. users are defined as requestors
who are not members of the support team. A list of names has to 
be provided. Maybe there is a groupid query that can be used.

=item B<-userlist>

Provide a list of usernames and analyze tickets with each user
as a requestor

=back
  
=head1 DESCRIPTION

B<rtchart_byqueue> reads the RT database and generates first response and resolution time charts.

It has only been implemented and tested for a MySQL database. Maybe
the RT perl API could be used to make it DB independent.

In order to read the initialisation file the Tiny module is required.

=head1 HISTORY


=head1 AUTHOR


=cut

use DBI;
use Date::Parse;
use GD::Graph::lines;
use Cwd;
use Sys::Hostname;
use File::Path;
use Config::Simple;
use Getopt::Long;
use Pod::Usage;
# see http://perldoc.perl.org/Getopt/Long.html#Simple-options

# declare and initialise all the options
my $archive = "";
my $cycles = 12;
my $users = "";
my $userlist = "";
my $init = "";
my $owners = "";
my $man = 0;
my $help = 0;
my $debug=0;
my $verbose=0;
my $outpath="./";
my $start_date="2012-01";
my $end_date="2012-01";
my $test="";
GetOptions('help|?' => \$help, 
             man => \$man,
           'debug' => \$debug,
           'verbose' => \$verbose,
           'outpath' => \$outpath,
           'test' => \$test,
           'cycles=i' => \$cycles,
           'users' => \$users,
           'userlist=s' => \$userlist,
           'owners=s' => \$owners,
           'init' => \$init,
           'archive=s' => \$archive,
           'startdate' => \$start_date) or pod2usage(2);
$thishost = hostname();

Config::Simple->import_from( 'RTconfig.ini', \%config) or die Config::Simple->error();

#Config file data

$host = $config{host};
$db = $config{database};
$user = $config{username};
$pass = $config{password};
my $type = $config{type};
my $logdir = $config{logdir};
my $rturl = $config{rturl};
my $outpath = $config{outpath};
$queue = $config{queue};

$debug = 0;
$verbose = 1;
$users = 1;
$ioa=1;

# option to annonymize the Owner IDs
$anonymous=0;

$plotrange=1;


$verbose && print 'verbose: ', $verbose,"\n";

print 'Running: ', $0, "\n";
print 'Running on: ', $thishost, "\n";
#print 'Running: ',abs_path($0), "\n";
print 'username: ', getlogin(), "\n";
print 'Current working directory: ', getcwd(), "\n";

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$timestamp = sprintf("%04d%02d%02d-%02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);

print "Timestamp: $timestamp\n";

# working day
($shour,$ehour) = (9.0,15.50);
$whoursperday= $ehour - $shour;

$respond_limit = 1.0;

$nyears=2.0;
$now = time;
$backthen = $now - $nyears*365*24*60*60; # n years ago, i.e. the report period


#$webdir='/var/www/drupal/files/generated/rt-plots';
#$webdir='./';

$webpath = '/2009/';

#$webpath = '';
#$webpath = '/2012/';
$webpath = '/2012/01/';
#$webpath = '/2012/02/';
#$webpath = '/2012/03/';
#$webpath = '/2012/04/';



$creationdate = '%';
#$creationdate = 0;
$outdir = '/';


#$creationdate = '2010-%';
#$outdir = '/2010/';

$creationdate = '2011-%';
$outdir = '/2011/';

$creationdate = '2012-%';
$outdir = '/2012/';
#$outdir = '/2012/01/';
#$outdir = '/2012/02/';
#$outdir = '/2012/03/';
#$outdir = '/2012/04/';

$creationdate = '2012-%';
#$creationdate = '2012-01%';
#$creationdate = '2012-02%';
#$creationdate = '2012-03%';
#$creationdate = '2012-04%';

#if ($creationdate>0) {print $creationdate};

print 'outpath: ',$outpath, "\n";
#$outpath='/home/rgm/public_html/coc/rt-metrics/' . $outdir;
#print 'outpath: ',$outpath, "\n";

if (-e $outpath || $verbose) {
  print 'Directory already exists: ' . $outpath . "\n"};
unless (-e $outpath) {
  if ($verbose) {print 'Creating: $outpath\n'};
  unless (mkpath($outpath)) {die "Unable to create $outpath\n"};
  }

# create filehandles for output files
open(FR1, ">$outpath/first_response_concerns.txt") or die $!;

# header for the html results file
$coc_chair='rgm';
$htmlheader="
<html><head>
<title>RT Plots: $queue </title>
</head><body>

<li> Based on modified 
<a href=http://www.maths.ox.ac.uk/notices/it/request-system>
software and metric plots from University of Oxford Mathematics Institute </a>
<p> 
Host: $thishost at: $timestamp 
<p>
Queue: $queue; 
<br> 
Ticket Creation: $creationdate
<br>
Working day for helpdesk opening hours: $shour to $ehour

<hr>
<p>
Statistics for tickets in the IOA queue where the ticket creator or ticket 
requestor is a 
normal user. 
Tickets where the ticket creator or ticket requestor is
a member of the IOA Computing/IT Support team are excluded. Tickets where 
the requestor or creator is the Computing Oversight Commitee Chair 
($coc_chair) are also 
excluded since many of these are related to oversight and not normal user
requests.
<p>
First human email response times is in terms of working 
hours and are based on RT email correspondence. The working hours period
is defined globally at the moment i.e. does not take into account
changes from the global value.
In cases where the first human response has been verbal the response
time does not take this into account. The time intervals in working hours
take into account weekends but does not take into account holidays. 
The effect of these is expected to smaller than the skewing due to 
verbal first reponse based on analysis of a tickets with apparently 
long human response times. 
<br>
<hr>
";



$htmlfooter="  
</html>
</body>";

#periods that stats are produced over in days
%periods = ('week' => 7, 'month' => 30, 'qtr' => 91,'semi' => 182,
	    'year' => 365, 'yeartwo' => 2*365);

#	    'year' => 365, 'yeartwo' => 730);

@periods_order = qw(week month qtr semi year yeartwo);

@periods_data = ( ['0', 'last week', 'last month', 'last qtr', 'last half', 'last year', 'last 2 years'] );
@periodsav_data = @periods_data;


#working periods that stats are produced over in days
@periods_work_order = qw(hour hour2 hour6 hour18 day day2 day3 day4 day5 day6 day7 day10 day15 day20 day30 );

%periods_work = ('hour' => 0.0417, 'hour2' => 0.0833, 'hour6' => 0.25, 'hour18' => 0.75, 'day' => 1, 'day2' => 2, 'day3' => 3, 'day4' => 4, 'day5' => 5, 'day6' => 6, 'day7' => 7, 'day10' => 10, 'day15' => 15, 'day20' => 20, 'day30' => 30);

@work_data = ( [ "0", "1 hour","2 hours", "6 hours","18 hours", "1 day", "2 days", "3 days", "4 days", "5 days", "6 days", "7 days", "10 days", "15 days", "20 days", "30 days"] );

if ($ioa) {
  # modified by rgm to computes hours in terms of a working day
  @periods_work_order = qw(hour hour2 hour4 hour6 day day2 day3 day4 day5 day6 day7 day10 day15 day20 day30);

  %periods_work = ('hour' => 1.0/$whoursperday, 'hour2' => 2.0/$whoursperday, 'hour4' => 4.0/$whoursperday, 'hour6' => 6.0/$whoursperday, 'day' => 1, 'day2' => 2, 'day3' => 3, 'day4' => 4, 'day5' => 5, 'day6' => 6, 'day7' => 7, 'day10' => 10, 'day15' => 15, 'day20' => 20, 'day30' => 30);

  @work_data = ( [ "0", "1 hour","2 hours", "4 hours","6 hours", "1 day", "2 days", "3 days", "4 days", "5 days", "6 days", "7 days", "10 days", "15 days", "20 days", "30 days"] );
};

@work_respond_data = @work_data;

# default line plot settings
# set also sub create_graph 
$graph_width = 600;
$graph_height = 450;
%graphopts = (
            title => 'TITLE HERE', 
            x_labels_vertical => 1,
	    long_ticks => 1,
	    line_width => 3,
	    transparent => 0,
            legend_placement => 'RC',
	    legend_marker_width => 18,
	    legend_spacing => 8,
	    bgclr => 'lgray',
            dclrs => [qw(white lorange lgreen lred lblue lyellow lpurple marine cyan black) ]           
#	    show_values => 1,
        );

#$dsn = "DBI:mysql:database=$database;host=$host:port=3306";
#$dbh = DBI->connect($dsn, $user, $password, {'RaiseError' => 1});

$dbh = DBI->connect("dbi:$type:".$db.';host='.$host,$user,$pass);


#Formatted printing output for debug mode
select(STDOUT); $|=1; $= =100000;	

format STDOUT_TOP =
 Id    Creator           Owner     DTrsv   WDTrsv  DSrsv   WDrsp   Queue         Subject
 ===== =========         ========= ======= ======= =====   =====   =========== ===================================
.



format STDOUT =
 @<<<< @<<<<<<<<<<<<<<<< @<<<<<<<< @<<<<<< @<<<<<< @<<<<<< @<<<<<< @<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
 $ary[0],$ary[1],$ownername{$ary[2]},$days_to_resolve,$working_days_to_resolve,$days_resolved,$working_days_to_respond,$ary[3],$ary[5],$ary[6]
.


format FR1_TOP =
 Id    Creator           Queue     Owner     DTrsv   WDTrsv  DSrsv   WDrsp   CREATED                  QUEUE       Subject
 ===== ================  ========= ======= ======= =====   =====   ====================     =========== ===================================
.

format FR1 =
 @<<<< @<<<<<<<<<<<<<<<< @<<<<<<<< @<<<<<<<< @<<<<<< @<<<<<< @<<<<<< @<<<<<< @<<<<<<<<<<<<<<<<<<<<<   @<<<<<<<<<  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
 $ary[0],$ary[1],$ARY[5],$ownername{$ary[2]},$days_to_resolve,$working_days_to_resolve,$days_resolved,$working_days_to_respond,$ary[3],$ary[5],$ary[6]
.



#return number of days between two times
sub days_diff {
  my ($opened_seconds, $closed_seconds) = @_;
  return ($closed_seconds - $opened_seconds)/(60*60*24);
} 

#return the number of working days in the period, i.e. remove the weekends
sub working_days_diff {
#If a ticket id opened before start of working day roll forward open time
#to start of working day
#If a ticket is opened after working day ends roll forward open time 
#to start of next working day
#Remove Saturdays and Sundays entirely
#Don't bother with bank holidays or official closures as that would 
#be very complicated 
#Similarly if a ticket is closed out of hours roll the close time back
#Then remove 2*number of weekends from this total days diff
#Then remove any final weekend straddled by start day/time and end day/time

    my ($opened_seconds,$closed_seconds) = @_;
    my ($days_open,$working_days);
    my ($osec,$omin,$ohour,$owday)=(gmtime($opened_seconds))[0,1,2,6];
    my ($csec,$cmin,$chour,$cwday)=(gmtime($closed_seconds))[0,1,2,6];

    #set the hours that the working day beings and ends
    #my ($shour,$ehour) = (9,17);


#Adjust opened time forward if required    
    if ( $ohour < $shour ) {
	#working day hasn't started so roll forward to start of day
	$opened_seconds += (($shour-$ohour)*60 -$omin)*60 -$osec;
    }

    if ( $ohour > $ehour-1) {
	#working day is over so roll forward to start of next day
	$opened_seconds += ((24+$shour-$ohour)*60 -$omin)*60 -$osec;
	$owday++;
    }

    if ( $owday==6 ) {
	#(now) opened on saturday so roll forward to sunday
	$opened_seconds += 24*60*60;
	$owday++;
    }

    if ( $owday==7 || $owday==0 ) {
	#(now) opened on a sunday so move the clock to start of monday
	$opened_seconds += ((24+$shour-$ohour)*60 -$omin)*60 -$osec;
	$owday++;
    }

#Adjust closed time backward if required
    if ( $chour > $ehour-1) {
	#working day is over so roll backwards to end of day
	$closed_seconds -= (($chour-$ehour)*60 + $cmin)*60 + $csec;
    }

    if ( $chour < $shour ) {
	#working day hasn't started so roll backward to end of previous day
	$closed_seconds -= ((24+$chour-$ehour)*60 + $cmin)*60 + $csec;
	$cwday--;
    }

    if ( $cwday==0 ) {
	#(now) closed on sunday so roll backward to saturday
	$closed_seconds -= 24*60*60;
	$cwday--;
    }

    if ( $cwday==6 || $cwday==-1 ) {
	#(now) closed on a saturday so move the clock to end of friday
	$closed_seconds -= ((24+$chour-$ehour)*60 + $cmin)*60 + $csec;
	$cwday--;
    }

    #now calcuate the days difference
    $working_days=days_diff($opened_seconds,$closed_seconds);

    #workout the number of weekends now involved and remove
    $working_days -= int($working_days/7)*2;

    #reset effective wday properly now before next bit
    $cwday = 5 if $cwday == -2;
    $owday = 1 if $owday == 8;

    #lastly can still have one final weekend in at this point,
    #check and remove 2 days if this is the case
    $working_days -= 2 if ( $cwday < $owday );
    $working_days -= 2 if ($cwday == $owday && $chour < $ohour );
    $working_days -= 2 if ($cwday == $owday && $chour == $ohour && $cmin < $omin );
    $working_days -= 2 if ($cwday == $owday && $chour == $ohour && $cmin == $omin && $csec < $osec );

    #if opened and responded/closed within a single weekend will get a 
    #negative time in which case set to zero
    $working_days = 0 if ($working_days < 0);

    return $working_days;
}

sub query_singleval {
    #simple search to get one value from one unique row match
    my ($query) = @_;
    my $sth = $dbh->prepare($query) or die "Can't prepare singleval query $query";
    $sth->execute();
    my ($singleval) = $sth->fetchrow_array;
    return $singleval;
}

sub excessive_responder_delay_days {
    #search the transactions table to get the open/closed history.
    #check if there were any periods when it was closed for more than 3 days
    #in which case remove this from the resolve time since we cannot be
    #responsible for a users not responding/reopening a closed request.
    #Note only calling this for tickets that take longer than 6 days anyway

    my ($ticketeid) = @_;
    my ($closed,$reopened,$closed_days,$delay_days);
    my $query = "
              SELECT 
                  Created, OldValue, NewValue 
              FROM 
                  Transactions 
              WHERE 
                  ObjectType='RT::Ticket' 
                  AND ObjectId=$ticketeid 
                  AND (OldValue='Resolved' or NewValue='Resolved');";

    my $sth = $dbh->prepare($query) 
        or die "Can't prepare responder delay query $query";
    $sth->execute or die "Can't execute statement: $DBI::errstr";

    my @ary;
    while (@ary = $sth->fetchrow_array) {
	my ($created,$oldval,$newval) = @ary;
	$closed = str2time($created,'GMT') if $newval eq 'resolved';
	if ( $newval eq 'open' ) {
	    $reopened = str2time($created,'GMT');
	    $closed_days = working_days_diff($closed,$reopened) if ( $reopened > $closed);
	    $delay_days += $closed_days if ($closed_days > 3);
	}
#	$debug && print "$created,$oldval,$newval,$closed,$reopened,$closed_days,$delay_days.\n";
    }
    $debug && print "User respond delay of $delay_days days on ticket $ticketeid\n" if $delay_days > 0; 
    return $delay_days;
}

#subroutine to sort names
sub by_names { return $ownername{$a} cmp $ownername{$b}; }

#subroutine to sort requesters by number of requests made
sub by_number { ($requesters{$a} <=> $requesters{$b}) || ($b cmp $a); }

#subroutine to produce a line graph; more parameters
sub create_graph {
    my ($ylabel,$outfile,@data) = @_;
    my $graph = GD::Graph::lines->new($graph_width,$graph_height);
    $graph->set_legend_font(GD::gdMediumBoldFont);
    $graph->set_x_label_font(GD::gdLargeBoldFont);
    $graph->set_y_label_font(GD::gdLargeBoldFont);
    $graph->set_x_axis_font(GD::gdMediumBoldFont);
    $graph->set_y_axis_font(GD::gdMediumBoldFont);
    $graph->set_values_font(GD::gdMediumBoldFont);
    $graph->set_legend(@legend_keys);
    $graph->set(
		y_label       => $ylabel,
		%graphopts
		);
    
    open(IMG, ">$outpath/$outfile") or die $!;
    print IMG $graph->plot(\@data)->png;
    close(IMG);
}

$tickets_merged=0;
$tickets_count;

#Main triple inner join query to get ticket info
$query_all = "
       SELECT 
         Tickets.id, 
         Users.Name, 
         Tickets.Owner, 
         Tickets.Created, 
         Tickets.Resolved, 
         Queues.Name, 
         Tickets.Subject, 
         Tickets.EffectiveId,
         Ti.Status
       FROM 
         Tickets, 
         Queues,
         Users 
       WHERE 
         Queues.name like '$queue'
         AND Tickets.Queue=Queues.id 
         AND Tickets.Creator=Users.id 
         /* AND Tickets.Status='Resolved' */
         AND Tickets.Status!='Deleted'
         ORDER BY Ti.EffectiveId;";

$query_users = "
       SELECT 
         Ti.id, 
         Users.Name, 
         Ti.Owner, 
         Ti.Created, 
         Ti.Resolved, 
         Queues.Name, 
         Ti.Subject, 
         Ti.EffectiveId,
         Ti.Status
       FROM 
         Tickets Ti, 
         Queues,
         Users, 
         Groups gr,
         CachedGroupMembers cgm,
         Principals pr
       WHERE 
         Ti.id = gr.Instance 
         AND gr.Type = 'Requestor' 
         AND gr.id = cgm.GroupId AND
                        pr.id = cgm.MemberId AND
                        Users.id = pr.id AND
                        Users.Name not like 'rgm' AND   
                        Users.Name not like 'adb' AND   
                        Users.Name not like 'atb' AND   
                        Users.Name not like 'sc' AND   
                        Users.Name not like 'nrm' AND   
                        Users.Name not like 'hss' AND   
                        Users.Name not like 'gbell' AND   
                        Users.Name not like 'helpdesk%' AND   
                        Users.Name not like 'report%' AND   
                        Users.Name not like 'MaiL%' AND
                        Users.Name not like 'MAIL%' AND
                        Users.Name not like 'postmaster%' 
         AND Queues.name like '$queue'
         AND Ti.Queue = Queues.id 
         AND Ti.Creator = Users.id 
         /* AND Ti.Status = 'Resolved' */
         AND Ti.Status != 'Deleted'
         ORDER BY Ti.EffectiveId;";

$query_users_bycreationdate= "
       SELECT 
           Ti.id, 
           Users.Name, 
           Ti.Owner, 
           Ti.Created, 
           Ti.Resolved, 
           Queues.Name, 
           Ti.Subject, 
           Ti.EffectiveId,
           Ti.Status
       FROM 
           Tickets Ti, 
           Queues,
           Users, 
           Groups gr,
           CachedGroupMembers cgm,
           Principals pr
       WHERE            
           Ti.id = gr.Instance 
           AND gr.Type = 'Requestor' 
           AND gr.id = cgm.GroupId
           AND pr.id = cgm.MemberId 
           AND Users.id = pr.id 
           AND Users.Name not like 'rgm'   
           AND Users.Name not like 'adb'    
           AND Users.Name not like 'atb'   
           AND Users.Name not like 'sc'   
           AND Users.Name not like 'nrm'    
           AND Users.Name not like 'hss'    
           AND Users.Name not like 'gbell'    
           AND Users.Name not like 'helpdesk%'    
           AND Users.Name not like 'report%'    
           AND Users.Name not like 'MaiL%' 
           AND Users.Name not like 'MAIL%' 
           AND Users.Name not like 'postmaster%' 
           AND Users.Name not like 'webman%'    
           /* AND (Queues.name like '$queue' OR Queues.name = 'General') */
           AND Queues.name like '$queue'
           AND Ti.Queue = Queues.id 
           AND Ti.Creator = Users.id 
           AND Ti.Created like '$creationdate'
           /* AND Ti.Status = 'Resolved' */
           AND Ti.Status != 'Deleted'
           ORDER BY Ti.EffectiveId
           ;";

$query = $query_all;
if ($users>0) {$query = $query_users};
if ($creationdate != 0) {$query = $query_users_bycreationdate};
#$query = $query_users_bycreationdate;

print $query,"\n";

#Ownerid list of people in the RT Admin group (and past people)
$query_admins = "SELECT MemberId FROM GroupMembers WHERE GroupId=28";
# do this earlier outside this loop
my $sth = $dbh->prepare($query_admins) or die "Can't prepare RT Admins query $query_admins";
$sth->execute();
$idlist=-1;
while (@ary = $sth->fetchrow_array ) {
    $owneridlist .= "Creator=$ary[0] or ";
    print $owneridlist[idlist],"\n";
	$idlist = $idlist+1 ;
}
#then add on 22 which was teasdale
$owneridlist .= "Creator=22";
print $owneridlist,"\n";

#Run the query
$sth = $dbh->prepare($query) or die "Can't prepare queue query";
$sth->execute or die "Can't execute statement: $DBI::errstr";

$count_created_unmerged=0;
$count_created_effective=0;

# status counters; could be some sort of list if I new how
$deleted_count=0;
$new_count=0;
$open_count=0;
$rejected_count=0;
$resolved_count=0;
$waiting_count=0;
$stalled_count=0;
$testing_count=0;
$ATowner_count=0;
$AToversight_count=0;
$ATrequestor_count=0;
$ATthirdparty_count=0;
$tickets_merged_count=0;
$rownum=0;
$tickets_merged_count=0;

$row_count = $sth->rows;
#Loop over the sql search results and construct performance measures
while (@ary = $sth->fetchrow_array) {

    $rownum++;
    $ticketid =         $ary[0];
    $ticketUsersName =  $ary[1];
    $ticketOwner=       $ary[2]; 
    $ticketCreated =    $ary[3];
    $ticketResolved =   $ary[4];
    $ticketQueue =      $ary[5];
    $ticketSubject =    $ary[6];
    $ticketeid =        $ary[7];
    $ticketStatus =     $ary[8];

    #add to overall counts (regardless of period)
    $tickets_count++;

    #print "Merged ticket: $rownum, $ticketid, $ticketeid \n";

    #First check if the ticket was merged and get resolved date from effectiveid
    $ticket_merged=0;
    if ($ticketid != $ticketeid ) {
	$ticket_merged=1;
        $tickets_merged_count++;
        print "Merged ticket: $ticketid, $ticketeid, \n";
	#need to check that the ticket it has been merged into is 
	#actually resolved before we proceed
	$query_estatus ="SELECT Status FROM Tickets WHERE id=$ticketeid";
	$estatus = query_singleval($query_estatus);
	next  if $estatus ne "resolved";

	#if resolved get details from effective ticket
	$query_eid = "SELECT Resolved FROM Tickets WHERE id=$ticketeid";
	$ary[4] = query_singleval($query_eid);
	$query_eowner = "SELECT Owner FROM Tickets WHERE id=$ticketeid";
	$ary[2] = query_singleval($query_eowner);
    }

    
    lc($ticketStatus) eq "deleted"  && $deleted_count++;
    lc($ticketStatus) eq "open"     && $open_count++;
    lc($ticketStatus) eq "rejected" && $rejected_count++;
    lc($ticketStatus) eq "resolved" && $resolved_count++;
    lc($ticketStatus) eq "waiting"  && $waiting_count++;
    lc($ticketStatus) eq "stalled"  && $stalled_count++;
    lc($ticketStatus) eq "testing"  && $testing_count++;
    lc($ticketStatus) eq "\@oversight" && $AToversight_count++;
    lc($ticketStatus) eq "\@owner"  && $ATowner_count++;
    lc($ticketStatus) eq "\@requestor" && $ATrequestor_count++;
    lc($ticketStatus) eq "\@3rdparty" && $ATthirdparty_count++;


    #convert open/created and close/resolved times to UTC
    $ticketopen = str2time($ary[3],'GMT');
    $ticketclose = str2time($ary[4],'GMT');

    #check for odd tickets that have been backwards merged and 
    #appear to take negative time to resolve
    if ( $ticketclose < $ticketopen ) {
	#need to look for LastUpdated Time instead of Resolved Time
	$query_lastupdated ="SELECT LastUpdated FROM Tickets WHERE id=$ticketid";
	$ary[4] = query_singleval($query_lastupdated);
	$ticketclose = str2time($ary[4],'GMT');
    }

    #don't use it if it was closed before the 2 year reporting period we use
    next if $ticketclose < $backthen;

    #if we got here then the ticket was resolved within our report period

    #find first human response time
    $query_first_response = "
        SELECT 
          Created 
        FROM 
          Transactions 
        WHERE 
          ObjectId=$ticketid 
          AND ObjectType='RT::Ticket' 
          AND Type='Correspond' 
        /*  AND ($owneridlist) */
          ORDER BY Created ASC
        ;";
    $first_response_time = query_singleval($query_first_response);
    
    if ( $first_response_time eq "" ) {
	# try again with merged ticketid
	if ( $ticket_merged ) {
	    $query_first_response = "
                SELECT 
                  Created 
                FROM 
                  Transactions 
                WHERE 
                  ObjectId=$ticketeid 
                  AND ObjectType='RT::Ticket' 
                  AND Type='Correspond' 
                  /* AND ($owneridlist) */
                  ORDER BY Created ASC 
                ;";
	    $first_response_time = query_singleval($query_first_response);
	}
    }

     if ( $first_response_time eq "" ) {
	# if still blank then no human response was ever given so take resolved time as the response, either F2F and then commented or did not need a response
	 $ticketrespond = $ticketclose;
     } else {
	 $ticketrespond = str2time($first_response_time,'GMT');
     }

    $query_owner="select Name from Users where id=$ary[2];";
    $ownername{$ary[2]} = query_singleval($query_owner) if (! defined $ownername{$ary[2]} );
    $owner = $ownername{$ary[2]};
    $ticketowner = $ownername{$ary[2]};

    #get something approximating a requesters name and 
    #add one to their ticket count
    $requester = $ary[1];
    $requester =~ s/\@.*//;
    $requesters{$requester}++;

    # summary of the status counts
    $status = $ary[8];
    $status_count{$status}++;

    # summary of the owner counts
    $owner_count{$owner}++;

    $days_resolved = days_diff($ticketclose,$now);
    $days_to_resolve = days_diff($ticketopen,$ticketclose);
    $working_days_to_resolve = working_days_diff($ticketopen,$ticketclose);
    $working_days_to_respond = working_days_diff($ticketopen,$ticketrespond);

    # print out tickets where time to respond is high than a threshold
    if ($working_days_to_respond gt $respond_limit) {
      #print $working_days_to_respond, "\n";
      write;
      write FR1;
      print "$ticketstatus; $ticketcreated; $first_response_time; $ticketresolved \n";
    }
    #if ($working_days_to_respond gt 5) {write};
    #if ticket takes more than 6 days to resolve check if the problem was
    #a real delay or simply the user reopening a suitably resolved ticket
    $working_days_to_resolve -= excessive_responder_delay_days($ticketeid) if ($days_to_resolve > 6 );

    #data for first table on tickets resolved by given period, e.g. last week
    foreach $period (keys %periods) {
	#also setup a counter for the requesters ticket total if needed
	$count2{$period}{$requester} = 0 if ! defined $count2{$period}{$requester};
	if ( $days_resolved <= $periods{$period} ) {
	    $count{$period}{$owner}++;
	    $timeworked{$period}{$owner} += $working_days_to_resolve;

	    #add to the requesters ticket total for the period
	    $count2{$period}{$requester}++;
	}
    }

    #data for second table on tickets responded, resolved and in less than a 
    #certain time, e.g. 1 hour
    $period_percent_placed = 0;
    $period_placed = 0;
    foreach $period (keys %periods_work) {
	$count_work_respond{$period}{$owner}++ if $working_days_to_respond < $periods_work{$period};
	$count_work{$period}{$owner}++ if $working_days_to_resolve < $periods_work{$period};
    }
    
    #write out ticket info table for debugging
    $debug && write;

}

#Get a count of tickets by status
$query_count_open = "SELECT count(*) FROM Tickets,Queues WHERE Tickets.Queue=Queues.Id and Queues.Name='General' and Tickets.Status='Open';";
$tickets_count_open = query_singleval($query_count_open);

$query_count_new = "SELECT count(*) from Tickets,Queues where Tickets.Queue=Queues.Id and Queues.Name='General' and Tickets.Status='New';";
$tickets_count_new = query_singleval($query_count_new);;

$query_count_open = "
    SELECT 
      count(*) 
    FROM 
      Tickets,Queues 
    WHERE 
      Tickets.Queue=Queues.Id 
      AND Queues.name like '$queue'
      AND Tickets.Status='Resolved';";
$tickets_count_resolved = query_singleval($query_count_open);

$query_count_new = "SELECT count(*) from Tickets,Queues where Tickets.Queue=Queues.Id and Queues.Name='General' and Tickets.Status='%owner';";
$tickets_count_ATowner = query_singleval($query_count_new);;



#add on tickets total from the old system (11218 unmerged, 766 less merged)
#$tickets_count += 11218;
#$tickets_count_unique = $tickets_count - $tickets_merged -766;
$tickets_count += 0;
$tickets_count_unique = $tickets_count - $tickets_merged_count;

#print a summary of tickets resolved/open
open(SSI, ">$outpath/rt-times-summary.html") or die $!;
#open(SSI, ">summary.ssi") or die $!;
print SSI $htmlheader;
print SSI "<ul>\n";
print SSI "   <li>Total number of rows returned = $row_count</li>\n";
print SSI "</ul>\n";
print SSI "   <hr>\n";
print SSI "<ul>\n";
print SSI "   <li>Total number of tickets with status deleted     = $deleted_count</li>\n";
print SSI "   <li>Total number of tickets with status new         = $tickets_count_new</li>\n";
print SSI "   <li>Total number of tickets with status open        = $open_count</li>\n";
print SSI "   <li>Total number of tickets with status rejected    = $rejected_count</li>\n";
print SSI "   <li>Total number of tickets with status resolved    = $resolved_count</li>\n";
print SSI "   <li>Total number of tickets with status stalled     = $stalled_count</li>\n";
print SSI "   <li>Total number of tickets with status testing     = $testing_count</li>\n";
print SSI "   <li>Total number of tickets with status waiting     = $waiting_count</li>\n";
print SSI "   <li>Total number of tickets with status \@owner     = $ATowner_count</li>\n";
print SSI "   <li>Total number of tickets with status \@oversight = $AToversight_count</li>\n";
print SSI "   <li>Total number of tickets with status \@requestor = $ATrequestor_count</li>\n";
print SSI "   <li>Total number of tickets with status \@3rdparty = $ATthirdparty_count</li>\n";
print SSI "   <hr>\n";
print SSI "   <li>Total number of tickets created = $tickets_count</li>\n";
print SSI "   <li>Total number of tickets merged = $tickets_merged_count</li>\n";
print SSI "   <li>Total number of tickets created after merging = $tickets_count_unique</li>\n";
print SSI "   <li>Total number of tickets currently open = $tickets_count_open</li>\n";
print SSI "   <li>Total number of tickets currently new = $tickets_count_new</li>\n";
#print SSI "   <li>Total number of tickets currently resolved = $tickets_count_resolved</li>\n";
print SSI "</ul>";

foreach $owner ( reverse sort by_number keys(%owner_count) ) {
    printf SSI "%20s %4d<br>\n", $owner, $owner_count{$owner};
}

foreach $status ( reverse sort by_number keys(%status_count) ) {
    printf SSI "%20s %6d<br>\n", $status, $status_count{$status};
}

print SSI $htmlfooter;
close(SSI);


open(SSI, ">$outpath/results1.html") or die $!;
print SSI $htmlheader;
#print the table of tickets resolved by period (with average days to resolve)
print SSI "\n<h3> Number of tickets resolved by period (with average working days to resolve) </h3>\n";
print SSI "<h4> (future version could include the median rather than average or both)</h4>\n";
print SSI "<table><thead><tr>
<th>Owner</th><th>last week</th><th>last month</th><th>last qtr</th>
<th>last half</th><th>last year</th><th>last 2 years</th>
</tr></thead><tbody>\n";

$av_max=0;

@owner_labels=qw(Scooby Curly Droopy Smiley Grumpy Dozy Spotty Dopey);
$owner_count=0;
$anonymous=1;
foreach $oid ( sort by_names keys %ownername ) {

    $owner_count++;
    $owner = $ownername{$oid};
    $ucowner = ucfirst $owner;
    if ($anonymous > 0) {$ucowner = $owner_labels[$owner_count-1]};
    print "Owner: $ucowner\n";

   

    foreach $period (keys %periods) {
	if ($count{$period}{$owner} > 0) {
	    $av{$period} = $timeworked{$period}{$owner}/$count{$period}{$owner};	    
	    $av_max = $av{$period} if ($av{$period} > $av_max);
	    $totalcount{$period}{Total} += $count{$period}{$owner};
	    $totaltimeworked{$period} += $timeworked{$period}{$owner};
	} else {
	    $count{$period}{$owner} = 0;
	    $av{$period} = 0;
	}
    }

    print SSI "<tr><td>$ucowner</td>";
    foreach $period (@periods_order) {
	printf SSI "<td>%6d (%4.1f)</td>",$count{$period}{$owner},$av{$period};
    }

    print SSI "</tr>\n";

    push @legend_keys, $ucowner;
    push @periods_data, [ 0, $count{week}{$owner},$count{month}{$owner},$count{qtr}{$owner},$count{semi}{$owner},$count{year}{$owner},$count{yeartwo}{$owner}];
    push @periodsav_data, [ 0, $av{week},$av{month},$av{qtr},$av{semi},$av{year},$av{yeartwo}];
}

foreach $period (keys %periods) {
    if ($totalcount{$period}{Total} > 0) {
	$totalav{$period} = $totaltimeworked{$period}/$totalcount{$period}{Total};
    } else {
	$totalav{$period} = 0;
    }
}

printf SSI "</tbody>\n";
printf SSI "<tfoot style=\"font-weight: bold;\"><tr><td>Total</td>";
foreach $period (@periods_order) {
    printf SSI "<td>%6d (%4.1f)</td>",$totalcount{$period}{Total},$totalav{$period};
}
print SSI "</tr>\n";
print SSI "</tfoot></table>\n";
print SSI $htmlfooter;
close(SSI);

push @legend_keys, 'Overall';
push @periods_data, [ 0, $totalcount{week}{Total},$totalcount{month}{Total},
  $totalcount{qtr}{Total},$totalcount{semi}{Total},$totalcount{year}{Total},
  $totalcount{yeartwo}{Total}];
push @periodsav_data, [ 0, $totalav{week},$totalav{month},$totalav{qtr},
  $totalav{semi},$totalav{year},$totalav{yeartwo}];

#print the tables of 
#Percentage of tickets receiving a human responded in less than (in working days)
#Percentage of tickets resolved in less than (in working days)
open(SSI1, ">$outpath/results2.html") or die $!;
print SSI1 $htmlheader;
print SSI1 "\n<h3> 
Percentage of tickets receiving a human response in working days.
</h3>\n";

open(SSI2, ">$outpath/results3.html") or die $!;
print SSI2 $htmlheader;
print SSI2 "\n<h3> 
Percentage of tickets resolved in working days.
</h3>\n";

$thead="<table><thead><tr><th>Owner</th>
<th>1 hour</th><th>2 hours</th><th>6 hours</th><th>18 hours</th><th>1 day</th>
<th>2 days</th><th>3 days<th>4 days</th><th>5 days</th><th>6 days</th>
<th>7 days</th><th>10 days</th><th>15 days</th><th>20 days</th><th>30 days</th>
</tr></thead>\n";

if ($ioa) {
$thead="<table><thead><tr><th>Owner</th>
<th>1 hour</th><th>2 hours</th><th>4 hours</th><th>6 hours</th><th>1 day</th>
<th>2 days</th><th>3 days<th>4 days</th><th>5 days</th><th>6 days</th>
<th>7 days</th><th>10 days</th><th>15 days</th><th>20 days</th><th>30 days</th>
</tr></thead>\n";
}

print SSI1 $thead;
print SSI2 $thead;

# compute statistics by owner
@owner_labels=qw(Scooby Droopy Smiley Grumpy Dozy Spotty Dopey);
$owner_count=0;
$anonymous=1;
foreach $oid ( sort by_names keys %ownername ) {

    $owner_count++;
    $owner = $ownername{$oid};
    $ucowner = ucfirst $owner;
    if ($anonymous > 0) {$ucowner = $owner_labels[$owner_count-1]};
    print "Owner: $ucowner\n";

    foreach $period (keys %periods_work) {
	$percent_respond{$period} = 100*$count_work_respond{$period}{$owner}/$count{'yeartwo'}{$owner};
	$percent{$period} = 100*$count_work{$period}{$owner}/$count{'yeartwo'}{$owner};
	$totalcount_work_respond{$period} += $count_work_respond{$period}{$owner};
	$totalcount_work{$period} += $count_work{$period}{$owner};
    }

    print SSI1 "<tr><td>$ucowner</td>";
    print SSI2 "<tr><td>$ucowner</td>";
    foreach $period (@periods_work_order) {
	printf SSI1 "<td>%7.2f</td>", $percent_respond{$period};
	printf SSI2 "<td>%7.2f</td>", $percent{$period};
    }
    print SSI1 "</tr>\n";
    print SSI2 "</tr>\n";

    push @work_data, [ 0,$percent{hour},$percent{hour2},$percent{hour6},
        $percent{hour18},$percent{day},$percent{day2},$percent{day3},
        $percent{day4},$percent{day5},$percent{day6},$percent{day7},
        $percent{day10},$percent{day15}, $percent{day20}, $percent{day30} ];

    push @work_respond_data, [ 0,$percent_respond{hour},
        $percent_respond{hour2},$percent_respond{hour6},
        $percent_respond{hour18},$percent_respond{day},
        $percent_respond{day2},$percent_respond{day3},
        $percent_respond{day4},$percent_respond{day5},
        $percent_respond{day6},$percent_respond{day7},
        $percent_respond{day10},$percent_respond{day15},
        $percent_respond{day20}, $percent_respond{day30} ];
}

foreach $period (keys %periods_work) {
    $percent_respond{$period} = 100*$totalcount_work_respond{$period}/$totalcount{'yeartwo'}{Total};
    $percent{$period} = 100*$totalcount_work{$period}/$totalcount{'yeartwo'}{Total};
}

print SSI1 "</tbody>\n<tfoot style=\"font-weight: bold;\">";
print SSI2 "</tbody>\n<tfoot style=\"font-weight: bold;\">";
print SSI1 "<tr><td>Overall</td>";
print SSI2 "<tr><td>Overall</td>";
foreach $period (@periods_work_order) {
	printf SSI1 "<td>%7.2f</td>", $percent_respond{$period};
	printf SSI2 "<td>%7.2f</td>", $percent{$period};
    }
print SSI1 "</tr>\n";
print SSI1 "</tfoot></table>\n";
print SSI2 "</tr>\n";
print SSI2 "</tfoot></table>\n";

print SSI1 $htmlfooter;
close (SSI1);

print SSI2 $htmlfooter;
close (SSI2);

push @work_data, [ 0,$percent{hour},$percent{hour2},$percent{hour6},
    $percent{hour18},$percent{day},$percent{day2},$percent{day3},
    $percent{day4},$percent{day5},$percent{day6},$percent{day7},
    $percent{day10},$percent{day15}, $percent{day20}, $percent{day30} ];

push @work_respond_data, [ 0,$percent_respond{hour},$percent_respond{hour2},
    $percent_respond{hour6},$percent_respond{hour18},$percent_respond{day},
    $percent_respond{day2},$percent_respond{day3},$percent_respond{day4},
    $percent_respond{day5},$percent_respond{day6},$percent_respond{day7},
    $percent_respond{day10},$percent_respond{day15},
    $percent_respond{day20}, $percent_respond{day30} ];

#dump requester stats to another file that is NOT included in the webpages!
open(SSI, ">$outpath/results-notshown.ssi") or die $!;
print SSI "           Requester  1wk  1mn  3mn  6mn  1yr  2yr\n";
foreach $requester ( reverse sort by_number keys(%requesters) ) {
    printf SSI "%20s %4d %4d %4d %4d %4d %4d\n", $requester,$count2{week}{$requester},$count2{month}{$requester},$count2{qtr}{$requester},$count2{semi}{$requester},$count2{year}{$requester},$count2{yeartwo}{$requester};
}
close(SSI);


#Lastly create some graphs

#Line plot of percentage of tickets with a human response in less than 
#certain time
$graphopts{'title'} = "First response time in elapsed working hours";
create_graph('%','plot0.png',@work_respond_data);

#Line plot of percentage of tickets resolved in less than certain time
$graphopts{'title'} = "Issue resolution time in elapsed working hours";
create_graph('%','plot1.png',@work_data);

#Line plot of tickets resolved in given periods
$y_max = 100*( int( $totalcount{'yeartwo'}{'Total'}/100 )+1) ;
$graphopts{'y_max_value'} = $y_max;
$graphopts{'title'} = "Number resolved per reporting period";
create_graph('Number resolved','plot2.png',@periods_data);

#Line plot of average time to resolve in periods
$y_max = 2*(int($av_max/2)+1);
$graphopts{'y_max_value'} = $y_max;
$graphopts{'title'} = "Average resolution working time by reporting period";
create_graph('working days','plot3.png',@periodsav_data);

#disconnect and exit
$dbh->disconnect;

open(SSI, ">$outpath/rt-plots-response.html") or die $!;
print SSI $htmlheader;



print SSI "<h3> 
Percentage of requests getting a first human response in a given working time
</h3>\n";

print SSI "<img src=plot0.png /> <br> <hr>";

print SSI "<h3> Percentage of requests resolved in a given working time 
</h3>\n";
print SSI "<img src=plot1.png /> <br><hr>";

print SSI "<h3> Requests resolved by period </h3>";
print SSI "<img src=plot2.png /> <br><hr> ";

print SSI "<h3> Average number of working days to resolve requests by period
</h3>\n";
print SSI "<img src=plot3.png /> <br><hr> ";

print SSI $htmlfooter;
close (SSI);

print "outpath: $outpath\n";

exit 0;
