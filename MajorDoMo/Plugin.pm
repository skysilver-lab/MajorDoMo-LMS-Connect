#	MajorDoMo Connect Plug-in
#
#	Author:	Agaphonov Dmitri <skysilver.da@gmail.com>
#
#	Copyright (c) 2015 Agaphonov Dmitri
#	All rights reserved.
#

package Plugins::MajorDoMo::Plugin;
use strict;
use base qw(Slim::Plugin::Base);

use Slim::Utils::Strings qw(string);
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Misc;

use Slim::Player::Client;
use Slim::Player::Source;
use Slim::Player::Playlist;

use File::Spec::Functions qw(:ALL);
use FindBin qw($Bin);

use Plugins::MajorDoMo::MajorDoMoSendMsg;
use Plugins::MajorDoMo::Settings;

# ----------------------------------------------------------------------------
# Глобальные переменные
# ----------------------------------------------------------------------------

my $playmodeCurrent = 'stop';
my $playmodeOld = 'stop';


# ----------------------------------------------------------------------------
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.MajorDoMo',
	'defaultLevel' => 'ERROR',
	'description'  => 'PLUGIN_MAJORDOMO_MODULE_NAME',
});

# ----------------------------------------------------------------------------
# Путь и имя файла для хранения настроек плагина: prefs\plugin\MajorDoMo.pref
# ----------------------------------------------------------------------------
my $prefs    = preferences('plugin.MajorDoMo');
my $srvprefs = preferences('server');

# ----------------------------------------------------------------------------
sub initPlugin {
	my $classPlugin = shift;

	$classPlugin->SUPER::initPlugin();

	my $classSettings = Plugins::MajorDoMo::Settings->new($classPlugin);

	Slim::Control::Request::subscribe( \&newPlayerCheck, [['client']],[['new']]);

	Plugins::MajorDoMo::MajorDoMoSendMsg->new( $classPlugin);

}

# ----------------------------------------------------------------------------
# Если в LMS добавляется новый плеер, то вызывается эта функция
# ----------------------------------------------------------------------------
sub newPlayerCheck {
	my $request = shift;
	my $client = $request->client();
	
    if ( defined($client) ) {
	    $log->debug( $client->name()." is: " . $client->id() );

		# Проверка типа плеера
		if( !(($client->isa( "Slim::Player::Receiver")) || ($client->isa( "Slim::Player::Squeezebox2")))) {
			$log->debug( "Not a receiver or a squeezebox.\n");
			clearCallback();
			return;
		}
		
		# Инициализация объекта для плеера
		my $cprefs = $prefs->client($client);
		my $pluginEnabled = $cprefs->get('pref_Enabled');
		
		if ( !defined( $pluginEnabled) ){
			$log->debug( "Failed to read prefs for: ".$client->name()."\n");
			$log->debug( "will not be activated.\n");
			clearCallback();
			return;
		}

		# Если плагин не активен для этого плеера, то ничего не делаем, иначе подписываемся на изменения статусов плеера.
		if ( $pluginEnabled == 0) {
			$log->debug( "Plugin Not Enabled for: ".$client->name()."\n");
			clearCallback();
			return;
		} else {
			if ( $pluginEnabled == 1) {
				$log->debug( "Plugin Enabled for: ".$client->name()."\n");
				# При изменении статуса плеера будет вызвана функция commandCallback()
				Slim::Control::Request::subscribe( \&commandCallback, [['power', 'play', 'playlist', 'pause', 'client', 'mixer' ]], $client);			
			}			
		}
	}
}


# ----------------------------------------------------------------------------
sub clearCallback {
	$log->debug("Clearing command callback.");
	Slim::Control::Request::unsubscribe(\&commandCallback);
}


# ----------------------------------------------------------------------------
# Функция обработки статуса плеера
# ----------------------------------------------------------------------------
sub commandCallback {
	my $request = shift;

	my $RequestClient = $request->client();
	
	$log->debug( "commandCallback() from client " . $RequestClient->name() ."\n");
	
	my $client = $RequestClient;
	
	my $cprefs = $prefs->client($RequestClient);
	my $pluginEnabled = $cprefs->get('pref_Enabled');
	
	# Если не удается определить статус плагина для данного плеера (активен или нет)
	# (возможно плеер в группе синхронизации)
	if ( !defined($pluginEnabled) ){
		$log->debug( "Client not configured; maybe a synced player interferes ... \n");
		
		# Если текущий плеер синхронизирован с другим плеером
		if( $RequestClient->isSynced() ) {
			$log->debug("Player is synced with ... \n");
			my @buddies = $RequestClient->syncedWith();
			for my $BuddyClient (@buddies) {
				my $Buddycprefs = $prefs->client($BuddyClient);
				my $BuddyEnabled = $Buddycprefs->get('pref_Enabled');
				if( defined($BuddyEnabled) ){
					$client = $BuddyClient;
					last;
				}
			}
		}
		else{
			$log->debug("Not synced --> Exit ... \n");
			return;
		}
	}
	
	my $cprefs = $prefs->client($client);
		
	$log->debug( "commandCallback() Client : " . $client->name() . "\n");
	$log->debug( "commandCallback()    p0  : " . $request->{'_request'}[0] . "\n");
	$log->debug( "commandCallback()    p1  : " . $request->{'_request'}[1] . "\n");
	
	my $playmode    = Slim::Player::Source::playmode($client);
	$log->debug("PLAYMODE " . $playmode . "\n");

	if( $request->isCommand([['power']]) ){

		my $Power = $client->power();

		if( $Power == 0){
		    $log->debug( "Power OFF request from client " . $client->name() ."\n");
		    RequestPowerOff($client);
		}

		if( $Power == 1){
		    $log->debug( "Power ON request from client " . $client->name() ."\n");
		    RequestPowerOn($client);
		}

	}
	elsif ( $request->isCommand([['play']])
		 || $request->isCommand([['pause']])
		 || $request->isCommand([['playlist'], ['stop']])
		 || $request->isCommand([['playlist'], ['pause']]) 
	     || $request->isCommand([['playlist'], ['play']])
	     || $request->isCommand([['playlist'], ['jump']]) 
		 || $request->isCommand([['playlist'], ['index']]) 
	     || $request->isCommand([['playlist'], ['newsong']]) ){
		 
			 
		if( ($playmode eq "play") && (($playmodeOld eq "pause") || ($playmodeOld eq "stop")) ){
			$log->debug( "Play request from client " . $client->name() ."\n");
			RequestPlay($client);
		}

		if( (($playmode eq "pause") || ($playmode eq "stop")) && ($playmodeOld eq "play") ){
			$log->debug("Pause request from client " . $client->name() ."\n");
			RequestPause($client);
		}

		$playmodeOld = $playmode;

	}
	elsif ( $request->isCommand([['mixer'], ['volume']])) {
		$log->debug("Mixer volume request from client " . $client->name() ."\n");
		my $CurrentVolume = $client->volume();
		$log->debug("Current volume is " . $CurrentVolume . "\n");
		RequestVolume($client, $CurrentVolume);
	}
}


# ----------------------------------------------------------------------------
sub RequestPowerOn {

	my $client = shift;
	my $cprefs = $prefs->client($client);
	my $Cmd = '';

	$Cmd = $cprefs->get('msgOn1');
	
	$log->debug("RequestPowerOn() Msg: " . $Cmd . "\n");
	
	SendCommands($client, $Cmd);

}


# ----------------------------------------------------------------------------
sub RequestPowerOff {

	my $client = shift;
	my $cprefs = $prefs->client($client);
	my $Cmd = '';

	$Cmd = $cprefs->get('msgOff1');
	
	$log->debug("RequestPowerOff() Msg: " . $Cmd . "\n");
	
	SendCommands($client, $Cmd);

}


# ----------------------------------------------------------------------------
sub RequestPlay {

	my $client = shift;
	my $cprefs = $prefs->client($client);
	my $Cmd = '';

	$Cmd = $cprefs->get('msgPlay1');
	
	$log->debug("RequestPlay() Msg: " . $Cmd . "\n");
	
	SendCommands($client, $Cmd);

}


# ----------------------------------------------------------------------------
sub RequestPause {

	my $client = shift;
	my $cprefs = $prefs->client($client);
	my $Cmd = '';

	$Cmd = $cprefs->get('msgPause1');
	
	$log->debug("RequestPause() Msg: " . $Cmd . "\n");
	
	SendCommands($client, $Cmd);

}


# ----------------------------------------------------------------------------
sub RequestVolume {

	my $client = shift;
	my $CurrentVolume = shift;
	my $cprefs = $prefs->client($client);
	my $Cmd = '';

	$Cmd = $cprefs->get('msgVolume1') . "&vollevel=" . $CurrentVolume;
	
	$log->debug("RequestVolume() Msg: " . $Cmd . "\n");
	
	SendCommands($client, $Cmd);

}


# ----------------------------------------------------------------------------
sub SendCommands{

	my $client = shift;
	my $iCmds = shift;
	
	my $cprefs = $prefs->client($client);
	my $iSrvAddress = $cprefs->get('srvAddress');

	if( length($iCmds) > 0 ){
		
		$log->debug("SendCommands: " . $iSrvAddress . $iCmds . "\n");
		
		Plugins::MajorDoMo::MajorDoMoSendMsg::SendCmd($iSrvAddress, $iCmds);	
	
	}
}


1;
