#	MajorDoMo Connect Pugin
#
#	Author:	Agaphonov Dmitri <skysilver.da@gmail.com>
#
#	Copyright (c) 2015 Agaphonov Dmitri
#	All rights reserved.
#

package Plugins::MajorDoMo::MajorDoMoSendMsg;

use strict;
use base qw(Slim::Networking::Async);

use URI;
use Slim::Utils::Log;					#для возможности логирования
use Slim::Utils::Misc;
use Slim::Utils::Prefs;					#для использования веб-интерфейса
use Slim::Networking::SimpleAsyncHTTP;	#для выполнения асинхронных HTTP-запросов
use Socket qw(:crlf);


# ----------------------------------------------------------------------------
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.MajorDoMo',
	'defaultLevel' => 'ERROR',
	'description'  => 'PLUGIN_MAJORDOMO_MODULE_NAME',
});

# ----------------------------------------------------------------------------
# Глобальные переменные
# ----------------------------------------------------------------------------
	my $prefs = preferences('plugin.MajorDoMo'); #файл настроек
	my $self;

# ----------------------------------------------------------------------------
# Общие настройки
# ----------------------------------------------------------------------------
my $classPlugin	= undef;

# ----------------------------------------------------------------------------
# Конструктор плагина (тут ничего не меняем)
# ----------------------------------------------------------------------------
sub new {
	my $ref = shift;
	$classPlugin = shift;

	$log->debug( "MajorDoMoSendMsg::new() " . $classPlugin . "\n");
	$self = $ref->SUPER::new;
}

# ----------------------------------------------------------------------------
# Функция обработки строки HTTP-запроса
# ----------------------------------------------------------------------------
sub SendCmd{
	my $Addr = shift;
	my $Cmd = shift;
	my $timeout = 1;
	
	$log->debug("SendCmd - Addr: " . $Addr . ", Cmd: " . $Cmd . "\n");
	
	my $http = "http://";
	
	if( index($Addr, $http) == 0 ) {
		HTTPSend($Addr, $Cmd);
	}
	else{
		$log->debug("SendCmd - Wrong server address. \n");
	}	
}

# ----------------------------------------------------------------------------
# Функция выполнения HTTP-запроса
# ----------------------------------------------------------------------------
sub HTTPSend{
	my $Addr = shift;
	my $Cmd = shift;
	my $timeout = 1;
	
	$log->debug("HTTPSend - Addr: " . $Addr . ", Cmd: " . $Cmd . "\n");
	
	my $http = Slim::Networking::SimpleAsyncHTTP->new(
			\&HttpSuccess,
			\&HttpError, 
			{
				#mydata'  => 'foo',
				#cache    => 0,		# optional, cache result of HTTP request
				#expires => '1h',	# optional, specify the length of time to cache
			}
	);
	
	my $url = $Addr . $Cmd;
	
	$http->get($url);
}


# ----------------------------------------------------------------------------
sub HttpError {
    my $http = shift;

    $log->debug("Error HTTP send! \n");
}


# ----------------------------------------------------------------------------
sub HttpSuccess{
    my $http = shift;

    my $content = $http->content();
	
	$log->debug("HTTP Response: " . $content . "\n");
}


1;