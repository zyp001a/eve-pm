#!/usr/bin/env perl
=h

=cut
use strict;
no strict "refs";
use LWP::UserAgent;
use Net::FTP;
#use File::Basename;
use File::Path qw(remove_tree);
use Fatal qw(open close);
my ($cmd,$pack,$stable_status)=@ARGV;
#stable_status: 
#	0->stable
#	1->dev
#	2->local

my $useage = <<END;
Useage:
  .\/pm [ install|i | update|u | erase|e | search|s | generate|g ] package-name
END

if(!$pack){
		die $useage;
}
if(!$ENV{"EVE_HOME"}){
		die "You must set EVE_HOME first\n";
}
my $ua = LWP::UserAgent->new;
my $eve_home = $ENV{"EVE_HOME"};
my $repo = "$eve_home/repo";

my %stable_package_hash;
my %dev_package_hash;
my %local_package_hash;
my $package_ref;
my %installed_packages;
my %dependencies;
my $log_file;
my $package_list="$eve_home/conf/installed_package.list";
my $dependency_list="$eve_home/conf/dependencies.list";


my $is_update=0;
my $prefix;
my $stable_status_string;
my $pack_id;
my $root_dir;
my $tmp_dir;

####################
#main logic
####################
&_read_list();
if($cmd eq "install" || $cmd eq "i"){
		$is_update=0;
		&install();
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
		&_set_prefix();
		if($installed_packages{$pack}{$stable_status}){
				print "$pack is installed, try \n ./pm update $pack $stable_status\n";
				return;
		}
		my ($download_url, $download_method, $install_method) =
				  @{$package_ref->{$pack}}[1..3];
		for my $dependency (split ",",$dependencies{$pack}){
				if(!$installed_packages{$dependency}){
						if(system qq(./pm i $dependency 0)){
								die "$dependency install failed";
						}
				}
		}
		if(-d "$repo/$pack_id" || -f "$repo/$pack_id.tar.gz"){
				print "$pack already exist, if you want to download new pack, please try \n ./pm update $pack\n";
		}
		else{
				&_download($download_url, $download_method);
		}

		&_build($install_method);
		&_write_list();
}
sub update(){
		&_set_prefix();
		my ($download_url, $download_method, $install_method) =
				@{$package_ref->{$pack}}[1..3];		
	#	&_download($download_url, $pack, $download_method);
	#	&_build($pack, $install_method);
}
sub erase(){
}
sub search(){
}
sub generate(){
}


####################
#internal methods
####################
sub _read_list(){
		my $c=0;
		open A,"$dependency_list";
		while (<A>){
        chomp;
        my ($package_name, $dependencies)=split "\t";
				$dependencies{$package_name}=$dependencies;
    }
		close A;
		open A,"$package_list";
		while (<A>){
				chomp;
				my ($package_name, $stable_status)=split "\t";
				next if $package_name eq "";
				$stable_status=0 if(!$stable_status);
				$stable_status=2 if($stable_status>1);
				$installed_packages{$package_name}{$stable_status}=1;
		}
		close A;
		open A,"cat $eve_home/conf/*.packages |";
		while (<A>){
				chomp;
				my ($package_name, $description, $download_url, $stable_status,
						$download_method, $install_method) = split "\t";
				if(!$download_url){
						die "packages not validate:\n $_\n";
				}
				if(!$stable_status){
						$stable_package_hash{$package_name} = 
								[$description, $download_url, 
								 $download_method, $install_method];
				}
				elsif($stable_status==1){
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
sub _write_list(){
		open O,">$package_list";
		for my $pack (sort keys %installed_packages){
				for my $stable_status (sort keys %{$installed_packages{$pack}}){
						print O "$pack\t$stable_status\n";
				}
		}
		close O;
}
sub _set_prefix(){
		my $exist_stable=$stable_package_hash{$pack};
		my $exist_dev=$dev_package_hash{$pack};
		my $exist_local=$local_package_hash{$pack};
		if(!$exist_dev && !$exist_stable){
				print "$pack is not exist\n";
				&search();
				die;
		}
		elsif($exist_stable && !$stable_status){
				$prefix="$eve_home/stable";
				print "$pack, stable version is selected\n";
				$stable_status=0;
				$stable_status_string="stable";
				$package_ref=\%stable_package_hash;
		}
		elsif($exist_dev && $stable_status<=1){
				$prefix="$eve_home/dev";
				print "$pack, development version is selected\n";
				$stable_status=1;
				$stable_status_string="dev";
				$package_ref=\%dev_package_hash;
		}
		else{
				print "$pack, local modified version is selected\n";
				$stable_status=2;
				$stable_status_string="local";
				$package_ref=\%local_package_hash;
		}
		$pack_id = "$pack\_$stable_status_string";
		$prefix = "$eve_home/$stable_status_string";
		$root_dir="$repo/$pack_id";
		$tmp_dir="$repo/$pack_id\_tmp";
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
				
		print "building $pack\n";
	  mkdir "$tmp_dir"
				|| die "cannot mkdir $tmp_dir";
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
		&remove_tree("$tmp_dir");
		$installed_packages{$pack}{$stable_status}=1;

}
sub _sync_system(){
		my ($cmd, $label)=@_;
		if(system "$cmd >>$log_file"){
#				&remove_tree("$tmp_dir");
				die "$label failed\n $cmd\n";
		}
		else{
				print "$label success\n";
		}
}


####################
#download methods
####################
sub latest() {
		print "try to get latest version\n";
		my ($string, $regex)=@_;
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
		$ftp->cwd($directory)
				or die "Can not change directories to $directory : $@\n";
		my @files = $ftp->ls();
		my $latest_file = '';
		my $latest_time = 0;
		foreach my $file (@files) {
#				warn $file;
				next if($file!~/$regex/);
				my $modtime = $ftp->mdtm($file);
#				warn "$file\t$modtime\n";
				if($latest_file eq "") {
						$latest_file = $file;
						$latest_time = $modtime;
						next;
				}
				if($modtime > $latest_time) {
#						warn "\t$latest_time $modtime";
#						warn "\t$latest_file $file";
						$latest_file = $file;
						$latest_time = $modtime;
				}
		}
		$ftp->close();			 
		print "#########\n$latest_file\n###########\n";
		die;
		return "$string\/$latest_file";
}

sub nav(){
		my ($download_url, $href)=@_;
		my $response = $ua->get($download_url) or die 'Unable to get page $download_url';
		my $content=$response->decoded_content;
		$download_url=~/^(http|https|ftp):\/\/([^\/]+)/;
		my ($protocal, $domain)=($1,$2);
		die "protocal $protocal is not identified" if !$protocal;
		if($content=~/href=\"(.*($href).*)\"/){
				my $url = $1;
				if($url!~/^(http|https|ftp):\/\/([^\/]+)/){
						$url=$response->base."/$url";
				}
				return $url;
		}
		else{
				die "href not find in page $download_url, $pack download failed";
		}

}
sub wget(){
		my ($download_url)=@_;
		if($is_update){
				unlink "$repo/$pack_id.tar.gz";
		}
		&_sync_system(qq(cd $repo && wget -c $download_url -O $pack_id.tar.gz), "wget");

}
sub git(){
		my ($repo)=@_;
		print "git clone $repo $pack_id\n";
		if($is_update){
				&_sync_system(qq(cd $repo/$pack_id && git pull origin master), "git");
		}
		else{
				&_sync_system(qq(cd $repo && git clone $repo $pack_id), "git");
		}
}
sub hg(){
		my ($repo)=@_;
		print "hg clone $repo $pack\n";
    &_sync_system(qq(cd $repo && hg clone $repo $pack_id),"hg");
}
sub svn(){
		my ($repo)=@_;
		print "svn checkout $repo $pack\n";
		&_sync_system(qq(cd $eve_home/repo && svn checkout $repo $pack_id),"svn");
}
####################
#install methods
####################
sub autoconf(){
		my (@args)=@_;
		&_sync_system(qq(cd $repo/$pack_id && autoreconf -fi),"autoconf");
}
sub tar(){
		my (@args)=@_;
		&_sync_system(qq(cd $tmp_dir && tar -xhf $repo/$pack_id.tar.gz),"tar");
		$root_dir="$tmp_dir/*";
}
sub conf(){
		my (@args)=@_;
		&_sync_system(qq(cd $tmp_dir && $root_dir/configure --prefix=$prefix >>$log_file && make), "./configure & make");
}
sub inst(){
		my (@args)=@_;
		&_sync_system(qq(cd $tmp_dir && make install),"make install");
}
sub sh(){
		my (@args)=@_;
		for my $arg (@args){
				&_sync_system("cd $root_dir && $arg","sh");
		}
}

