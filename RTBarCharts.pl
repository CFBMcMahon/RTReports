# $Id: charts_byqueue_users_byowner.pl,v 1.1 2012/08/01 16:28:59 rgm Exp $
#!/usr/bin/perl

# BEWARE: This is a slow query

# rgm added min and max range calc for tickets
# rgm adding a summary txt file output that records the number if outstanding
# and unresolved tickets
   
# Original: v0.5: Ryan Armanasco - 2009-12-08 - ryan@slowest.net
# 
#   
# maybe limit also to tickets not created bu users
# also support for select by group for owner or requestor
#
#
#
#
# Extract queue statistics from RT and generate Google Charts call to graph
#
# example graph: http://tinyurl.com/yk6lw63
#
# Produces stats for specified number of months, optionally including the 
# current month,
# showing created, resolved and overall outstanding at the point in time for that month.
#
# Reopened and re-resolved tickets will skew the figures slightly.
#
# It has to do a lot of database work, and it take a fair while depending 
# on the size of your database
#
# Indicative stats:
#   to produce a 16 month cycle on a 4500 record database.  
#   ESX clustered host with 3GHz Xeon, 2GB RAM = 6.5 seconds
   
use strict;

use DBI;
use Getopt::Long;
use File::Path;
use IO::Handle qw( );  # For flush
use List::Util qw[min max];
use Config::Simple;

use Sys::Hostname;
my $hostname = hostname;
print 'Hostname: ',$hostname, "\n";

my %config;
Config::Simple->import_from( 'RTconfig.ini', \%config) or die Config::Simple->error();

my $host = $config{host};
my $db = $config{database};
my $user = $config{username};
my $pass = $config{password};
my $type = $config{type};
my $outpath = $config{outpath};

print 'Running: ',$0, "\n";
use Cwd 'abs_path';

print 'Running: ',abs_path($0), "\n";
print 'username: ',getlogin(), "\n";
use Cwd;

print 'Current working directory: ',getcwd(), "\n";

my $verbose;
my $debug;
GetOptions ('debug' => \$debug,
            'verbose' => \$verbose);
if ($debug or $verbose) {print 'Verbose is true', "\n";}
if ($debug)   {print 'Debug is true', "\n";}

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $datestamp = sprintf("%04d%02d%02d",$year+1900,$mon+1,$mday);
my $yearstamp = sprintf("%04d",$year+1900);
my $monthstamp = sprintf("%02d",$mon+1);
my $daystamp = sprintf("%02d",$mday);

my $timestamp = sprintf("%04d%02d%02d-%2d:%2d:%2d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
print 'datestamp: ',$datestamp,"\n";   
print 'timestamp: ',$timestamp,"\n";    

# SETTINGS - CUSTOMISE THESE


   # DATABASE - CUSTOMISE THESE

   my $dbh = DBI->connect("dbi:$type:".$db.';host='.$host,$user,$pass)
   or die "Connection Error: $DBI::errstr\n";

my $start_date;
$start_date=$yearstamp . '-' . $monthstamp;
#$start_date="2012-03";
#$start_date="2010-12";
#$start_date="2011-12";

print "start_date: $start_date\n";

my $outpath = '/home/conall/';
#my $outpath = '/home/rgm/public_html/coc/rt-metrics/2010/';
#my $outpath = '/home/rgm/public_html/coc/rt-metrics/2011/';

my $outpath_archive = $outpath . 
  $yearstamp . '/' . $datestamp . "/";

if (-e $outpath || $verbose) {print 'Directory already exists: ' . $outpath . "\n"};
unless (-e $outpath) {
  if ($verbose) {print 'Creating: $outpath\n'};
  unless (mkpath($outpath)) {die "Unable to create $outpath\n"};
}

if (-e $outpath_archive || $verbose) 
  {print 'Directory already exists: ' . $outpath_archive. "\n"};
unless (-e $outpath_archive) {
  if ($verbose) {print 'Creating: $outpath\n'};
  unless (mkpath($outpath_archive)) {die "Unable to create $outpath_archive\n"};
}

my $htmlfile = 
    '>' . $outpath . 'charts_byqueue_users_byowner.html';
print 'current file: ',$htmlfile,"\n";

my $htmlfile_archive = 
    '>' . $outpath_archive . 'charts_byqueue_users_byowner.html';
print 'archive file: ',$htmlfile_archive,"\n";


# create filehandles for output plot files
OUTFILE->autoflush(1);
OUTFILE2->autoflush(1);
open (OUTFILE, $htmlfile);
open (OUTFILE2, $htmlfile_archive);
OUTFILE->autoflush(1);
OUTFILE2->autoflush(1);

my $currentstatusfile = "$outpath/byqueue_users_current_status.txt";

if (-e $currentstatusfile || $verbose) 
  {print 'Directory already exists: ' . $currentstatusfile. "\n"};
unless (-e $currentstatusfile) {
  if ($verbose) {print 'Creating: $currentstatusfile\n'};
  unless (mkpath($currentstatusfile)) {die "Unable to create $currentstatusfile\n"};
}
open(STATUSFILE, $currentstatusfile) or die $!;

   my $queue='Purchasing'; # RT queue to operate on
   my $queue='Change Control'; # RT queue to operate on
   my $queue='Informational'; # RT queue to operate on
   my $queue='IoA'; # RT queue to operate on

   my $queue='Informational'; # RT queue to operate on

   my @queues = (q('Change Control'), q('IoA'), q('Purchasing'), q('Informational') ); # works

my @queues = (q('%'), q('IoA'), q('Purchasing'), 
     q('Web Development'), q('Old Web Development'), 
     q('Informational'),q('Change Control'), q('Planning'), 
     q('Mini-projects'),q('Major Projects'),
     q('GAIA'),q('Kavli'),q('General'),
     q('Beltane'),q('Action Items')); # works

my @queues = (q('%'), q('IoA'), q('Purchasing'));
#my @queues = (q('%'), q('IoA'));
my @queues = (q('IoA'));
#my @queues = (q('IoA'), q('Purchasing'));
#my @queues = (q('Informational') ); # works
#my @queues=(q('Planning')); # RT queue to operate on
#my @queues=(q('%')); # RT queue to operate on



my @owners = (q('adb'), q('gbell'), q('nrm'),q('sc'),q('atb'),q('hss'));
my @owners = (q('adb'), q('gbell'), q('nrm'),q('sc'));
my $user = 'rgm';
my $owner = q('%');
my @owners = (q('%'),q('adb'), q('gbell'), q('nrm'),q('sc'),q('atb'),q('hss'));
# 2012-12-12: rgm added rmj
my @owners = (q('%'),q('adb'), q('gbell'), q('nrm'),q('sc'),q('rmj'));


my $cycles=12; # how many months to report on
my $thismonth=1; # include current month in graph?

my $test=1;
my $test=0;
#$test=1;
if ($test) {$cycles=6};
   
   
   # GRAPH DIMENSIONS - CUSTOMISE THESE
   #   (340,000 [X x Y] pixel maximum)
   my $chartx=850;
   my $charty=350;
   die "Chart area $chartx * $charty is greater than 340,000 pixles - google will reject it\n" if $charty * $chartx > 340000;
   
   #====================================================
   # DON'T TOUCH ANYTHING BELOW HERE
   #====================================================
   
   # friendly month names for labels/titles
   my @months = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
   
   # connect to RT database
   
   my $data; # stores all returned/calulcated ticket stats - hashref
   my $max=0; # tracks maximum value to scale graph
   my $end_date; # track ending time period for labels
   my @perc; # percentage calculation during output
 

   
# generate the decending year/month combos 
# - previous `date --date="x months ago" has issues on the first 
#   day of the month, so here's a more fool-proof version.
   sub makedate {
         my $ddate = shift;
         my $doffset = shift;
         my $year;
         my $month;

         #print "ddate:", $ddate,"\n";
         #print "doffset:", $doffset,"\n";
         #print "year:",$year,"\n";
         #print "month:",$month,"\n";

         $doffset--;
 
         $ddate =~ /(\d\d\d\d)-(\d\d)/;
                 $year = $1;
                 $month = $2;
 
         for(0..$doffset) {
                 $month--;
                 if ($month == 0) {
                         $month = 12;
                         $year--;
                 }
                 if (length($month) ==1) {
                         $month = "0".$month;
                 }
         }
 
         if ($doffset == -2) {
                 $month++;
                 if ($month == 13) {
                         $month = 1;
                         $year++;
                 }
                 if (length($month) ==1) {
                         $month = "0".$month;
                 }
         }
         #print "\n";
         #print "year:  ", $year,"\n";
         #print "month: ", $month,"\n";
         #print "$year-$month-","\n";
         return "$year-$month";
   }
   

my $status=q('%requestor%');
my $status=q('null');
my $status=q('%');
#my $status='null';
# loop through owners
foreach my $owner (@owners) {
# loop through queues
foreach my $queue (@queues) {
    my $graphtitle="Request Tracker $queue Queue:"." $owner". " requestor:users";
    my $max=0;

   # reset counters each loop
   my $created=0;
   my $total_created=0;
   my $average_created=0;
   my $min_created=0;
   my $max_created=0;

   my $outstanding=0;
   my $total_outstanding=0;
   my $average_outstanding=0;
   my $min_outstanding=0;
   my $max_outstanding=0;

   my $resolved=0;
   my $total_resolved=0;
   my $average_resolved=0;
   my $min_resolved=0;
   my $max_resolved=0;


   my $unresolved=0;

   # loop through requested month range
   for (1..$cycles) {

   # reset counters each loop
   	my $created=0;
   	my $outstanding=0;
   	my $resolved=0;

   	# lazy way to work out x months before present
   	my $offset=$_;
   	$offset -= 1 if $thismonth;
   	# existing faulty version: my $date = `date --date="$offset months ago" +"%Y-%m"`;
   	# existing faulty version: chomp($date);
        my $date = makedate($start_date,$offset);
 
   	# store info for label generation
   	$data->{date}[$_-1]=$date;
   
   			
   	# CREATED TICKET STATS
        # count(DISTINCT effectiveID)        
   	my $sql = "
   		select
                        count(DISTINCT ti.effectiveID)        
   		from
   			Tickets ti,
                        Queues qu,
                        Users users,
                        Groups gr,
                        CachedGroupMembers cgm,
                        Principals pr,
                        (SELECT 
                           ti.id 
                         FROM
                           Tickets ti,
                           Users users
                         WHERE
                           ti.owner = users.id 
                           AND users.name like $owner) s1
   		where
                        ti.id = s1.id AND
                        ti.id = gr.Instance AND
                        gr.Type = 'Requestor' AND
                        gr.id = cgm.GroupId AND
                        pr.id = cgm.MemberId AND
                        users.id = pr.id AND
                        users.Name not like 'adb' AND   
                        users.Name not like 'atb' AND   
                        users.Name not like 'sc' AND   
                        users.Name not like 'nrm' AND   
                        users.Name not like 'hss' AND   
                        users.Name not like 'gbell' AND 
                        users.Name not like 'rmj' AND     
                        users.Name not like 'helpdesk%' AND   
                        users.Name not like 'reporter%' AND   
                        users.Name not like 'MaiLnX%' AND   
   			ti.queue = qu.id AND
                        qu.name like $queue AND  
                        ti.status like $status AND  
   			ti.created like '$date%';";

        print "sql:",$sql,"\n";
        print "\n";

   	# execute and retrieve
         my $sth = $dbh->prepare($sql);
         $sth->execute();
   	$created = ($sth->fetchrow_array)[0];
   
   	# RESOLVED TICKET STATS
   	my $sql = "
   		select
   		  count(distinct tr.objectid) as resolved,
   		  round(max(datediff(ti.resolved,ti.created))) as maxage,
   		  round(avg(datediff(ti.resolved,ti.created))) as avgage
   		from
   		  Transactions tr,
   		  Tickets ti,
                  Queues qu,
                  Users users,
                  Groups gr,
                  CachedGroupMembers cgm,
                  Principals pr,
                        (SELECT 
                           ti.id 
                         FROM
                           Tickets ti,
                           Users users
                         WHERE
                           ti.owner = users.id 
                           AND users.name like $owner) s1
   		where
                        ti.id = s1.id AND
                       ti.id = gr.Instance AND
                        gr.Type = 'Requestor' AND
                        gr.id = cgm.GroupId AND
                        pr.id = cgm.MemberId AND
                        users.id = pr.id AND
                        users.Name not like 'adb' AND   
                        users.Name not like 'atb' AND   
                        users.Name not like 'sc' AND   
                        users.Name not like 'nrm' AND   
                        users.Name not like 'hss' AND   
                        users.Name not like 'rmj' AND   
                        users.Name not like 'gbell' AND   
                        users.Name not like 'helpdesk%' AND   
                        users.Name not like 'reporter%' AND   
                        users.Name not like 'MaiLnX%' AND   
   			  ti.queue = qu.id 
                        and
                            qu.name like  $queue
                        and
   				tr.type='Status'
   			and
   			   (tr.newvalue='resolved' or tr.newvalue='deleted')
   			and
   				tr.objecttype='RT::Ticket'
   			and
   				tr.objectid = ti.effectiveid
   			and
   				tr.created like '$date-%';";
   
   		# returns this
   		#+---------+--------+---------+
   		#| tickets | maxage | avgage  |
   		#+---------+--------+---------+
   		#|     107 |    192 | 18.8692 |
   		#+---------+--------+---------+
   
        #print $sql;
   	# execute and retrieve
   	my $sth = $dbh->prepare($sql);
   	$sth->execute();
   	($resolved, $data->{max}[$_-1], $data->{avg}[$_-1]) = ($sth->fetchrow_array);
   

   	# RESOLVED TICKET STATS
   	my $sql = "
   		select
   		  count(distinct tr.id) as unresolved
   		from
   		  Transactions tr,
   		  Tickets ti,
                  Queues qu,
                  Users users,
                  Groups gr,
                  CachedGroupMembers cgm,
                  Principals pr,
                        (SELECT 
                           ti.id 
                         FROM
                           Tickets ti,
                           Users users
                         WHERE
                           ti.owner = users.id 
                           AND users.name like $owner) s1
   		where
                        ti.id = s1.id AND
                       ti.id = gr.Instance AND
                        gr.Type = 'Requestor' AND
                        gr.id = cgm.GroupId AND
                        pr.id = cgm.MemberId AND
                        users.id = pr.id AND
                        users.Name not like 'adb' AND   
                        users.Name not like 'atb' AND   
                        users.Name not like 'sc' AND   
                        users.Name not like 'nrm' AND   
                        users.Name not like 'hss' AND   
                        users.Name not like 'rmj' AND   
                        users.Name not like 'gbell' AND   
                        users.Name not like 'helpdesk%' AND   
                        users.Name not like 'reporter%' AND   
                        users.Name not like 'MaiLnX%' AND   
   			  ti.queue = qu.id 
                        and
                            qu.name like  $queue
                        and
   				tr.type='Status'
   			and
   			   (tr.newvalue='resolved' or tr.newvalue='deleted')
   			and
   				tr.objecttype='RT::Ticket'
   			and
   				tr.objectid = ti.effectiveid
   			AND tr.created like '$date-%'
                        AND ti.status not like 'resolved'
                        AND ti.status not like 'rejected'
                        AND ti.status not like 'deleted';";
   
   
        #print $sql;
   	# execute and retrieve
   	my $sth = $dbh->prepare($sql);
   	$sth->execute();
   	$unresolved = $sth->fetchrow_array;
   
           # need to step date forward a month to get accurate figures
     	   # previous faulty version: my $offset=$_ - 1;
           # previous faulty version: $offset -= 1 if $thismonth;
           # previous faulty version: my $dateforward = `date --date="$offset months ago" +"%Y-%m"`;
           # previous faulty version: chomp($dateforward);
           my $dateforward = makedate($start_date, ($offset-1) );
   
   	# OUTSTANDING TICKET STATS
   	my $sql = "
   		select
   			count(*) as tickets
   		from
   			Transactions tr,
   			Tickets ti,
                        Queues qu,
                        Users users,
                  Groups gr,
                  CachedGroupMembers cgm,
                  Principals pr,
                        (SELECT 
                           ti.id 
                         FROM
                           Tickets ti,
                           Users users
                         WHERE
                           ti.owner = users.id 
                           AND users.name like $owner) s1
   		where
                   ti.id = s1.id AND
                       ti.id = gr.Instance AND
                        gr.Type = 'Requestor' AND
                        gr.id = cgm.GroupId AND
                        pr.id = cgm.MemberId AND
                        users.id = pr.id AND
                        users.Name not like 'adb' AND   
                        users.Name not like 'atb' AND   
                        users.Name not like 'sc' AND   
                        users.Name not like 'nrm' AND   
                        users.Name not like 'hss' AND   
                        users.Name not like 'rmj' AND   
                        users.Name not like 'gbell' AND   
                        users.Name not like 'helpdesk%' AND   
                        users.Name not like 'reporter%' AND   
                        users.Name not like 'MaiLnX%' AND   
   			  ti.queue = qu.id 
                        and
                        qu.name like  $queue
                        and  
   				tr.type='Create'
   			and
   				tr.objecttype='RT::Ticket'
   			and
   				tr.objectid = ti.effectiveid
   			and
   				ti.created < '$dateforward'
   			and not
   				tr.objectid in 	(
   						select
   							distinct tr.objectid
   						from
   							Transactions tr,
   							Tickets ti
   						where
   								tr.type='Status'
   							and
   								tr.newvalue='resolved'
   							and
   								tr.objecttype='RT::Ticket'
   							and
   								tr.objectid = ti.id
   							and
   								tr.created < '$dateforward'
   						)
   
   			and
   				tr.objectid not in 	(
   							select
   								id
   							from
   								Tickets
   							where
   									id <> effectiveID
   							)
   			and not
   				tr.objectid in (
   						select
   							id
   						from
   							Tickets
   						where
   								resolved < '$dateforward'
   							and not
   								resolved = '1970-01-01 00:00:00'
   						)
   			and
   				ti.type <> 'reminder'
   		order by tr.objectid";
   
   	# execute and retrieve
         my $sth = $dbh->prepare($sql);
         $sth->execute();
   	$outstanding = ($sth->fetchrow_array)[0];
   
        print "\n";
        print "dateforward: ", $dateforward,"\n";
        print "created: ", $created,"\n";
        print "outstanding: ", $outstanding,"\n";
        print "resolved: ", $resolved,"\n";

   	# store all the data somewhere
   	#if ($created < 1) { $created = 1 };
   	$data->{cre}[$_-1] = $created;
   	$data->{outstanding}[$_-1] = $outstanding;
   	$data->{resolved}[$_-1] = $resolved;
   	$data->{created}[$_-1] = $created;

        $total_created = $total_created + $created;
        $total_resolved = $total_resolved + $resolved;
        $total_outstanding = $total_outstanding + $outstanding;

        if ($created > $max_created) { $max_created = $created};
        if ($created < $min_created) { $min_created = $created}; 


   
   	if ($created > $resolved) {
   		$max = $created if $created > $max;
   	} else {
   		$max = $resolved if $resolved > $max;
   	}

   	if ($outstanding > $max) { $max = $outstanding };

   }
   
   $max = int($max * 1.10);
   $max = $max + 10 + (50-($max % 50));
   print "\$max: ",$max,"\n";
   
   $max_created=

   $average_created = $total_created / $cycles;
   $average_resolved = $total_resolved / $cycles;
   $average_outstanding = $total_outstanding / $cycles;

   # fill array with average values
   for (1..$cycles) {
     $data->{average_created}[$_-1] = $average_created;
     $data->{average_resolved}[$_-1] = $average_resolved;
     $data->{average_outstanding}[$_-1] = $average_outstanding;
   }


my @created = @{$$data{'created'}};  
$min_created= min($data->{created});
$max_created= min($data->{created});

$min_resolved= min($data->{resolved});
$max_resolved= min($data->{resolved});

$min_outstanding= min($data->{outstanding});
$max_outstanding= min($data->{outstanding});


print "\n";
print $average_created, " :", $total_created, " :", $cycles, "\n";
print "Monthly created range: ", $min_created, $max_created, "\n";

print $average_resolved, " :", $total_resolved, " :", $cycles, "\n";
print $average_outstanding, " :", $total_outstanding, " :", $cycles, "\n";

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $timestamp = sprintf("%04d%02d%02d-%2d:%2d:%2d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
print 'timestamp: ',$timestamp,"\n";    

print OUTFILE '<img src="';
print OUTFILE2 '<img src="';   

# http://code.google.com/apis/chart/image/docs/chart_params.html

print OUTFILE <<GRAPH;
http://chart.apis.google.com/chart?
cht=bvg
&chs=${chartx}x${charty}
&chbh=a
&chds=0,$max
&chco=0033ff,1eec44,e00a0a,c342bb
&chm=N,000000,0,-1,11|N,000000,1,-1,11|N,000000,2,-1,11|D,c342bb,3,0,4,-1
&chts=000000,20
&chf=bg,s,FFFFFF,s,FFFFFF
&chma=30,40,50,50|100,20
&chxt=x,y,r,x,x,x,x,x,x
&chdl=created|resolved|outstanding
&chtt=$graphtitle
&chxl=0:|
GRAPH

print OUTFILE2 <<GRAPH;
http://chart.apis.google.com/chart?
cht=bvg
&chs=${chartx}x${charty}
&chbh=a
&chds=0,$max
&chco=0033ff,1eec44,e00a0a,c342bb
&chm=N,000000,0,-1,11|N,000000,1,-1,11|N,000000,2,-1,11|D,c342bb,3,0,4,-1
&chts=000000,20
&chf=bg,s,FFFFFF,s,FFFFFF
&chma=30,40,50,50|100,20
&chxt=x,y,r,x,x,x,x,x,x
&chdl=created|resolved|outstanding
&chtt=$graphtitle
&chxl=0:|
GRAPH


   
   # x axis MMM 'YY labels
   foreach my $label (reverse(@{$data->{date}})) {
   	$label =~ /\d\d(\d\d)-(\d\d)/;
   	print OUTFILE "$months[$2-1] '$1|","\n";
   }

   # x axis MMM 'YY labels
   foreach my $label (reverse(@{$data->{date}})) {
   	$label =~ /\d\d(\d\d)-(\d\d)/;
   	print OUTFILE2 "$months[$2-1] '$1|","\n";
   }


   # graphs scalings/axis require some calculations
   print OUTFILE '|1:|0|'.sprintf('%2d',($max/2))."|$max","\n";
   print OUTFILE2 '|1:|0|'.sprintf('%2d',($max/2))."|$max","\n";

   #print OUTFILE '|2:|0|50|100',"\n";

   print OUTFILE '|2:|0|'.sprintf('%2d',($max/2))."|$max","\n";
   print OUTFILE2 '|2:|0|'.sprintf('%2d',($max/2))."|$max","\n";

   #print OUTFILE '|3:|',"\n";
   print OUTFILE '|3:|'.'|'x(($cycles/2)-1).'|Average(Total) created: ', int($average_created+0.5)," (", $total_created,")", "[range:",$min_created,$max_created,"]","\n";
   print OUTFILE2 '|3:|'.'|'x(($cycles/2)-1).'|Average(Total) created: ', int($average_created+0.5)," (", $total_created,")", "[range:",$min_created,$max_created,"]","\n";

   print OUTFILE '|4:|'.'|'x(($cycles/2)-1).'|Average(Total) resolved: ', int($average_resolved+0.5)," (", $total_resolved,")","\n";
   print OUTFILE2 '|4:|'.'|'x(($cycles/2)-1).'|Average(Total) resolved: ', int($average_resolved+0.5)," (", $total_resolved,")","\n";

   print OUTFILE '|5:|'.'|'x(($cycles/2)-1).'|Average outstanding: ', int($average_outstanding+0.5),"\n";
   print OUTFILE2 '|5:|'.'|'x(($cycles/2)-1).'|Average outstanding: ', int($average_outstanding+0.5),"\n";


   print OUTFILE '|6:|'.'|'x(($cycles/2)-1).'|Average resolved ticket age (days)',"\n";
   print OUTFILE2 '|6:|'.'|'x(($cycles/2)-1).'|Average resolved ticket age (days)',"\n";

   print OUTFILE '|7:|'.join('|',reverse(@{$data->{avg}})),"\n";
   print OUTFILE2 '|7:|'.join('|',reverse(@{$data->{avg}})),"\n";

   print OUTFILE '|8:|' . '|'x(($cycles/2)-1) . '| Created on: ' . $timestamp . '  with: ' . abs_path($0) .': '.$hostname, "\n";
   print OUTFILE2 '|8:|' . '|'x(($cycles/2)-1) . '| Created on: ' . $timestamp . '  with: ' . abs_path($0) .': '.$hostname, "\n";

   # output the data sets
   # chd=t3: => 
   print OUTFILE "&chd=t3:","\n";
   print OUTFILE2 "&chd=t3:","\n";

   #for (0..$cycles-1) { $perc[$_] = sprintf('%2d',($max-2)/100*(($data->{ctd}[$cycles-1-$_]-$data->{out}[$cycles-1-$_])/$data->{ctd}[$cycles-1-$_]) * 100 ); }

   print OUTFILE join(',',reverse(@{$data->{created}})),"\n";
   print OUTFILE2 join(',',reverse(@{$data->{created}})),"\n";

   print OUTFILE '|'.join(',',reverse(@{$data->{resolved}})),"\n";
   print OUTFILE2 '|'.join(',',reverse(@{$data->{resolved}})),"\n";

   print OUTFILE '|'.join(',',reverse(@{$data->{outstanding}})),"\n";
   print OUTFILE2 '|'.join(',',reverse(@{$data->{outstanding}})),"\n";

   #print OUTFILE '|'.join(',',@perc),"\n";

   print OUTFILE '"',"\n","border=1 />","\n";
   print OUTFILE2 '"',"\n","border=1 />","\n";

print STATUSFILE $queue, $owner, $created, $resolved, $unresolved, $outstanding, "\n";

  } # queue loop

} # owner loop

close(STATUSFILE);
close (OUTFILE);
close (OUTFILE2);
   
exit;
   
   
