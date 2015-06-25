package Plugins::MajorDoMo::Settings;

use strict;
use base qw(Slim::Web::Settings); 		#driven by the web UI
use Slim::Utils::Strings qw(string); 	#we want to use text from the strings file
use Slim::Utils::Log; 					#we want to use the log methods
use Slim::Utils::Prefs; 				#we want access to the preferences methods

# ----------------------------------------------------------------------------
# Global variables
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# References to other classes
# ----------------------------------------------------------------------------
my $classPlugin		= undef;

# ----------------------------------------------------------------------------
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.MajorDoMo',
	'defaultLevel' => 'ERROR',
	'description'  => 'PLUGIN_MAJORDOMO_MODULE_NAME',
});

# ----------------------------------------------------------------------------
my $prefs = preferences('plugin.MajorDoMo'); #name of preferences file: prefs\plugin\MajorDoMo.pref

# ----------------------------------------------------------------------------
# Define own constructor
# - to save references to Plugin.pm
# ----------------------------------------------------------------------------
sub new {
	my $class = shift;

	$classPlugin = shift;

	$log->debug( "Settings::new() " . $classPlugin . "\n");

	$class->SUPER::new();	

	return $class;
}

# ----------------------------------------------------------------------------
# Name in the settings dropdown
# ----------------------------------------------------------------------------
sub name { #this is what is shown in the players menu on the web gui
	return 'PLUGIN_MAJORDOMO_MODULE_NAME';
}

# ----------------------------------------------------------------------------
# Webpage served for settings
# ----------------------------------------------------------------------------
sub page { #tells which file to use as the web page
	return 'plugins/MajorDoMo/settings/basic.html';
}

# ----------------------------------------------------------------------------
# Settings are per player
# ----------------------------------------------------------------------------
sub needsClient {
	return 1; #this means this is for a particular squeezebox, not the system
}

# ----------------------------------------------------------------------------
# Only show plugin for Squeezebox 3 or Receiver players
# ----------------------------------------------------------------------------
sub validFor {
	my $class = shift;
	my $client = shift;
	# Receiver and Squeezebox2 also means SB3
	return $client->isPlayer && ($client->isa('Slim::Player::Receiver') || 
		                         $client->isa('Slim::Player::Squeezebox2') ||
								 $client->isa('Slim::Player::SqueezeLite') ||
		                         $client->isa('Slim::Player::SqueezeSlave'));
}

# ----------------------------------------------------------------------------
# Handler for settings page
# ----------------------------------------------------------------------------
sub handler {
	my ($class, $client, $params) = @_; 
	#passes the class and client objects along with the parameters

	# $client is the client that is selected on the right side of the web interface!!!
	# We need the client identified by 'playerid'

	# Find player that fits the mac address supplied in $params->{'playerid'}
	my @playerItems = Slim::Player::Client::clients();
	foreach my $play (@playerItems) {
		if( $params->{'playerid'} eq $play->macaddress()) {
			$client = $play; #this particular player
			last;
		}
	}
	if( !defined( $client)) {
		#set the class object with the particular player
		return $class->SUPER::handler($client, $params); 
		$log->debug( "found player: " . $client . "\n");
	}

	
	# Fill in name of player
	if( !$params->{'playername'}) {
		#get the player name but I don't use it
		$params->{'playername'} = $client->name(); 
		$log->debug( "player name: " . $params->{'playername'} . "\n");
	}
	
	# When "Save" is pressed on the settings page, this function gets called.
	if ($params->{'saveSettings'}) {
		#store the enabled value in the client prefs
		if ($params->{'pref_Enabled'}){ #save the enabled state
			$prefs->client($client)->set('pref_Enabled', 1); 
		} else {
			$prefs->client($client)->set('pref_Enabled', 0);
		}
		
		# General settings --------------------------------------------------------------
		if ($params->{'srvAddress'}) { #save the Server IP Address
			my $srvAddress = $params->{'srvAddress'};
			# get rid of leading spaces if any since one is always added.
			$srvAddress =~ s/^(\s*)(.*)(\s*)$/$2/;
			#save the server address in the client prefs
			$prefs->client($client)->set('srvAddress', "$srvAddress"); 
		}
		
		if ($params->{'msgOn1'}) { 
			my $msgOn = $params->{'msgOn1'};
			$prefs->client($client)->set('msgOn1', "$msgOn"); 
		}
		if ($params->{'msgOff1'}) { 
			my $msgOff = $params->{'msgOff1'};
			$prefs->client($client)->set('msgOff1', "$msgOff"); 
		}
		if ($params->{'msgPlay1'}) { 
			my $msgOff = $params->{'msgPlay1'};
			$prefs->client($client)->set('msgPlay1', "$msgOff"); 
		}
		if ($params->{'msgPause1'}) { 
			my $msgOff = $params->{'msgPause1'};
			$prefs->client($client)->set('msgPause1', "$msgOff"); 
		}
		if ($params->{'msgVolume1'}) { 
			my $msgOff = $params->{'msgVolume1'};
			$prefs->client($client)->set('msgVolume1', "$msgOff"); 
		}
		
	}

	# Puts the values on the webpage. 
	#next line takes the stored plugin pref value and puts it on the web page
	#set the enabled checkbox on the web page
	if($prefs->client($client)->get('pref_Enabled') == '1') {
		$params->{'prefs'}->{'pref_Enabled'} = 1; 
	}

	# this puts the text fields in the web page
	$params->{'prefs'}->{'srvAddress'} = $prefs->client($client)->get('srvAddress'); 
	$params->{'prefs'}->{'msgOn1'} = $prefs->client($client)->get('msgOn1'); 
	$params->{'prefs'}->{'msgOff1'} = $prefs->client($client)->get('msgOff1'); 
	$params->{'prefs'}->{'msgPlay1'} = $prefs->client($client)->get('msgPlay1'); 
	$params->{'prefs'}->{'msgPause1'} = $prefs->client($client)->get('msgPause1'); 
	$params->{'prefs'}->{'msgVolume1'} = $prefs->client($client)->get('msgVolume1'); 
	
	
	return $class->SUPER::handler($client, $params);
}

1;

__END__

pref_Enabled