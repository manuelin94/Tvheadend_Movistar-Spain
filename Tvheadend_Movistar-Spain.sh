#!/bin/sh
#Formatear texto con colores: https://unix.stackexchange.com/a/92568
red='\e[1;31m'
green='\e[1;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
magenta='\e[1;35m'
cyan='\e[1;36m'
end='\e[0m'

clear
if [[ $(id -u) -ne 0 ]]; then
	printf "$red%s$end\n" "ERROR: Por favor, ejecute el script como root.
	
	Puede hacerlo de diferentes formas:
	- Mediante el comando \"sudo $0\"
	- Entrando en la sesión del propio root con \"sudo -i\"
	  y después ejecutando el script con \"$0\"
	- Logeándote con el usuario root en vez del usuario $USER"
	exit 1
fi


if [[ -z "$COLUMNS" ]]; then
	COLUMNS=80
fi


LIST_ERROR=false #INSTALLED_LIST=true
GRABBER_ERROR=false #INSTALLED_GRABBER=true
SERVICE_ERROR=false


LOCAL_SCRIPT_VERSION="20170501"
REMOTE_SCRIPT_VERSION="$(curl -fLs https://github.com/manuelin94/Tvheadend_Movistar-Spain/raw/master/version.txt | grep ^"SCRIPT_VERSION" | cut -d'=' -f2)"
URL_SCRIPT="https://github.com/manuelin94/Tvheadend_Movistar-Spain/raw/master/Tvheadend_Movistar-Spain.sh"

if [ $LOCAL_SCRIPT_VERSION -lt $REMOTE_SCRIPT_VERSION ]; then
	echo "Hay disponible una versión más reciente del script, se va a proceder a su descarga."
	
	sleep 6
	
	printf "%-$(($COLUMNS-10))s"  " * Actualizando el script $(basename $0)"
	wget -qO "$(basename $0)" "$URL_SCRIPT" 2>/dev/null
	if [ $? -eq 0 ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
		chmod +x "$(basename $0)" 2>/dev/null
		echo -e "\nScript actualizado correctamente.\nPor favor, vuelva a ejecutar el script de nuevo."
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
		echo -e "\nEl script no se ha podido actualizar.\nPor favor, vuelva a intentarlo más tarde o descargue de nuevo la versión actual del script."
	fi
	exit 1
fi


SYSTEM_INFO="$(uname -a)"
SYSTEM=0
if [ "${SYSTEM_INFO#*"synology"}" != "$SYSTEM_INFO" ]; then
	read -p "Se ha detectado el sistema operativo Synology/XPEnology. ¿Es correcto? [S/n] " OPTION
	if [ "$OPTION" = "s" -o "$OPTION" = "S" -o "$OPTION" = "" ]; then
		SYSTEM=1
	fi
elif [ "${SYSTEM_INFO#*"LibreELEC"}" != "$SYSTEM_INFO" -o "${SYSTEM_INFO#*"OpenELEC"}" != "$SYSTEM_INFO" ]; then
	read -p "Se ha detectado el sistema operativo LibreELEC/OpenELEC. ¿Es correcto? [S/n] " OPTION
	if [ "$OPTION" = "s" -o "$OPTION" = "S" -o "$OPTION" = "" ]; then
		SYSTEM=2
	fi
fi

while [ $SYSTEM -ne 1 ] && [ $SYSTEM -ne 2 ] && [ $SYSTEM -ne 3 ]; do
	clear
	echo -e "Seleccione el sistema operativo que está utilizando:\n\t1- Synology/XPEnology\n\t2- LibreELEC/OpenELEC\n\t3- Linux"
	read -p "Opción: " SYSTEM
	case $SYSTEM in
		1)
			read -p "Se ha elegido la opción 1 (Synology/XPEnology), ¿es correcto? [S/n] " OPTION
			if [ "$OPTION" != "s" -a "$OPTION" != "S" -a "$OPTION" != "" ]; then
				SYSTEM=0
			fi;;
		2)
			read -p "Se ha elegido la opción 2 (LibreELEC/OpenELEC), ¿es correcto? [S/n] " OPTION
			if [ "$OPTION" != "s" -a "$OPTION" != "S" -a "$OPTION" != "" ]; then
				SYSTEM=0
			fi;;
		3)
			read -p "Se ha elegido la opción 3 (Linux), ¿es correcto? [S/n] " OPTION
			if [ "$OPTION" != "s" -a "$OPTION" != "S" -a "$OPTION" != "" ]; then
				SYSTEM=0
			fi;;
		*)
			printf "$red%s$end\n" "ERROR: Se ha elegido una opción incorrecta. Por favor, vuelva a elegir de nuevo."
			SYSTEM=0
			sleep 4;;
	esac
done

case $SYSTEM in
	1)
		TVHEADEND_SERVICE="$(synoservicecfg --list | grep tvheadend)" #"pkgctl-tvheadend-testing"
		if [ $? -ne 0 ]; then
			SERVICES_MANAGEMENT="OLD"
		else
			SERVICES_MANAGEMENT="NEW"
		fi
		TVHEADEND_USER="$(cut -d: -f1 /etc/passwd | grep tvheadend)" #"tvheadend-testing"
		TVHEADEND_GROUP="$(id -gn $TVHEADEND_USER)" #"users"
		TVHEADEND_PERMISSIONS="700" #"u=rwX,g=,o="
		TVHEADEND_CONFIG_DIR="/var/packages/$(ls /var/packages/ | grep tvheadend)/target/var" #"/var/packages/tvheadend-testing/target/var"
		TVHEADEND_GRABBER_DIR="/usr/local/bin";;
	2)
		TVHEADEND_SERVICE="$(systemctl list-unit-files --type=service | grep tvheadend | tr -s ' ' | cut -d' ' -f1)" #"service.tvheadend42.service"
		TVHEADEND_USER="root"
		TVHEADEND_GROUP="video"
		TVHEADEND_PERMISSIONS="700" #"u=rwX,g=,o="
		TVHEADEND_CONFIG_DIR="/storage/.kodi/userdata/addon_data/$(ls /storage/.kodi/userdata/addon_data/ | grep tvheadend)" #"/storage/.kodi/userdata/addon_data/service.tvheadend42"
		TVHEADEND_GRABBER_DIR="/storage/.kodi/addons/$(ls /storage/.kodi/addons/ | grep tvheadend)/bin";; #"/storage/.kodi/addons/service.tvheadend42/bin"
	3)
		TVHEADEND_SERVICE="$(systemctl list-unit-files --type=service | grep tvheadend | tr -s ' ' | cut -d' ' -f1)" #"tvheadend.service"
		TVHEADEND_USER="$(cut -d: -f1 /etc/passwd | grep -E 'tvheadend|hts')" #"hts"
		TVHEADEND_GROUP="video" #"$(id -gn $TVHEADEND_USER)"
		TVHEADEND_PERMISSIONS="700" #"u=rwX,g=,o="
		TVHEADEND_CONFIG_DIR="/home/hts/.hts/tvheadend"
		TVHEADEND_GRABBER_DIR="/usr/local/bin";;
esac


clear
if [ "$1" = "-b" -o "$1" = "-B" ]; then
	printf "%-$(($COLUMNS-10))s"  " * Deteniendo Tvheadend"
	case $SYSTEM in
		1)
			if [ "$SERVICES_MANAGEMENT" = "OLD" ]; then
				"/var/packages/$(ls /var/packages/ | grep tvheadend)/scripts/start-stop-status" stop 1>/dev/null 2>&1
			else
				stop -q $TVHEADEND_SERVICE 2>/dev/null
			fi;;
		2)
			systemctl stop $TVHEADEND_SERVICE 2>/dev/null;;
		3)
			systemctl stop $TVHEADEND_SERVICE 2>/dev/null;;
	esac
	if [ $? -eq 0 ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
	fi
	
	printf "%-$(($COLUMNS-10))s"  " * Realizando backup de la configuración actual"
	SCRIPT_ROUTE="$PWD"
	cd $TVHEADEND_CONFIG_DIR
	if [ -f "$SCRIPT_ROUTE/Backup_configuracion_Tvheadend_$(date +"%Y-%m-%d").tar.xz" ]; then
		FILE="Backup_configuracion_Tvheadend_$(date +"%Y-%m-%d--%H-%M-%S").tar.xz"
		tar -cJf $SCRIPT_ROUTE/$FILE channel epggrab/xmltv input/dvb Picons
	else
		FILE="Backup_configuracion_Tvheadend_$(date +"%Y-%m-%d").tar.xz"
		tar -cJf $SCRIPT_ROUTE/$FILE channel epggrab/xmltv input/dvb Picons
	fi
	if [ $? -eq 0 ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
		echo -e "\tBackup creado: $FILE"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
	fi
	
	printf "%-$(($COLUMNS-10))s"  " * Iniciando Tvheadend"
	case $SYSTEM in
		1)
			if [ "$SERVICES_MANAGEMENT" = "OLD" ]; then
				"/var/packages/$(ls /var/packages/ | grep tvheadend)/scripts/start-stop-status" start 1>/dev/null 2>&1
			else
				start -q $TVHEADEND_SERVICE 2>/dev/null
			fi;;
		2)
			systemctl start $TVHEADEND_SERVICE 2>/dev/null;;
		3)
			systemctl start $TVHEADEND_SERVICE 2>/dev/null;;
	esac
	if [ $? -eq 0 ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
	fi
	
	exit 1
fi


if [[ -d $TVHEADEND_CONFIG_DIR/channel ]]; then
	TVHEADEND_CHANNEL_USER=$(stat -c %U $TVHEADEND_CONFIG_DIR/channel) 2>/dev/null
	TVHEADEND_CHANNEL_GROUP=$(stat -c %G $TVHEADEND_CONFIG_DIR/channel) 2>/dev/null
	TVHEADEND_CHANNEL_PERMISSIONS=$(stat -c %a $TVHEADEND_CONFIG_DIR/channel) 2>/dev/null
	if [ $? -ne 0 ]; then
		TVHEADEND_CHANNEL_USER=$TVHEADEND_USER
		TVHEADEND_CHANNEL_GROUP=$TVHEADEND_GROUP
		TVHEADEND_CHANNEL_PERMISSIONS=$TVHEADEND_PERMISSIONS
	fi
else
	TVHEADEND_CHANNEL_USER=$TVHEADEND_USER
	TVHEADEND_CHANNEL_GROUP=$TVHEADEND_GROUP
	TVHEADEND_CHANNEL_PERMISSIONS=$TVHEADEND_PERMISSIONS
fi

if [[ -d $TVHEADEND_CONFIG_DIR/epggrab ]]; then
	TVHEADEND_EPGGRAB_USER=$(stat -c %U $TVHEADEND_CONFIG_DIR/epggrab) 2>/dev/null
	TVHEADEND_EPGGRAB_GROUP=$(stat -c %G $TVHEADEND_CONFIG_DIR/epggrab) 2>/dev/null
	TVHEADEND_EPGGRAB_PERMISSIONS=$(stat -c %a $TVHEADEND_CONFIG_DIR/epggrab) 2>/dev/null
	if [ $? -ne 0 ]; then
		TVHEADEND_EPGGRAB_USER=$TVHEADEND_USER
		TVHEADEND_EPGGRAB_GROUP=$TVHEADEND_GROUP
		TVHEADEND_EPGGRAB_PERMISSIONS=$TVHEADEND_PERMISSIONS
	fi
else
	TVHEADEND_EPGGRAB_USER=$TVHEADEND_USER
	TVHEADEND_EPGGRAB_GROUP=$TVHEADEND_GROUP
	TVHEADEND_EPGGRAB_PERMISSIONS=$TVHEADEND_PERMISSIONS
fi

if [[ -d $TVHEADEND_CONFIG_DIR/input ]]; then
	TVHEADEND_INPUT_USER=$(stat -c %U $TVHEADEND_CONFIG_DIR/input) 2>/dev/null
	TVHEADEND_INPUT_GROUP=$(stat -c %G $TVHEADEND_CONFIG_DIR/input) 2>/dev/null
	TVHEADEND_INPUT_PERMISSIONS=$(stat -c %a $TVHEADEND_CONFIG_DIR/input) 2>/dev/null
	if [ $? -ne 0 ]; then
		TVHEADEND_INPUT_USER=$TVHEADEND_USER
		TVHEADEND_INPUT_GROUP=$TVHEADEND_GROUP
		TVHEADEND_INPUT_PERMISSIONS=$TVHEADEND_PERMISSIONS
	fi
else
	TVHEADEND_INPUT_USER=$TVHEADEND_USER
	TVHEADEND_INPUT_GROUP=$TVHEADEND_GROUP
	TVHEADEND_INPUT_PERMISSIONS=$TVHEADEND_PERMISSIONS
fi

if [[ -d $TVHEADEND_CONFIG_DIR/Picons ]]; then
	TVHEADEND_PICONS_USER=$(stat -c %U $TVHEADEND_CONFIG_DIR/Picons) 2>/dev/null
	TVHEADEND_PICONS_GROUP=$(stat -c %G $TVHEADEND_CONFIG_DIR/Picons) 2>/dev/null
	TVHEADEND_PICONS_PERMISSIONS=$(stat -c %a $TVHEADEND_CONFIG_DIR/Picons) 2>/dev/null
	if [ $? -ne 0 ]; then
		TVHEADEND_PICONS_USER=$TVHEADEND_USER
		TVHEADEND_PICONS_GROUP=$TVHEADEND_GROUP
		TVHEADEND_PICONS_PERMISSIONS=$TVHEADEND_PERMISSIONS
	fi
else
	TVHEADEND_PICONS_USER=$TVHEADEND_USER
	TVHEADEND_PICONS_GROUP=$TVHEADEND_GROUP
	TVHEADEND_PICONS_PERMISSIONS=$TVHEADEND_PERMISSIONS
fi


REMOTE_LIST_VERSION="$(curl -fLs https://github.com/manuelin94/Tvheadend_Movistar-Spain/raw/master/version.txt | grep ^"LIST_VERSION" | cut -d'=' -f2)"
URL_LIST="https://github.com/manuelin94/Tvheadend_Movistar-Spain/raw/master/files/Configuracion_Tvheadend_$REMOTE_LIST_VERSION.tar.xz"

REMOTE_GRABBER_VERSION="$(curl -fLs https://github.com/manuelin94/Tvheadend_Movistar-Spain/raw/master/version.txt | grep ^"GRABBER_VERSION" | cut -d'=' -f2)"
URL_GRABBER="https://github.com/manuelin94/Tvheadend_Movistar-Spain/raw/master/files/tv_grab_movistar-spain"


if [ -f $TVHEADEND_CONFIG_DIR/version.txt ]; then
	LOCAL_LIST_VERSION="$(grep ^"LIST_VERSION" $TVHEADEND_CONFIG_DIR/version.txt | cut -d'=' -f2)"
	LOCAL_GRABBER_VERSION="$(grep ^"GRABBER_VERSION" $TVHEADEND_CONFIG_DIR/version.txt | cut -d'=' -f2)"
	
	if [ $LOCAL_LIST_VERSION -gt 0 ]; then
		clear
		echo "Se ha detectado una versión de la lista de canales previamente instalada."
		printf "%s$blue%s$end\n\t$blue%s$end%s\t$blue%s$end%s\n" "- " "Lista de canales:" "Versión instalada: " "$LOCAL_LIST_VERSION" "Última versión disponible: " "$REMOTE_LIST_VERSION"
		if [ $LOCAL_LIST_VERSION -lt $REMOTE_LIST_VERSION ]; then
			echo "Hay disponible una versión más reciente de la lista de canales, se va a proceder a su descarga y posterior instalación."
			INSTALL_LIST=true
			sleep 10
		else
			echo "Su lista de canales ya está actualizada y por tanto no hace falta que se vuelva a instalar."
			read -p "¿Desea reinstalar la lista de canales? [S/n] " REINSTALAR
			if [ "$REINSTALAR" = "s" -o "$REINSTALAR" = "S" -o "$REINSTALAR" = "" ]; then
				INSTALL_LIST=true
			else
				INSTALL_LIST=false
			fi
		fi
	else
		INSTALL_LIST=true
	fi
	
	sleep 1
	
	if [ $LOCAL_GRABBER_VERSION -gt 0 ]; then
		clear
		echo "Se ha detectado una versión del grabber de Movistar+ previamente instalada."
		printf "%s$blue%s$end\n\t$blue%s$end%s\t$blue%s$end%s\n" "- " "Grabber (EPG de canales):" "Versión instalada: " "$LOCAL_GRABBER_VERSION" "Última versión disponible: " "$REMOTE_GRABBER_VERSION"
		if [ $LOCAL_GRABBER_VERSION -lt $REMOTE_GRABBER_VERSION ]; then
			echo "Hay disponible una versión más reciente del grabber, se va a proceder a su descarga y posterior instalación."
			INSTALL_GRABBER=true
			sleep 10
		else
			echo "Su grabber ya está actualizada y por tanto no hace falta que se vuelva a instalar."
			read -p "¿Desea reinstalar el grabber? [S/n] " REINSTALAR
			if [ "$REINSTALAR" = "s" -o "$REINSTALAR" = "S" -o "$REINSTALAR" = "" ]; then
				INSTALL_GRABBER=true
			else
				INSTALL_GRABBER=false
			fi
		fi
	else
		if [ -f $TVHEADEND_GRABBER_DIR/tv_grab_movistar-spain -o "$1" = "-g" -o "$1" = "-G" ]; then
			INSTALL_GRABBER=true
		else
			INSTALL_GRABBER=false
		fi
	fi
else
	LOCAL_LIST_VERSION=0
	LOCAL_GRABBER_VERSION=0
	
	INSTALL_LIST=true
	
	if [ -f $TVHEADEND_GRABBER_DIR/tv_grab_movistar-spain -o "$1" = "-g" -o "$1" = "-G" ]; then
		INSTALL_GRABBER=true
	else
		INSTALL_GRABBER=false
	fi
fi


if [ "$INSTALL_LIST" = false -a "$INSTALL_GRABBER" = false ]; then
	exit 1
fi


clear
printf "%-$(($COLUMNS-10))s"  " * Deteniendo Tvheadend"
case $SYSTEM in
	1)
		if [ "$SERVICES_MANAGEMENT" = "OLD" ]; then
			"/var/packages/$(ls /var/packages/ | grep tvheadend)/scripts/start-stop-status" stop 1>/dev/null 2>&1
		else
			stop -q $TVHEADEND_SERVICE 2>/dev/null
		fi;;
	2)
		systemctl stop $TVHEADEND_SERVICE 2>/dev/null;;
	3)
		systemctl stop $TVHEADEND_SERVICE 2>/dev/null;;
esac
if [ $? -eq 0 ]; then
	printf "%s$green%s$end%s\n" "[" "  OK  " "]"
else
	printf "%s$red%s$end%s\n" "[" "FAILED" "]"
	SERVICE_ERROR=true
fi


if [ "$INSTALL_LIST" = true ]; then
	printf "%-$(($COLUMNS-10))s"  " * Descargando lista de canales"
	wget -qO "Configuracion_Tvheadend_$REMOTE_LIST_VERSION.tar.xz" "$URL_LIST" 2>/dev/null
	if [ $? -eq 0 ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
		echo -e "\nLa lista de canales no se ha podido descargar.\nPor favor, vuelva a intentarlo más tarde."
		exit 1
	fi
	
	
	printf "%-$(($COLUMNS-10+1))s"  " * Eliminando la configuración actual"
	rm -rf $TVHEADEND_CONFIG_DIR/channel $TVHEADEND_CONFIG_DIR/input/dvb $TVHEADEND_CONFIG_DIR/Picons 2>/dev/null
	if [ $? -eq 0 ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
		LIST_ERROR=true
	fi
	
	
	printf "%-$(($COLUMNS-10+1))s"  " * Aplicando la configuración nueva"
	tar -Jxf "Configuracion_Tvheadend_$REMOTE_LIST_VERSION.tar.xz" -C $TVHEADEND_CONFIG_DIR channel input Picons 2>/dev/null #--strip-components=1
	if [ $? -eq 0 ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
		LIST_ERROR=true
	fi
	
	
	printf "%-$(($COLUMNS-10+1))s"  " * Aplicando permisos a los ficheros de configuración"
	ERROR=false
	chown -R $TVHEADEND_CHANNEL_USER:$TVHEADEND_CHANNEL_GROUP $TVHEADEND_CONFIG_DIR/channel 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	find $TVHEADEND_CONFIG_DIR/channel -type d -exec chmod $TVHEADEND_CHANNEL_PERMISSIONS 2>/dev/null {} \;
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	find $TVHEADEND_CONFIG_DIR/channel -type f -exec chmod $(($TVHEADEND_CHANNEL_PERMISSIONS-100)) 2>/dev/null {} \;
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	chown -R $TVHEADEND_INPUT_USER:$TVHEADEND_INPUT_GROUP $TVHEADEND_CONFIG_DIR/input 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	find $TVHEADEND_CONFIG_DIR/input -type d -exec chmod $TVHEADEND_INPUT_PERMISSIONS 2>/dev/null {} \;
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	find $TVHEADEND_CONFIG_DIR/input -type f -exec chmod $(($TVHEADEND_INPUT_PERMISSIONS-100)) 2>/dev/null {} \;
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	chown -R $TVHEADEND_PICONS_USER:$TVHEADEND_PICONS_GROUP $TVHEADEND_CONFIG_DIR/Picons 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	find $TVHEADEND_CONFIG_DIR/Picons -type d -exec chmod $TVHEADEND_PICONS_PERMISSIONS 2>/dev/null {} \;
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	find $TVHEADEND_CONFIG_DIR/Picons -type f -exec chmod $(($TVHEADEND_PICONS_PERMISSIONS-100)) 2>/dev/null {} \;
	if [ $? -eq 0 -a $ERROR = "false" ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
		LIST_ERROR=true
	fi
	
	
	printf "%-$(($COLUMNS-10))s"  " * Configurando Tvheadend"
	ERROR=false
	sed -i '/"chiconscheme": .*,/d' $TVHEADEND_CONFIG_DIR/config 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	sed -i '/"piconpath": .*,/d' $TVHEADEND_CONFIG_DIR/config 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	sed -i '/"piconscheme": .*,/d' $TVHEADEND_CONFIG_DIR/config 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	sed -i 's/"prefer_picon": .*,/"prefer_picon": false,\n\t"chiconscheme": 0,\n\t"piconpath": "file:\/\/\/var\/packages\/tvheadend-testing\/target\/var\/Picons",\n\t"piconscheme": 1,/g' $TVHEADEND_CONFIG_DIR/config 2>/dev/null
	if [ $? -eq 0 -a $ERROR = "false" ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
		LIST_ERROR=true
	fi
fi


if [ "$INSTALL_GRABBER" = true ]; then
	if [ ! -f "Configuracion_Tvheadend_$REMOTE_LIST_VERSION.tar.xz" ]; then
		printf "%-$(($COLUMNS-10))s"  " * Descargando lista de canales"
		wget -qO "Configuracion_Tvheadend_$REMOTE_LIST_VERSION.tar.xz" "$URL_LIST" 2>/dev/null
		if [ $? -eq 0 ]; then
			printf "%s$green%s$end%s\n" "[" "  OK  " "]"
		else
			printf "%s$red%s$end%s\n" "[" "FAILED" "]"
			echo -e "\nLa lista de canales no se ha podido descargar.\nPor favor, vuelva a intentarlo más tarde."
			exit 1
		fi
	fi
	
	printf "%-$(($COLUMNS-10))s"  " * Descargando grabber de Movistar+"
	wget -qO "tv_grab_movistar-spain" "$URL_GRABBER" 2>/dev/null
	if [ $? -eq 0 ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
		echo -e "\nEl grabber de Movistar+ no se ha podido descargar.\nPor favor, vuelva a intentarlo más tarde."
		exit 1
	fi
	
	printf "%-$(($COLUMNS-10))s"  " * Instalando grabber de Movistar+"
	if [ -f /usr/bin/tv_grab_movistar-spain ]; then
		rm /usr/bin/tv_grab_movistar-spain 2>/dev/null
	fi
	ERROR=false
	rm -rf $TVHEADEND_CONFIG_DIR/epggrab/xmltv 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	tar -Jxf "Configuracion_Tvheadend_$REMOTE_LIST_VERSION.tar.xz" -C $TVHEADEND_CONFIG_DIR epggrab 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	if [ $SYSTEM -eq 2 ]; then
		sed -i -- "s,/usr/local/bin,$TVHEADEND_GRABBER_DIR,g" $TVHEADEND_CONFIG_DIR/epggrab/xmltv/channels/* epggrab 2>/dev/null
		if [ $? -ne 0 ]; then
			ERROR=true
		fi
	fi
	chown -R $TVHEADEND_EPGGRAB_USER:$TVHEADEND_EPGGRAB_GROUP $TVHEADEND_CONFIG_DIR/epggrab 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	find $TVHEADEND_CONFIG_DIR/epggrab -type d -exec chmod $TVHEADEND_EPGGRAB_PERMISSIONS 2>/dev/null {} \;
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	find $TVHEADEND_CONFIG_DIR/epggrab -type f -exec chmod $(($TVHEADEND_EPGGRAB_PERMISSIONS-100)) 2>/dev/null {} \;
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	if [ ! -d $TVHEADEND_GRABBER_DIR ]; then
		mkdir -p $TVHEADEND_GRABBER_DIR 2>/dev/null
	fi
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	cp tv_grab_movistar-spain $TVHEADEND_GRABBER_DIR/ 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	chown $TVHEADEND_USER:$TVHEADEND_GROUP $TVHEADEND_GRABBER_DIR/tv_grab_movistar-spain 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	chmod $(($TVHEADEND_PERMISSIONS-100)) $TVHEADEND_GRABBER_DIR/tv_grab_movistar-spain 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	chmod +rx $TVHEADEND_GRABBER_DIR/tv_grab_movistar-spain 2>/dev/null
	if [ $? -eq 0 -a $ERROR = "false" ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
		GRABBER_ERROR=true
	fi
	
	
	printf "%-$(($COLUMNS-10))s"  " * Iniciando Tvheadend"
	case $SYSTEM in
		1)
			if [ "$SERVICES_MANAGEMENT" = "OLD" ]; then
				"/var/packages/$(ls /var/packages/ | grep tvheadend)/scripts/start-stop-status" start 1>/dev/null 2>&1
			else
				start -q $TVHEADEND_SERVICE 2>/dev/null
			fi;;
		2)
			systemctl start $TVHEADEND_SERVICE 2>/dev/null;;
		3)
			systemctl start $TVHEADEND_SERVICE 2>/dev/null;;
	esac
	if [ $? -eq 0 ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
		SERVICE_ERROR=true
	fi
	
	sleep 4
	
	if [ ! -f $TVHEADEND_CONFIG_DIR/epggrab/config ]; then
		printf '%*s' $COLUMNS | tr ' ' "-"
		printf "$red%s$end\n\n" "¡No continúe hasta que haga lo siguiente!:"
		printf "%s\n\t%s$blue%s$end%s$blue%s$end%s$blue%s$end\n\t%s\n" "Es necesario que entre en la interfaz web del Tvheadend y se dirija al apartado:" "- " "Configuración"  " >> " "Canal / EPG" " >> " "Módulos para Obtención de Guía" "  (en inglés: Configuration >> Channel / EPG >> EPG Grabber Modules)"
		printf "\n%s\n" "Una vez esté situado aquí, haga lo siguiente:"
		printf "\t%s$blue%s$end\n" "1- Seleccione el grabber " "\"XMLTV: Movistar+\""
		printf "\t%s$blue%s$end\n\t%s\n" "2- En el menú lateral marque la casilla " "\"Habilitado\"" "  (en inglés \"Enabled\")"
		printf "\t%s$blue%s$end\n\t%s\n\n" "3- Finalmente, pulse sobre el botón superior " "\"Guardar\"" "  (en inglés \"Save\")"
		
		CONTINUAR="n"
		while [ "$CONTINUAR" != "s" ] && [ "$CONTINUAR" != "S" ] && [ "$CONTINUAR" != "" ]; do
			read -p "Una vez haya realizado este proceso ya puede continuar. ¿Desea continuar? [S/n]" CONTINUAR
		done
		printf '%*s' $COLUMNS | tr ' ' "-"
	fi
	
	
	printf "%-$(($COLUMNS-10))s"  " * Deteniendo Tvheadend"
	case $SYSTEM in
		1)
			if [ "$SERVICES_MANAGEMENT" = "OLD" ]; then
				"/var/packages/$(ls /var/packages/ | grep tvheadend)/scripts/start-stop-status" stop 1>/dev/null 2>&1
			else
				stop -q $TVHEADEND_SERVICE 2>/dev/null
			fi;;
		2)
			systemctl stop $TVHEADEND_SERVICE 2>/dev/null;;
		3)
			systemctl stop $TVHEADEND_SERVICE 2>/dev/null;;
	esac
	if [ $? -eq 0 ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
		SERVICE_ERROR=true
	fi
	
	
	printf "%-$(($COLUMNS-10))s"  " * Habilitando grabber de Movistar+"
	ERROR=false
	sed -i '/tv_grab_movistar-spain/,/},/d' $TVHEADEND_CONFIG_DIR/epggrab/config 2>/dev/null
	if [ $? -ne 0 ]; then
		ERROR=true
	fi
	if [ $SYSTEM -eq 2 ]; then
		sed -i 's/"modules": {/"modules": {\n\t\t"\/storage\/.kodi\/addons\/service.tvheadend42\/bin\/tv_grab_movistar-spain": {\n\t\t\t"class": "epggrab_mod_int_xmltv",\n\t\t\t"dn_chnum": 0,\n\t\t\t"name": "XMLTV: Movistar+",\n\t\t\t"type": "Internal",\n\t\t\t"enabled": true,\n\t\t\t"priority": 3\n\t\t},/g' $TVHEADEND_CONFIG_DIR/epggrab/config 2>/dev/null
	else
		sed -i 's/"modules": {/"modules": {\n\t\t"\/usr\/local\/bin\/tv_grab_movistar-spain": {\n\t\t\t"class": "epggrab_mod_int_xmltv",\n\t\t\t"dn_chnum": 0,\n\t\t\t"name": "XMLTV: Movistar+",\n\t\t\t"type": "Internal",\n\t\t\t"enabled": true,\n\t\t\t"priority": 3\n\t\t},/g' $TVHEADEND_CONFIG_DIR/epggrab/config 2>/dev/null
	fi
	if [ $? -eq 0 -a $ERROR = "false" ]; then
		printf "%s$green%s$end%s\n" "[" "  OK  " "]"
	else
		printf "%s$red%s$end%s\n" "[" "FAILED" "]"
		GRABBER_ERROR=true
	fi
fi

printf "%-$(($COLUMNS-10))s"  " * Iniciando Tvheadend"
case $SYSTEM in
	1)
		if [ "$SERVICES_MANAGEMENT" = "OLD" ]; then
			"/var/packages/$(ls /var/packages/ | grep tvheadend)/scripts/start-stop-status" start 1>/dev/null 2>&1
		else
			start -q $TVHEADEND_SERVICE 2>/dev/null
		fi;;
	2)
		systemctl start $TVHEADEND_SERVICE 2>/dev/null;;
	3)
		systemctl start $TVHEADEND_SERVICE 2>/dev/null;;
esac
if [ $? -eq 0 ]; then
	printf "%s$green%s$end%s\n" "[" "  OK  " "]"
else
	printf "%s$red%s$end%s\n" "[" "FAILED" "]"
	SERVICE_ERROR=true
fi


if [ "$LIST_ERROR" = true -a "$GRABBER_ERROR" = true ]; then
	echo -e "LIST_VERSION=$LOCAL_LIST_VERSION\nGRABBER_VERSION=$LOCAL_GRABBER_VERSION" > $TVHEADEND_CONFIG_DIR/version.txt
elif [ "$LIST_ERROR" = true -a "$GRABBER_ERROR" = false ]; then
	echo -e "LIST_VERSION=$LOCAL_LIST_VERSION\nGRABBER_VERSION=$REMOTE_GRABBER_VERSION" > $TVHEADEND_CONFIG_DIR/version.txt
elif [ "$LIST_ERROR" = false -a "$GRABBER_ERROR" = true ]; then
	echo -e "LIST_VERSION=$REMOTE_LIST_VERSION\nGRABBER_VERSION=$LOCAL_GRABBER_VERSION" > $TVHEADEND_CONFIG_DIR/version.txt
elif [ "$LIST_ERROR" = false -a "$GRABBER_ERROR" = false ]; then
	echo -e "LIST_VERSION=$REMOTE_LIST_VERSION\nGRABBER_VERSION=$REMOTE_GRABBER_VERSION" > $TVHEADEND_CONFIG_DIR/version.txt
fi


if [ "$LIST_ERROR" = true -o "$GRABBER_ERROR" = true ]; then
	printf "\n$red%s$end\n" "ERROR: El proceso no se ha completado correctamente."
	printf "$red%s$end\n" "Revise los errores anteriores para intentar solucionarlo."
elif [ "$SERVICE_ERROR" = true ]; then
	printf "\n$red%s$end\n" "ERROR: Tvheadend no se ha podido reiniciar de forma automática."
	printf "$red%s$end\n" "Es necesario reiniciar Tvheadend manualmente para aplicar los cambios."
	printf "$green%s$end\n" "¡Proceso completado correctamente!"
else
	printf "\n$green%s$end\n" "¡Proceso completado correctamente!"
fi


rm "Configuracion_Tvheadend_$REMOTE_LIST_VERSION.tar.xz" "tv_grab_movistar-spain"
