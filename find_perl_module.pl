#!/usr/bin/perl

my $numargs=scalar @ARGV;
my $Command="/usr/bin/perl";
my $PerlVer="5.14.2";
my $Module=$ARGV[0];

$PerlVer=$ARGV[1];

sub validate
{
   if(1>scalar @ARGV)
   {
        print STDERR <<EOF;

Prints Path of Module loaded:

Usage: $0 <Module_Name> [<Perl_Version>]
        Module_Name  : Name of Module to search
        Perl_Version : Perl Version to search for should be one of 5.0/ 5.8 /5.10 /5.14

EOF
        exit(1);
   }
}
####################### Main ######################
&validate();
$Command = "/usr/bin/perl";

$b="$Command -M'$Module' -e 'use Data::Dumper; print Dumper ".'\%INC'."' 2>/dev/null";
$rv=system("$b");

if($rv != 0) {
  print "\n Failed: Module could not be located with Perl version $PerlVer\n\n";
}

####################################################

