#!/usr/bin/perl
use HTTP::Request;
use HTTP::Cookies;
use LWP::UserAgent;
use JSON;
use Data::Dumper;
use Encode;
use DBI qw(:sql_types);
use Smart::Comments;
use Net::SMTP;
use POSIX;
use Mail::Sender;
my @user_mails = ('');
my @admin_mails = ('');
my $from = '';
my $smtp_host = 'smtp.qq.com';
my $pop_host = 'pop.qq.com';
my $username = "";
my $password = "";
my $url = "http://xueqiu.com/user/login";
my $update_time = `date "+%Y-%m-%d %T"`;
my %stock_info ;
my %old_stock_info;
my %insert_stock_add;
my %insert_stock_move;
my $fail_count = 0;
my $cookie_jar = HTTP::Cookies->new(
		file => "./acookies.lwp",
		autosave=>1,
		);
#$ua->proxy("http","http://10.103.11.57:81/");
#$ua->env_proxy;
$cookie = "Hm_lvt_1db88642e346389874251b5a1eded6e3=1424835754,1424850192,1424940268,1424946234; __utma=1.908767593.1422843696.1424940267.1424944571.17; __utmz=1.1424940267.16.5.utmcsr=baidu|utmccn=(organic)|utmcmd=organic|utmctr=%E9%9B%AA%E7%90%83%E6%8C%81%E4%BB%93%E7%BB%84%E5%90%88; bid=e5795c98cf852afa2d63ebaba3be7d3a_i6dczl3m; last_account=huadaonan%40163.com; __utmb=1.11.10.1424944571; __utmc=1; Hm_lpvt_1db88642e346389874251b5a1eded6e3=1424947673; xq_a_token=39af55e14d4e1ce4d058bd0092651e75e6608a3a; xq_r_token=ae2a058a9cefe66c075cc518bf9f762073348a4f; xqat=39af55e14d4e1ce4d058bd0092651e75e6608a3a; xq_is_login=1; xq_token_expire=Mon%20Mar%2023%202015%2018%3A24%3A50%20GMT%2B0800%20(CST); __utmt=1";


#my $res = $ua->post($url,
#		[
#		username=>'huadaonan@163.com',
#		password=>'qazwsx1984',
#		],
#		);
#@vgroup_adr = ("http://xueqiu.com/P/ZH187525");


my $dir = "/root/monitor";


#### use group id files
#open FILE_HANDLE,"<$dir/group_id.log" or die "can't open file\n";
#        @group_id = <FILE_HANDLE>;
#        @vgroup_adr = map { "http://xueqiu.com/P/$_"} @group_id;
#close FILE_HANDLE;



#### get the group id

my @vgroup_adr = ();
my $custom_adr = "http://xueqiu.com/1297321670";
my $ua = LWP::UserAgent->new("timeout=>60");
my $cookies = $ua->cookie_jar($cookie_jar);
$ua->default_header('cookie'=>$cookie);
$ip= int(rand(254)).".".int(rand(254)).".".int(rand(254)).".".int(rand(254));
$ua->default_header('client_ip'=>$ip);
$ua->default_header('x_forwarded_for'=>$ip);
$ua->default_header('remote_adr'=>$ip);
$ua->agent('Mozilla/5.0 (Windows NT 6.1; rv:30.0) Gecko/20100101 Firefox/30.0');
my $custom_group = $ua->get($custom_adr);
if($custom_group->is_success){
	 $custom_content  = $custom_group->content;
	 if($custom_content =~  /var portfolioOptions =([\D\d]+);\nseajs[.]use/){
                $custom_json = $1;
         }else{
		&writeAMesg("$update_time : $custom_adr first my monitor maybe forbidden for access reason\n");			
		next;
         };

	 my $json = new JSON;
	 my $custom_obj = $json->decode($custom_json);
	 $custom_group_ref = $custom_obj->{"customArray"};
         @vgroup_adr = map { "http://xueqiu.com/P/$_"} @$custom_group_ref;

}else{
		my $tstr = "$update_time : $custom_adr ".$custom_group->status_line."\n";
		&writeAMesg($tstr,@admin_mails);			
                next;
}

#@vgroup_adr = ("http://xueqiu.com/P/ZH187525");
foreach my $group_adr(@vgroup_adr){
 sleep(0.2);
### get each stock info of groups 
  my $va = LWP::UserAgent->new("timeout=>60");
  $va->default_header('cookie'=>$cookie);
  $ip= int(rand(254)).".".int(rand(254)).".".int(rand(254)).".".int(rand(254));
  $va->default_header('client_ip'=>$ip);
  $va->default_header('x_forwarded_for'=>$ip);
  $va->default_header('remote_adr'=>$ip);
  $va->agent('Mozilla/5.0 (Windows NT 6.1; rv:30.0) Gecko/20100101 Firefox/30.0');
  $focus_group = $va->get($group_adr);

  if($focus_group->is_success){
	 $fail_count = 0;
	 $content  = $focus_group->content;
         if($content =~ /SNB.cubeInfo = ([\D\d]+)\sSNB.cubePieData/){
                $focus_json = $1;
         }else{
		&writeAMesg("$update_time : $group_adr first my monitor didn't get info success\n");			
                next;
         };
	 my $json = new JSON;
	 my $obj = $json->decode($focus_json);
 	 my $group_adr  =  $obj->{"symbol"};
	 my $group_name =  Encode::decode("utf8",$obj->{"name"});
	 my $v_time = substr($obj->{"updated_at"},0,10);
	 $update_time = strftime("%Y-%m-%d %H:%M:%S", localtime($v_time));

####### read old stock numbe
	 $path = "$dir/stock_info_$group_adr.log";
	 if  ( -e $path) {
	 	open READ_INFO,"<$path" or die "can't open file\n";
	 	while(<READ_INFO>){
	 	 	chomp;
			my @vstrings = split(/,/,$_);
	  	        push(@old_stock_number,$vstrings[0]);
			$old_stock_info{$vstrings[0]} = [ $vstrings[1] ,$vstrings[2] , $vstrings[3] ,$vstrings[4] ];
		 };
	 	close READ_INFO;
	 }else {
		open FILE,">$path"  or die "can't open file\n";
		close FILE;
	 };


####### write new stock number
	 open FILEHANDLE, ">$path" or die "can't write file\n";
	 $array_holding = $obj->{"last_success_rebalancing"}{"holdings"};
	 #$array_holding = $obj->{"view_rebalancing"}{"holdings"};
	 @array1 = @$array_holding;
	 
	 foreach(0..$#array1){
		if($array_holding->[$_]{"stock_symbol"} =~ /^\w+/){
			my $stock_name = Encode::decode_utf8($array_holding->[$_]{"stock_name"});
		 	my $stock_number = $array_holding->[$_]{"stock_symbol"};
			my $segment_name = Encode::decode_utf8($array_holding->[$_]{"segment_name"});
			my $weight = $array_holding->[$_]{"weight"};
			push(@new_stock_number,$stock_number);
			$stock_info{$stock_number} = [ $stock_name,$segment_name,$weight ];
			my $vstrings = $stock_number.",".$stock_name.",".$segment_name.",".$weight.",".$update_time;
			print FILEHANDLE "$vstrings\n";
		}
	 };
 	 close FILEHANDLE;

######## compare
#
#	


	if(@new_stock_number){
		 %new_stock = map { $_,1 } @new_stock_number;
		 foreach my $stock_number(@old_stock_number){
			unless($new_stock{$stock_number}){
				 $stock_name =  Encode::decode("utf8",$old_stock_info{$stock_number}->[0]);
				my $vstock_info = $stock_number.",".$stock_name.",".$old_stock_info{$stock_number}->[2];
				push @array_stock_number,$vstock_info;
				$insert_stock_move{$stock_number} =[ $stock_name,Encode::decode("utf8",$old_stock_info{$stock_number}->[1]),$old_stock_info{$stock_number}->[2] ];
###				%insert_stock_move
			}else{

				my $old_weight = $old_stock_info{$stock_number}->[2];
				my $new_weight = $stock_info{$stock_number}->[2];
				my $stk_name =   Encode::decode("utf8",$stock_info{$stock_number}->[0]);
				if(abs($new_weight - $old_weight)>10){
					$vstr = "GROUP:http://xueqiu.com/P/$group_adr $group_name had changed $stk_name $stock_number\'s weight from $old_weight\% to $new_weight\% \n";
					&writeAMesg($vstr,@user_mails);
				}
				
			}
		};
		if(@array_stock_number){
	 		$vvstrings = "GROUP:http://xueqiu.com/P/$group_adr $group_name  had  removed: @array_stock_number at $update_time ";
			
			&writeAMesg($vvstrings,@user_mails);
			&insert_db( $group_adr,$group_name,0,$update_time,%insert_stock_move);
		}
	};
	if(@old_stock_number){
		%old_stock = map {$_,1} @old_stock_number;
		foreach my $stk_num(@new_stock_number){
			unless($old_stock{$stk_num}){
				print "$update_time : $stk_num are new added\n";	
				my $vstock_info = $stk_num.",". Encode::decode("utf8",$stock_info{$stk_num}->[0]).",".$stock_info{$stk_num}->[2];
				push @array_stk_num,$vstock_info;
				$insert_stock_add{$stk_num} = [ Encode::decode("utf8",$stock_info{$stk_num}->[0]) ,Encode::decode("utf8",$stock_info{$stk_num}->[1]),$stock_info{$stk_num}->[2] ];

			}else{

				my $old_weight = $old_stock_info{$stk_num}->[2];
				my $new_weight = $stock_info{$stk_num}->[2];
				my $stk_name =   Encode::decode("utf8",$stock_info{$stk_num}->[0]);
				if(abs($new_weight - $old_weight)>10){
					$vstr = "GROUP:http://xueqiu.com/P/$group_adr $group_name had changed $stk_name $stk_num\'s weight from $old_weight\% to $new_weight\% \n";
					&writeAMesg($vstr,@user_mails);
				}
			
### $vstr
			}
		};
		if(@array_stk_num){
			my $vvstr = "GROUP:http://xueqiu.com/P/$group_adr $group_name  had added: @array_stk_num at $update_time";
			&writeAMesg($vvstr,@user_mails);
			&insert_db($group_adr,$group_name,1,$update_time,%insert_stock_add);
### %insert_stock_add
		}
	};
	
	
	@new_stock_number = ();
	@old_stock_number = ();
	@array_stk_num = ();
	@array_stock_number = ();
	%insert_stock_add = ();
	%insert_stock_move = ();
	$va = ();
 }else{
	$fail_count++;
	if($fail_count >3){
		 my $tstr = "$update_time : $group_adr".$focus_group->status_line."\n";
	 	 &writeAMesg($tstr,@admin_mails);			
 		 next;
	}else{
		 redo;
	}
 }	 
}


sub writeAMesg{

	my $msg = shift @_;
	@mail_adr = @_;
	my $sender = new Mail::Sender{
	        ctype=>'text/plain;charset=utf-8',
	        encoding=> 'utf-8',
	};
	if($sender->MailMsg({
	        smtp=>'smtp.qq.com',
	        from=>'',
	        to=> \@mail_adr,
	        subject=>'！',
	        msg=>$msg,
	        auth=>'LOGIN',
	        authid=>'',
	        authpwd =>'',
	}) <0) {
	        die "error : $Mail::Sender::Error\n";
	};
	$sender->Close();



#    my $smtp = Net::SMTP->new( $smtp_host, Timeout=>60 );
#    $smtp->auth($username, $password);
#   foreach my $mailto (@mailtos) {
#    $smtp->mail( $from );
#    $smtp->to( $mailto );
#print $mailto."\n";
#    $smtp->data();
#    $smtp->datasend("To: $to\n");
#    $subject = Encode::decode_utf8("for test 雪球定制组合调仓提醒!!!");
#    $smtp->datasend("Subject:  $subject--$update_time\n");
#    $smtp->datasend("\n");
#    $smtp->datasend("$strings\n");
#    $smtp->datasend("\n");
#    $smtp->dataend();
#   };
#   $smtp->quit;
#   @mailtos=();
};

sub insert_db {
	($group_num,$group_name,$stock_action,$change_time,%insert_stock_info) = @_;
	foreach my $stock_num( keys %insert_stock_info){
	my $stock_name = $insert_stock_info{$stock_num}->[0];
	my $segment_name = $insert_stock_info{$stock_num}->[1];
	my $weight = $insert_stock_info{$stock_num}->[2];
	my $dsn ="DBI:mysql:database=xueqiu;hostname=127.0.0.1:3306";
	my $dbh = DBI->connect($dsn,"xueqiu-sys",'xueqiu',{'RaiseError'=>1});
	$dbh->do("set names utf8");
	my $sqr = $dbh->prepare("insert into stock_change_detail(group_num,group_name,segment_name,stock_num,stock_name,weight,stock_action,change_time) values(?,?,?,?,?,?,?,?)");
	$sqr->bind_param(1,$group_num,{TYPE=>SQL_VARCHAR});
	$sqr->bind_param(2,$group_name,{TYPE=>SQL_VARCHAR});
	$sqr->bind_param(3,$segment_name,{TYPE=>SQL_VARCHAR});
	$sqr->bind_param(4,$stock_num,{TYPE=>SQL_VARCHAR});
	$sqr->bind_param(5,$stock_name,{TYPE=>SQL_VARCHAR});
	$sqr->bind_param(6,$weight,{TYPE=>SQL_VARCHAR});
	$sqr->bind_param(7,$stock_action,{TYPE=>SQL_VARCHAR});
	$sqr->bind_param(8,$change_time,{TYPE=>SQL_VARCHAR});
	$sqr->execute();
	$sqr->finish();
	}
}
