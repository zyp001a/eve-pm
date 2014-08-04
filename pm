#!/usr/bin/env perl
=h
=cut
use strict;
no strict "refs";
use HTTP::Tiny;
use Net::FTP;
use POSIX qw(strftime);
my $cur_year = strftime "%Y",localtime();
my $cur_day = strftime "%Y%m%d",localtime();
my $mon_ref={"Jan"=>1, "Feb"=>2, "Mar"=>3, "Apr"=>4,
 "May"=>5, "Jun"=>6, "Jul"=>7, "Aug"=>8,
	 "Sep"=>9, "Oct"=>10, "Nov"=>11, "Dec"=>12};

#use File::Basename;
use File::Path qw(remove_tree);
use Fatal qw(open close);
my ($cmd,$pack,@op)=@ARGV;
my $stable_status;
my $conf_op="";
for my $op (@op){
    if($op=~/^ss(\d)/){
	$stable_status=$1;
    }
    else{
	$conf_op.=" $op";
    }
}
#stable_status: 
#	0->binary
#	1->stable
#	2->dev
#	3->local

my $useage = <<END;
Useage:
    .\/pm [ install|i | update|u | download|d | erase|e | search|s | generate|g ] package-name
END

    if(!$pack){
	die $useage;
}
if(!$ENV{"EVE_HOME"}){
    die "You must set EVE_HOME first\n";
}

my $eve_home = $ENV{"EVE_HOME"};
my $repo = "$eve_home/repo";
if($ENV{"EVE_REPO"}){
    $repo=$ENV{"EVE_REPO"};
}
my %binary_package_hash;
my %stable_package_hash;
my %dev_package_hash;
my %local_package_hash;
my $package_ref;
my %installed_packages;
my %dependencies;
my $log_file;
my $package_list="$repo/installed_package.list";
my $dependency_list="$eve_home/conf/dependencies.list";


my $is_update=0;
my $prefix;
my $stable_status_string;
my $pack_id;

my %dirs;

my $filename;
####################
#main logic
####################
&_read_list();
&_set_prefix();
if($cmd eq "install" || $cmd eq "i"){
    $is_update=0;
    &install();
}
elsif($cmd eq "download" || $cmd eq "d"){
    $is_update=0;
    &download();
}
elsif($cmd eq "update" || $cmd eq "u"){
    $is_update=1;
    &update();
}
elsif($cmd eq "erase" || $cmd eq "e"){
    &erase();
}
elsif($cmd eq "search" || $cmd eq "s"){
    &search();
}
elsif($cmd eq "generate" || $cmd eq "g"){
    &generate();
}
else{
    die $useage;
}


####################
#commands
####################
sub install(){

    my ($download_url, $download_method, $install_method) = @{$package_ref->{$pack}}[1..3];
    mkdir "$dirs{tmp}" || die "cannot mkdir $dirs{tmp}";
    &_download($download_url, $download_method);

    &_build($install_method);
    &remove_tree("$dirs{tmp}");
}
sub download(){
    my ($download_url, $download_method, $install_method) = @{$package_ref->{$pack}}[1..3];
    &_download($download_url, $download_method);
}
sub update(){
    my ($download_url, $download_method, $install_method) = @{$package_ref->{$pack}}[1..3];
    #if not new &_download($download_url, $download_method);
    &_build($install_method);
}
sub erase(){
}
sub search(){
    warn "Search $pack...\n";
    for my $ipack (sort (keys %binary_package_hash, 
												 keys %stable_package_hash,
												 keys %dev_package_hash,
												 keys %local_package_hash)){
				warn "$ipack\t$pack\n";
				my ($download_url, $download_method, $install_method) = @{$package_ref->{$ipack}}[1..3];
				if($ipack=~/$pack/){
						print $ipack,"\n";
				}
    }
}
sub generate(){
}


####################
#internal methods
####################
sub _read_list(){
    my $c=0;
    open A,"cat $eve_home/conf/*.packages |";
    while (<A>){
	chomp;
	my ($package_name, $description, $download_url, $stable_status,
	    $download_method, $install_method) = split "\t";
	if(!$package_name){ next;}
	if(!$download_url){
	    die "packages not validate:\n $_\n";
	}
	if(!$stable_status){
	    $binary_package_hash{$package_name} = 
		[$description, $download_url, 
		 $download_method, $install_method];
	}
	elsif($stable_status==1){
	    $stable_package_hash{$package_name} = 
		[$description, $download_url, 
		 $download_method, $install_method];
	}
	elsif($stable_status==2){
	    $dev_package_hash{$package_name} =
                [$description, $download_url,
                 $download_method, $install_method];
	}
	else{
	    $local_package_hash{$package_name} =
                [$description, $download_url,
                 $download_method, $install_method];
	}
	$c++;
    }
    close A;
    print "$c packages avaiable\n";
    
}
sub _set_prefix(){
    my $exist_binary=$binary_package_hash{$pack};
    my $exist_stable=$stable_package_hash{$pack};
    my $exist_dev=$dev_package_hash{$pack};
    my $exist_local=$local_package_hash{$pack};
    if(!$exist_binary && !$exist_dev && !$exist_stable && !$exist_local){
	print "$pack is not exist\n";
	&search();
	die;
    }
    elsif($exist_binary && !$stable_status){
	print "$pack, binary version is selected\n";
	$stable_status=0;
	$stable_status_string="binary";
	$package_ref=\%binary_package_hash;
    }
    elsif($exist_stable && $stable_status<=1){
	print "$pack, stable version is selected\n";
	$stable_status=1;
	$stable_status_string="stable";
	$package_ref=\%stable_package_hash;
    }
    elsif($exist_dev && $stable_status<=2){
	print "$pack, development version is selected\n";
	$stable_status=2;
	$stable_status_string="dev";
	$package_ref=\%dev_package_hash;
    }
    else{
	print "$pack, local modified version is selected\n";
	$stable_status=3;
	$stable_status_string="local";
	$package_ref=\%local_package_hash;
    }
    $pack=~s/\//--/g;
    $pack_id = "$pack\_$stable_status_string";
    $prefix = "$repo/$stable_status_string";
    $dirs{root}="$repo/$pack_id";
    $dirs{tmp}="$repo/$pack_id\_tmp";
    $dirs{make}=$dirs{tmp};
    $log_file="$repo/$pack_id.log";
    unlink $log_file;
}

sub _download(){
    my ($download_url, $download_method_list)=@_;
    my ($function, $arg);
    my @download_method_list = split /\|/,$download_method_list;
    for my $download_method (@download_method_list){
				if($download_method=~/^([^:]+):?(\S+)?$/){
						($function, $arg)=($1,$2);
				}
				else{
						die "download method string is not valid: \n$download_method";
				}
				my @args=split ",",$arg;

				$download_url=&{\&{$function}}($download_url, @args);
    }

    
}
sub _build(){
    my ($install_method_list)=@_;
    my ($function, $arg);
    my @install_method_list = split /\|/,$install_method_list;
    
    print "building $pack\n" if $install_method_list ne "";

    for my $install_method (@install_method_list){

				if($install_method=~/^([^:]+):?(.+)?$/){
						($function, $arg)=($1,$2);
				}	
				else{
						die "build method string is not valid: \n$install_method";
				}
				my @args=split ",",$arg;
				&{\&{$function}}(@args);
    }



}
sub _sync_system(){
    my ($cmd, $label)=@_;
    if(system "$cmd >>$log_file"){
#				&remove_tree("$dirs{tmp}");
	die "$label failed\n $cmd\n";
    }
    else{
	print "$label success\n";
    }
}

sub _parse_ftp_list_string(){
#-rw-r--r--   1 3003     65534         120 Jan 25  2001 README.olderversions
#drwxr-xr-x    2 3003     3003         4096 May 31  2013 gcc-4.8.1
#drwxr-xr-x    2 3003     3003         4096 Oct 16 09:06 gcc-4.8.2
    my ($string)=@_;

    my ($mod,$num,$usr,$grp,$size,$mon,$day,$year,$file)=split /\s+/,$string;
    if(length($year)!=4){
	$year=$cur_year;
    }
    my $time=sprintf("%04d%02d%02d",$year,$mon_ref->{$mon},$day);
if($time>$cur_day){
	$time=sprintf("%04d%02d%02d",$year-1,$mon_ref->{$mon},$day);
}
    my $isdir=0;
    if($mod=~/^d/){
	$isdir=1;
    }
    return ($file,$time,$isdir);
}

####################
#download methods
####################
sub latest() {
    print "try to get latest version\n";
    my ($string, $regex)=@_;
    if($regex eq ""){
	$regex=".*";
    }
    my ($server,$user,$pass,$directory);
    if($string=~/^ftp:\/\/(?:([^:\@]+):([^\@]+)\@)?([^\/]+)\/(\S+)/){
	($server,$user,$pass,$directory)=($3,$1,$2,$4);
	$directory="./$directory";
	$user = "anonymous" if $user eq "";
	$pass = '-anonymous@' if $pass eq "";
    }
    else{
	die "ftp string is not validate\n $string\n";
    }
    my $ftp = Net::FTP->new($server, Timeout => 30)
	or die "Can not connect to $server : $@\n";
    $ftp->login($user, $pass)
	or die "Can not login using credentials : $@\n";
    $ftp->binary()
	or die "Can not switch to binary mode : $@\n";
GETDIR:
    $ftp->cwd($directory)
	or die "Can not change directories to $directory : $@\n";
    my @filestr = $ftp->dir() ;
    if(@filestr==0){
	die "Can not list files : $@\n";
    }
    my $latest_file = '';
    my $latest_time = 0;
    my $is_latest_dir;
    foreach my $filestr (@filestr) {
	my ($file,$modtime,$isdir)=&_parse_ftp_list_string($filestr);
	next if(($file!~/$regex/ && !$isdir) || ($isdir && $file!~/\d\./));
	warn $file,"\t$modtime\n";	
	if($latest_file eq "") {
	    $latest_file = $file;
	    $latest_time = $modtime;
	    $is_latest_dir = $isdir;
	    next;
	}
	if($modtime > $latest_time) {
	    warn "\t$latest_time $modtime";
	    warn "\t$latest_file $file";
	    if($file=~/(\S+).xz$/ && $latest_file eq "$1.gz"){	
		next;
	    }
	    $latest_file = $file;
	    $latest_time = $modtime;
	    $is_latest_dir = $isdir;
	}
    }
    if(!$latest_file){
	die "not file match $regex:$@\n";
    }
    if($is_latest_dir){
	$directory="$latest_file";
	$string="$string/$latest_file";
	goto GETDIR;
    }
    $ftp->close();
    print "#########\n$latest_file\n###########\n";
    #die;
    return "$string\/$latest_file";
}

sub nav(){
    my ($download_url, $href)=@_;
    warn "navigate $download_url\n";
    $download_url=~/^(((http|https|ftp):\/\/[^\/]+)\S+(?:[^\/]+)?)$/;
    my ($base, $domain, $protocal)=($1,$2,$3);

    die "protocal $protocal is not identified" if !$protocal;
    my $response;
    my $content;
    if($protocal eq "https"){
				$content=`wget -c $download_url --no-check-certificate -O -`;
    }
    else{
				$response=HTTP::Tiny->new->get($download_url);
				die "Unable to get page $download_url $@" if !$response->{success};;
				$content=$response->{content};
    }
    
    
    if($content=~/href\s*=\s*[\'\"]([0-9a-zA-z_\-\:\/\.]*$href[0-9a-zA-z_\-\:\/\.]*)[\'\"]/s){
				my $url = $1;


				if($url=~/^http|https|ftp:\/\/[^\/]+/){
						$url=$url;
				}
				elsif($url=~/^\/\//){
						$url="http:$url";
				}
				elsif($url=~/^\//){
						$url=$domain."$url";
				}
				elsif($base =~ /\/$/){
						$url=$base."$url";
				}
				else{
						$url=$domain."/"."$url";
				}
				warn "-->match: ", $url,"\n";

				return $url;
    }
    else{
				die "href not find in page $download_url, $pack download failed";
    }

}
sub parse(){
}
sub apply(){
}
sub wget(){
    my ($download_url, $postfix)=@_;
		my $ori_download_url=$download_url;
		if($postfix){
				$download_url=$download_url.$postfix;
		}
    if($download_url=~/([^\/]+)\/?$/){
				$filename=$1;
    }
    else{
				die "invalid download url, wget $pack\n";
    }
    if($download_url=~/([^\/]+\.gz)/ && $1 ne $filename){
				$filename = $1;
    }
    if($download_url=~/([^\/]+\.zip)/ && $1 ne $filename){
				$filename = $1;
    }
    print "-->download filename: ", $filename,"\n";
    system qq(echo $download_url >>$log_file); 
		if($is_update){
				unlink($filename);
		}
    &_sync_system(qq(cd $repo && wget -c $download_url --no-check-certificate -O $filename), "wget");
		return $ori_download_url;
}
sub wgettmp(){
    my ($download_url)=@_;
    system qq(echo $download_url >>$log_file); 
    $filename="binary";
    &_sync_system(qq(cd $dirs{tmp} && wget -c $download_url -O $filename), "wget");

}
sub newdir(){
    &_sync_system(qq(mkdir $dirs{root}),"mkdir");
}
sub git(){
    my ($addr)=@_;
    print "git clone $addr $pack_id\n";
    &_sync_system(qq(cd $repo && git clone $addr $pack_id), "git");
}
sub hg(){
    my ($addr)=@_;
    print "hg clone $addr $pack\n";
    &_sync_system(qq(cd $repo && hg clone $addr $pack_id),"hg");
}
sub svn(){
    my ($addr)=@_;
    print "svn checkout $addr $pack\n";
    &_sync_system(qq(cd $repo && svn checkout $addr $pack_id),"svn");
}

####################
#install methods
####################
sub autoconf(){
    my (@args)=@_;
    &_sync_system(qq(cd $dirs{root} && autoreconf -fi),"autoconf");

}
sub tar(){
    my (@args)=@_;
    &_sync_system(qq(cd $dirs{tmp} && tar -xhf $repo/$filename),"tar");
    $dirs{root}="$dirs{tmp}/*";
}
sub unzip(){
    my (@args)=@_;
    &_sync_system(qq(cd $dirs{tmp} && unzip $repo/$filename),"unzip");
    $dirs{root}="$dirs{tmp}/*";
}
sub conf(){
    my (@args)=@_;
    &_sync_system(qq(cd $dirs{make} && $dirs{root}/configure $conf_op >>$log_file && make), "./configure & make");
}
sub cmake(){
    my (@args)=@_;
    &_sync_system(qq(cd $dirs{make} && cmake * $conf_op  >>$log_file && make),  "cmake && make");
}
sub inst(){
    my (@args)=@_;
    &_sync_system(qq(cd $dirs{make} && sudo make install),"make install");
}
sub sh(){
    my (@args)=@_;
    for my $arg (@args){
	&_sync_system("cd $dirs{make} && $arg","sh");
    }
}
sub shcat(){
    my (@args)=@_;
    for my $arg (@args){
	&_sync_system("cd $dirs{make} && cat $filename | $arg","sh");
    }
}
sub shroot(){
    my (@args)=@_;
    for my $arg (@args){
	&_sync_system("cd $dirs{root} && $arg","sh");
    }
}
sub shtmp(){
    my (@args)=@_;
    for my $arg (@args){
	&_sync_system("cd $dirs{tmp} && $arg","sh");
    }
}
sub ln(){
    my ($t)=@_;
    &_sync_system("cd $dirs{root} && sudo ln -sf $dirs{root}/$t /usr/local/bin", "soft link");
}
sub setdir(){
    my ($str1,$str2)=@_;
    $dirs{$str1}=$dirs{$str2};
}

sub mvtmp(){
    if(-d "$repo/$pack_id"){
				remove_tree("$repo/$pack_id");
    }
    &_sync_system("mv $dirs{root} $repo/$pack_id","mv");
    $dirs{root}="$repo/$pack_id"
}
sub mvbin(){
    if(-d "$repo/$pack_id"){
				remove_tree("$repo/$pack_id");
    }
    &_sync_system("sudo mv $dirs{root}/bin/* /usr/bin/.","mv");
    $dirs{root}="/usr/bin"
}
sub rmz(){
    unlink $filename;
}
