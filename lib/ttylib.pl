#-----
# ttylib.pl - small collection of functions for making interactions with a 
#             terminal more pleasant. 
#----

use Term::ReadKey;
my $CLS_STR;

sub center_str{
  my $str = shift;
  my $max = shift;
  my $strlen = length $str;
  if ($strlen > $max){
   return substr($str,0,$max);
  }
  my $rem = int((  $max - $strlen) / 2);
  my $padding = " " x $rem;
  return $padding . $str;
}

sub clear_screen{
  if (!$CLS_STR){
    $CLS_STR = `clear`;
  }
  print $CLS_STR;
}

sub double_check{
 my ($alert,$type,@valid_values) = @_;
 my $valid = 0;
 my $value = "";
 while (!$valid){
   $value = prompt($alert,$type,@valid_values);
   $valid = verify($value);
 }
 return $value;
}
sub get_screen_size(){
 return split(/ /,`/bin/stty size`);
}

sub pause(){
  prompt("Press [Enter] to continue", "wait");
}

#------------------------------------------------------------------------------#
# Sub:         prompt(@)
# Description: prompts the user for input
# Parameters:  @ options (see implimentation below)
# Returns:     value inputed by user
#------------------------------------------------------------------------------#
sub prompt(@){
  my ($alert, $type, @valid_values) = @_;
  if (!$type){
    warn "Type not set in prompt!\n";
    return;
  }
  if ( $type =~ /^bool$/ ){ 
    $alert .= " (y,n): ";
  }elsif ($type =~ /^default$/){
    my $default = $valid_values[0];
    if ($default ne ""){
      $alert .= " (default: \'$default\'): ";
    }
  }else{
    $alert .= ": ";
  }

  
  my $returnval = 0;
  my $VALID = 0;
  my $READY = 0;
  while (!$READY){
    print $alert;
    if ($type =~/^password$/){ system "/bin/stty -echo" if (-t STDIN); }
    chomp($returnval = <STDIN>);
    if ($type =~/^password$/){ 
      system "/bin/stty echo" if (-t STDIN); 
      print "\n";
      if ($returnval ne ""){ 
        return $returnval; 
      }
      next;
    }
    if( $type =~ /^text$/ ){
      if ($returnval ne ""){ 
        return $returnval; 
      }
      next;
    }
    if ($type =~ /^int$/){
       if($returnval =~ /^\-?\d+$/){
         $returnval =~ s/\s//;
         return $returnval;
       }
       next;
    }  
    if ($type =~ /^int_list$/){
      if ($returnval =~ /^\d+[\,\d]+$/){
        return $returnval;
      }
      next;
    }
    if ($type =~ /^file$/){
     if (! -e $returnval){
       print "File does not exist...\n";
       next;
     }
     return $returnval;
    }
    if ($type =~ /^float$/){
       if($returnval =~ /^\d+\.?\d*$/){
        return $returnval;
       }
       next;
    }
    if ($type =~/^ip$/){
       if ($returnval =~/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/){
         return $returnval;
       }
       next;
    }
    if ($type =~ /^portrange$/){
       if ($returnval =~ m/^(gi|fa|te)\d\/\d\/\d+(\s\-\s\d+)?$/i ){
         return $returnval;
       }
       next;
    }
    if ($type =~ /^default$/ ){
      if (($returnval eq "") && ($valid_values[0] ne "")){
        return $valid_values[0];
      }
      if ($returnval ne ""){
        return $returnval; 
      }
      next;
    }
    if ($type =~ /^bool$/ ){
      if ($returnval =~ /^\s*y/i){ return 1;}
      if ($returnval =~ /^\s*n/i){ return 0;}
      next;
    }
    if ($type =~ /^wait$/){
      return 1;
    }
    if ($type =~ /^subset$/){
      foreach my $val (@valid_values){
        if ($returnval eq $val){
          return $returnval;
        }
      }
      next;
    }
  }  
    return 0;
}

sub submenu(@){
  my ($prompt, $choices, $returnvals) = @_;
  my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();
  my $seperator = "-";
  print "-" x $wchar;
  my @choices = ();
  for (my $i = 0; $i < scalar(@$choices) ; $i++){
     my $j = $i + 1;
     push @choices, $j;
     print "$j: " . $$choices[$i] . "\n";
  }
  print "-" x $wchar;
  my $subvalue = prompt($prompt,"subset",@choices);
  my $k = $subvalue - 1;
  return $$returnvals[$k];
}

sub menu{
  my (%items) = @_;
  my $action = "";
  my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();
  my $seperator = "-";
  print $seperator x $wchar;
  if (exists($items{'title'})){
    my $title = center_str($items{'title'}, $wchar);
    print $title . "\n";
    print $seperator x $wchar;
  }
  foreach my $key (sort keys %items){
    next if ($key eq "title" || $key eq "prompt");
    print $key . ".\t" . $items{$key} . "\n";
  }
  print $seperator x $wchar . "\n\n";
  my $prompt = (exists($items{'prompt'})) ? $items{'prompt'}: "Pick an action";
  while (!exists($items{$action})){
    $action = prompt($prompt, "text");
  }
  return $action;
}

sub verify($){
  my $value = shift;
  if (prompt("Is \'$value\' correct?", "bool")){
   return 1; 
  }
  return 0;
}

1;
