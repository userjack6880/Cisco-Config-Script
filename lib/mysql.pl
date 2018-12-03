use DBI;

# initialize variable
$db_connected = 0;
our $dbh;

# functions

# connect db
sub db_connect{
	my $database = shift;
	my $username = shift;
	my $password = shift;
	$username = ($username) ? $username : $conf{'mysql_user'};
	$password = ($password) ? $password : $conf{'mysql_pass'};

	$dbh = DBI->connect("DBI:mysql:" . $database,  $username,$password) or return 0;
	return 1;
}

# disconnect db
sub db_disconnect{
	if ($dbh){
		$dbh->disconnect();
		return 1;
	}
	return 0;
}

# query the db
sub db_query{
	my $query = shift;
	if (!$dbh){
		db_connect();
	}
	my @result = ();
	my $select = $dbh->prepare($query);

	$select->execute() or warn ("problem with query $!");
	$tempval = $select->fetchrow_hashref();
	if ($tempval){
		return $tempval;
	}
	return undef;
}

# do multiple db queries
sub db_query_multiple{
	my $query = shift;
	if (!$dbh){
		db_connect();
	}

	my $select = $dbh->prepare($query);

	if (!$select->execute()){
		warn "Problem with query: $!\n";
		return @results;
	}

	while ($tempval = $select->fetchrow_hashref()){
		push @results, $tempval;
	}
	return @results;
}

# db do
sub db_do{
	my $action = shift;
	if (!$dbh){
		db_connect() or return -1;
	}
	my $retval = $dbh->do($action) or print $DBI::errstr;
	return $retval;
}

# db errors
sub db_error{
	if (!$dbh){
		return "";
	}
	return $dbh->errstr;
}

# db last inserted id
sub db_last_insert_id{
	if (!$dbh){ 
		return -1;
	}
	return $dbh->{'mysql_insertid'};
}

# make it true!
1;
