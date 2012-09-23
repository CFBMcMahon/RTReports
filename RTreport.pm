

=pod


=head1 RTreports.pm

First attempt at using a module for some of the support subroutines


Conall McMahon (email address here)


=head1 ACKNOWLEDGMENTS


=head1 SEE ALSO


=head2 CHANGES


=back

=cut


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

use strict;

# 2012091-rgm: turned off since loads of warnings 
#use warnings;

package RTreport;

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

    
1;		     
