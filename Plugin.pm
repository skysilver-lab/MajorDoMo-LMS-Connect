#	MajorDoMo Connect Pugin
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

my $pluginReady = 0; 
my $playmodeCurrent = 'stop';
my $playmodeOld = 'stop';


# ----------------------------------------------------------------------------
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.MajorDoMo',
	'defaultLevel' => 'ERROR',
	'description'  => 'PLUGIN_MAJORDOMO_MODULE_NAME',
});

# ----------------------------------------------------------------------------
my $prefs    = preferences('plugin.MajorDoMo'); 	#name of preferences file: prefs\plugin\MajorDoMo.pref
my $srvprefs = preferences('server');

# ----------------------------------------------------------------------------
sub initPlugin {
	my $classPlugin = shift;

	# Not Calling our parent class prevents adds it to the player UI for the audio options
	 $classPlugin->SUPER::initPlugin();

	# Initialize settings classes
	my $classSettings = Plugins::MajorDoMo::Settings->new($classPlugin);

	# Install callback to get client setup
	Slim::Control::Request::subscribe( \&newPlayerCheck, [['client']],[['new']]);

	# init the MajorDoMoSendMsg plugin
	Plugins::MajorDoMo::MajorDoMoSendMsg->new( $classPlugin);

}

# ----------------------------------------------------------------------------
sub newPlayerCheck {
	my $request = shift;
	my $client = $request->client();
	
    if ( defined($client) ) {
	    $log->debug( $client->name()." is: " . $client->id() );

		# Do nothing if client is not a Receiver or Squeezebox
		if( !(($client->isa( "Slim::Player::Receiver")) || ($client->isa( "Slim::Player::Squeezebox2")))) {
			$log->debug( "Not a receiver or a squeezebox.\n");
			#now clear callback for those clients that are not part of the plugin
			clearCallback();
			return;
		}
		
		#init the client
		my $cprefs = $prefs->client($client);
		my $pluginEnabled = $cprefs->get('pref_Enabled');
		
		if ( !defined( $pluginEnabled) ){
			$log->debug( "Failed to read prefs for: ".$client->name()."\n");
			$log->debug( "will not be activated.\n");
			clearCallback();
			return;
		}

		# Do nothing if plugin is disabled for this client
		if ( $pluginEnabled == 0) {
			$log->debug( "Plugin Not Enabled for: ".$client->name()."\n");
			clearCallback();
			return;
		} else {
			if ( $pluginEnabled == 1) {
				$log->debug( "Plugin Enabled for: ".$client->name()."\n");
				# Install callback to get client state changes
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
# Callback to get client state changes
# ----------------------------------------------------------------------------
sub commandCallback {
	my $request = shift;

	my $RequestClient = $request->client();
	
	$log->debug( "commandCallback() from client " . $RequestClient->name() ."\n");
	
	my $client = $RequestClient;
	
	my $cprefs = $prefs->client($RequestClient);
	my $pluginEnabled = $cprefs->get('pref_Enabled');
	
	if ( !defined($pluginEnabled) ){
		$log->debug( "Client not configured; maybe a synced player interferes ... \n");
		
		#if we're sync'd, get our buddies
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
	
	# Do nothing if client is not defined
	if(!defined( $client) || $pluginReady==0) {
		$pluginReady=1;
		return;
	}
	
	my $cprefs = $prefs->client($client);
		
	$log->debug( "commandCallback() Client : " . $client->name() . "\n");
	$log->debug( "commandCallback()    p0  : " . $request->{'_request'}[0] . "\n");
	$log->debug( "commandCallback()    p1  : " . $request->{'_request'}[1] . "\n");
	
	my $playmode    = Slim::Player::Source::playmode($client);
	$log->debug("PLAYMODE " . $playmode . "\n");

	if( $request->isCommand([['power']]) ){
		#$log->debug("Power request $request \n");
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
		#$client->volume(0);
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
