#!/usr/bin/env perl
=h

=cut
use strict;
use Net::FTP;
use Fatal qw(open close);
if(!$ENV{"EVE_HOME"}){
		die "You must set EVE_HOME first\n";
}
my $eve_home = $ENV{"EVE_HOME"};
my $string="ftp://ftp.gnu.org/gnu/";

my ($server,$user,$pass,$directory);
if($string=~/^ftp:\/\/(?:([^:\@]+):([^\@]+)\@)?([^\/]+)\/(\S+)/){
		($server,$user,$pass,$directory)=($3,$1,$2,$4);
		$directory="./$directory";
		$user = "anonymous" if $user eq "";
		$pass = '-anonymous@' if $pass eq "";
}
my $ftp = Net::FTP->new($server, Timeout => 30)
		or die "Can not connect to $server : $@\n";
$ftp->login($user, $pass)
		or die "Can not login using credentials : $@\n";
$ftp->binary()
		or die "Can not switch to binary mode : $@\n";
$ftp->cwd($directory)
		or die "Can not change directories to $directory : $@\n";
my @files = $ftp->dir();
open O,">$eve_home/conf/gnu.packages";
foreach my $file (@files) {
		my @l=split /\s+/,$file;
		next if substr($l[0],0,1) ne 'd';
		next if !islower(substr($l[-1],0,1));
		next if $l[-1] =~/archive/;
		print O "$l[-1]\tgnu $l[-1]\tftp://ftp.gnu.org/gnu/$l[-1]/\t0\tlatest:tar\\.[g|l|x|b]z2?\$|wget\ttar|conf|inst\n";
}
close O;
$ftp->close();
sub islower(){
		my $c=shift;
		return $c ge 'a' && $c le 'z';
}			 


