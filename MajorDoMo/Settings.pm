package Plugins::MajorDoMo::Settings;

use strict;
use base qw(Slim::Web::Settings); 		#для использования веб-интерфейса
use Slim::Utils::Strings qw(string); 	#для использования строк из текстовых файлов
use Slim::Utils::Log; 					#для возможности логирования
use Slim::Utils::Prefs; 				#для доступа к файлам настроек

# ----------------------------------------------------------------------------
# Глобальные переменные
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# Общие настройки
# ----------------------------------------------------------------------------
my $classPlugin		= undef;

my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.MajorDoMo',
	'defaultLevel' => 'ERROR',
	'description'  => 'PLUGIN_MAJORDOMO_MODULE_NAME',
});

# ----------------------------------------------------------------------------
# Путь и имя файла для хранения настроек плагина: prefs\plugin\MajorDoMo.pref
# ----------------------------------------------------------------------------
my $prefs = preferences('plugin.MajorDoMo');

# ----------------------------------------------------------------------------
# Конструктор плагина (тут ничего не меняем)
# ----------------------------------------------------------------------------
sub new {
	my $class = shift;

	$classPlugin = shift;

	$log->debug( "Settings::new() " . $classPlugin . "\n");

	$class->SUPER::new();	

	return $class;
}

# ----------------------------------------------------------------------------
# Название пункта настроек плагина в веб-интерфейсе
# ----------------------------------------------------------------------------
sub name {
	return 'PLUGIN_MAJORDOMO_MODULE_NAME';
}

# ----------------------------------------------------------------------------
# Путь к странице настроек
# ----------------------------------------------------------------------------
sub page { #какой файл использовать в качестве веб страницы
	return 'plugins/MajorDoMo/settings/basic.html';
}

# ----------------------------------------------------------------------------
# Настройки индивидуальные для каждого плеера, поэтому возвращаем 1
# ----------------------------------------------------------------------------
sub needsClient {
	return 1;
}

# ----------------------------------------------------------------------------
# Выбираем для каких плееров можно использовать этот плагин
# ----------------------------------------------------------------------------
sub validFor {
	my $class = shift;
	my $client = shift;
	
	return $client->isPlayer && ($client->isa('Slim::Player::Receiver') || 
		                         $client->isa('Slim::Player::Squeezebox2') ||
								 $client->isa('Slim::Player::SqueezeLite') ||
		                         $client->isa('Slim::Player::SqueezeSlave'));
}

# ----------------------------------------------------------------------------
# Обработчик страницы настроек плагина
# ----------------------------------------------------------------------------
sub handler {
	my ($class, $client, $params) = @_; 
	
	# $client - объект клиента (плеера), который выбран в веб-интерфейсе
	# Клиенты идентифицируются по 'playerid', равному мак-адресу плеера.

	my @playerItems = Slim::Player::Client::clients();
	foreach my $play (@playerItems) {
		if( $params->{'playerid'} eq $play->macaddress()) {
			$client = $play;
			last;
		}
	}
	if( !defined( $client)) {
		return $class->SUPER::handler($client, $params); 
		$log->debug( "found player: " . $client . "\n");
	}

	if( !$params->{'playername'}) {
		$params->{'playername'} = $client->name(); 
		$log->debug( "player name: " . $params->{'playername'} . "\n");
	}
	
	# Функция, вызываемая при нажатии на кнопку "Сохранить"
	if ($params->{'saveSettings'}) {
		
		#Сохраняем значения в файл настроек
		
		if ($params->{'pref_Enabled'}){ #Статус плагина для плеера - включен или выключен
			$prefs->client($client)->set('pref_Enabled', 1); 
		} else {
			$prefs->client($client)->set('pref_Enabled', 0);
		}
		
		
		if ($params->{'srvAddress'}) { #IP-адрес сервера MajorDoMo
			my $srvAddress = $params->{'srvAddress'};
			$srvAddress =~ s/^(\s*)(.*)(\s*)$/$2/;
			$prefs->client($client)->set('srvAddress', "$srvAddress"); 
		}
		
		# HTTP-запросы для разных состояний плеера
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

	# Заполняем поля на странице настроек плагина в веб-интерфейсе.
	# Значения берутся из файла настроек.
	if($prefs->client($client)->get('pref_Enabled') == '1') {
		$params->{'prefs'}->{'pref_Enabled'} = 1; 
	}

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