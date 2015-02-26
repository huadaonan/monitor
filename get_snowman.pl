#!/usr/bin/perl
use HTTP::Request;
use HTTP::Cookies;
use LWP::UserAgent;
use JSON;
use Data::Dumper;
use Encode;
#use Smart::Comments;
use Net::SMTP;
my @mailto = ('xxxx','xxxx');
my $from = 'xxx';
my $smtp_host = '';
my $pop_host = '';
my $username = "";
my $password = "";
my $url = "http://xueqiu.com/user/login";
my $time = localtime;
my %stock_info ;
my $cookie_jar = HTTP::Cookies->new(
		file => "./acookies.lwp",
		autosave=>1,
		);
my $ua = LWP::UserAgent->new;
#$ua->proxy("http","http://10.103.11.57:81/");
#$ua->env_proxy;
my $cookies = $ua->cookie_jar($cookie_jar);
$ua->agent('Mozilla/5.0 (Windows NT 6.1; rv:30.0) Gecko/20100101 Firefox/30.0');
my $res = $ua->post($url,
		[
		username=>'',
		password=>'',
		],
		);
#### get the group id
my @vgroup_adr = ();
my $custom_adr = "http://xueqiu.com/1297321670";
my $custom_group = $ua->get($custom_adr);
if($custom_group->is_success){
	 $custom_content  = $custom_group->content;
	 if($custom_content =~ /var portfolioOptions =([\D\d]+);\nseajs[.]use/){
	 	$custom_json = $1;
	 }
	 my $json = new JSON;
	 my $custom_obj = $json->decode($custom_json);
	 $custom_group_ref = $custom_obj->{"customArray"};
         @vgroup_adr = map { "http://xueqiu.com/P/$_"} @$custom_group_ref;
	# print @vgroup_adr;
};



foreach my $group_adr(@vgroup_adr){

### get each stock info of groups 
 $focus_group = $ua->get($group_adr);
 if($focus_group->is_success){
	 $content  = $focus_group->content;
	 if($content =~ /SNB.cubeInfo = ([\D\d]+)\sSNB.cubePieData/){
	 	$focus_json = $1;
	 }
	 my $json = new JSON;
	 my $obj = $json->decode($focus_json);
 	 my $group_adr  =  $obj->{"symbol"};
	 my $group_name =  Encode::decode("utf8",$obj->{"name"});
### $content
### $obj

####### read old stock numbe
	 $path = "/root/monitor/stock_info_$group_adr.log";
	 if  ( -e $path) {
	 	open READ_INFO,"<$path" or die "can't open file\n";
	 	while(<READ_INFO>){
	 	 	chomp;
			my @vstrings = split(/,/,$_);
	  	        push(@old_stock_number,$vstrings[0]);
		 };
	 	close READ_INFO;
	 }else {
		open FILE,">$path"  or die "can't open file\n";
		close FILE;
	 };


####### write new stock number
	 open FILEHANDLE, ">$path" or die "can't write file\n";
	 $array_holding = $obj->{"last_rebalancing"}{"holdings"};
	 @array1 = @$array_holding;
	 
	 foreach(0..$#array1){
		if($array_holding->[$_]{"stock_symbol"} =~ /^\w+/){
			my $stock_name = Encode::decode_utf8($array_holding->[$_]{"stock_name"});
		 	my $stock_number = $array_holding->[$_]{"stock_symbol"};
			push(@new_stock_number,$stock_number);
			$stock_info{$stock_number} = $stock_name;
			my $vstrings = $stock_number.",".$stock_name;
			print FILEHANDLE "$vstrings\n";
		}
	 };
 	 close FILEHANDLE;

######## compare
#
	if(@new_stock_number){
		 %new_stock = map { $_,1 } @new_stock_number;
		 foreach my $stock_number(@old_stock_number){
			unless($new_stock{$stock_number}){
				 $stock_name = Encode::decode("utf8",$stock_info{$stock_number});
				print "$stock_number  $stock_name had been move\n";
				my $vstock_info = $stock_number.",".$stock_name;
				push @array_stock_number,$vstock_info;
			}
		};
		if(@array_stock_number){
	 		&writeAMesg("$group_adr $group_name $time: @array_stock_number had been move");
		}
	};
	if(@old_stock_number){
		%old_stock = map {$_,1} @old_stock_number;
		foreach my $stk_num(@new_stock_number){
			unless($old_stock{$stk_num}){
				print "$time : $stk_num are new added\n";	
				my $vstock_info = $stk_num.",". Encode::decode("utf8",$stock_info{$stk_num});
				push @array_stk_num,$vstock_info;
			}
		};
		if(@array_stk_num){
			&writeAMesg("$group_adr $group_name $time: @array_stk_num are new added");	
		}
	};
	@new_stock_number = ();
	@old_stock_number = ();
	@array_stk_num = ();
	@array_stock_number = ();
 }else{
 	exit;
 }	 
}



sub writeAMesg{
    my $strings = shift @_;
   foreach my $mailto (@mailto) {
    my $smtp = Net::SMTP->new( $smtp_host, Timeout=>60 );
    $smtp->auth($username, $password);
    $smtp->mail( $from );
    $smtp->to( $mailto );
    $smtp->data();
    $smtp->datasend("To: $to\n");
    $smtp->datasend("Subject: $group_adr  group had been changed!!!!!\n");
    $smtp->datasend("\n");
    $smtp->datasend("$strings\n");
    $smtp->datasend("\n");
    $smtp->dataend();
    $smtp->quit;
   }
};
