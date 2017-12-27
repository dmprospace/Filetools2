#!/usr/bin/perl

use Net::Telnet;
#use Strict;
#use Warnings;

my ($second, $mm, $hh, $dd, $MM, $yyyy, $dayofweek, $dayofyear, $dst) = gmtime();

$yyyy += 1900;
$MM   += 1;

my $tl=sprintf("%02d%02d%02d%02d%04d", $MM,$dd,$hh,$mm,$yyyy);
#print "\n" . $tl;

my $t, @lines;
$t= new Net::Telnet(Timeout=>2);
$t->open("192.168.1.22");
#$t->login("root","root");

$t->waitfor('/Venus login:.*$/');
$t->print("root");


@lines=$t->cmd("date");
@lines=$t->cmd("date $tl");
print @lines;
