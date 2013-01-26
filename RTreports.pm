=pod

=head1 NAME

RTreports - support functions for RT reporting scripts

=head1 SYNOPSIS

These are support functions used by the RT reporting scripts

=head1 DESCRIPTION OF METHODS 

=over 

=item owner("query", "owner_name")

Returns SQL query string beginning argument with owner_name placed at beginning

=item not_requestors("query", @requestors_to_be_excluded)

Returns SQL query string appended with excluded requestor(s). 


=item limit_by_time("query", @time_span_string_list)

Returns SQL query string with appended time span, to know which arguments 
will work, see the method itself. Unless you know what you are changing, 
just leave the programme alone. 


=item not_status("query", @status_string_list)

Returns SQL query string with appended statuses to be excluded. 
Please change arguments in config file


=item add_queue("query", @queue_string_list)

Returns SQL query string with queue limiter appended. Currently only one 
queue can be specified and used


=item add_status("query", @status_string_list)

Returns query string with appended statuses to be included. Please change arguments in config file


=item spec_status("query", "status to be included", @status_string_list)

Returns query string with one appended status to be included and any number of statuses to be excluded. Avoid this method unless absolutely necessary


=item get_RTserver()

Returns the version number of RT running on the server


=back


=head1 AUTHOR

Conall McMahon (mc_mahon@hotmail.co.uk)


=head1 ACKNOWLEDGMENTS


=head1 SEE ALSO


=head1 CHANGES

=over

=item 20130107-cfm: added $VERSION 

=item 2013-01-07-cfm: added get_RTserver function to get the RT version 
of the server

=item 2012-09-02-rgm: turned off warnings since loads of warnings 

=item 2012-09-01-cfm: module version based on code from main program

=back

=cut

use strict;
#use warnings;

package RTreports;

# version number accessible as $RTreports::VERSION
# e.g. print 'RT version: $RTreports::VERSION\n';
our $VERSION = "0.4.1";

sub owner {
    my $query = shift(@_);
    foreach my $owner (@_){
	#print $new_owner , "\n";
	if ($owner =~ m/^%$/){
	    $query =~ s/^/owner LIKE '%'/;
	} else {
	    $query =~ s/^/owner = '$owner'/;
	}
	$query;
    }
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
    my($query, $time) = (@_[0], @_[1]);
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
	unless ($query eq ""){ 
	    $query .= " AND status != '$_'";
	}
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
     my $build;
     $build = " AND " if $query;
     my $start = shift(@_);
	 
     if($start eq '%'){
	 $build .= "(queue LIKE '%'";
     }else{
	 $build .= "(queue = '$start'";
     
	 foreach(@_){
	    $build .= " OR queue = '$_'";
  	 }
     
	 $build .= ") ";
	 return $query .= $build;
     }
}
    
sub spec_status {
    my $query = shift(@_);
    my $add = shift(@_);
    $query = &add_status($query, $add);
    $query = &not_status($query, @_);
    $query;
}

sub get_RTserver {
    use LWP::Simple;
    my $URL_REST = shift(@_);
    my $response = get($URL_REST) or die "Unable to get RTserver page at $URL_REST\n";

    # locate the RT server version before the 401 error string
    my $pos=index($response, '401');
    $response = substr($response, 3, $pos-4); 

    my $version = $response;
    return $version;
}
    
