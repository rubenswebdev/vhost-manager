#!/bin/bash

# ---------------------------------------------------------------------------- #
# GLOBAL VARIABLES (in script)                                                 #
# ---------------------------------------------------------------------------- #

# Nome do vhost que sera criado
NAME="${!#}"

# nome padrao para os arquivos de configuraçao
CONFNAME="$NAME.conf"

# Email do webmaster do virtualhost
EMAIL="webmaster@localhost"

# Email do webmaster do virtualhost
LOGPATH="\${APACHE_LOG_DIR}"

# URL do virtual host
URL=""

# pasta dos arquivos
WEBROOT=""

# Template padrao para o vhost apache
TEMPLATE="/etc/vhost/template.conf"

# Template padrao para a pool do php5-fpm
POOL_TEMPLATE="/etc/vhost/pool-template.conf"

# Se sera gerado um vhost com php5-fpm
HAS_POOL_TEMPLATE="0"

# red output
RED='\033[0;31m'

# green output
GREEN='\033[0;32m'

# Yellow outpu
YELLOW='\033[0;33m'

# No Color
NC='\033[0m'

# ---------------------------------------------------------------------------- #
# FUNCTIONS                                                                    #
# ---------------------------------------------------------------------------- #

#
# Echoes a red message
#
echo-red() {
    echo -e "${RED}$1${NC}"
}

#
# Echoes a green message
#
echo-green() {
    echo -e "${GREEN}$1${NC}"
}

#
# Echoes a yellow message
#
echo-yellow() {
    echo -e "${YELLOW}$1${NC}"
}


#
# Shows info on the authors and the program
#
vhost-credits() {

    echo -e "${GREEN}"
    cat <<splash
Vhost Manager v1.1.0 By
    - Rubens Fernandes <rubensdrk@gmail.com>
    - Reinaldo A. C. Rauch <reinaldorauch@gmail.com>
splash
    echo -e "${NC}"

}

#
# Verifies sudo for comments after
#
vhost-verify-sudo() {

    if [ "$EUID" -ne 0 ]
      then echo-red "Execute as root eg: sudo"
      exit 1
    fi

}

#
# Shows usage information to user
#
vhost-usage() {

    echo -e "${YELLOW}"
    cat <<"USAGE"

Uso: vhost [options] <name of vhost>
    -h|--help   help
    -url        url local of the project eg: site.dev
    -rm         remove a vhost and delete from /etc/hosts
    -d          the folder for index
    -email      email to webmaster (default "webmaster@localhost")
    -l          list all vhosts
    -t          set template for vhost
    -pt         set template for pool of php5-fpm
    -install    install the script globally
    -logpath    set the path default for save the logs eg: error.log; access.log of the apache2


USAGE

    echo "Examples:"
    echo
    echo-yellow "Create a vhost call \"silex.conf\" for url \"silex.dev\" with webroot ~/projetos/silex/web with the template \"template.conf\""
    echo-green "sudo vhost -d ~/projetos/silex/web -url silex.dev -t template.conf silex"
    echo
    echo-yellow "Remove the vhost \"silex.conf\" and remove the url of \"/etc/hosts\""
    echo-green "sudo vhost -rm silex.dev silex"

    echo -e "${NC}"
    exit 0

}

#
# install script, instal option to add the script in bin directory
#
vhost-install() {
    vhost-verify-sudo;
    cp vhost.bash /usr/bin/vhost

    CONFDIR="/etc/vhost"

    if [ ! -e  "$CONFDIR" ]; then
        mkdir "$CONFDIR"
    fi

    cp template.conf template-phpfpm.conf template-pool.conf $CONFDIR

    echo-green "Script installed! use: vhost"

    exit 0;

}

#
# Removes the added files by the script
#
vhost-remove() {
    vhost-verify-sudo;
    FPM_POOL_CONF="/etc/php5/fpm/pool.d/$CONFNAME"

    echo-yellow "Removendo $URL de /etc/hosts."
    sed -i '/'$URL'/d' /etc/hosts

    echo-yellow "Desativando e deletando $CONFNAME virtual host."
    a2dissite $CONFNAME

    rm "/etc/apache2/sites-available/$CONFNAME"
    service apache2 reload

    if [ -f "$FPM_POOL_CONF" ]; then
        echo-yellow "Desativando pool do php5-fpm"
        rm "$FPM_POOL_CONF"
        service php5-fpm reload
    fi

    exit 0

}

#
# List avaliable and enabled vhosts
#
vhost-list() {

    echo-yellow "Virtual hosts avaliable:"
    ls -1 "/etc/apache2/sites-available/"

    echo-green "Virtual hosts enabled:"
    ls -1 "/etc/apache2/sites-enabled/"

    exit 0

}

#
# verificar se a pasta existe
#
vhost-createFolder() {
    vhost-verify-sudo;
    if [ ! -d "$WEBROOT" ]; then
        echo-green "Creating $WEBROOT directory"
        mkdir -p $WEBROOT
    fi

}

#
# Validate template's existance
#
vhost-template() {
    vhost-verify-sudo;
    echo-green "Verifying template..."

    if [ ! -f "$TEMPLATE" ]; then
        echo-red "template not found, verifying global template..."

        if [ ! -f "/etc/vhost/template.conf" ]; then
            echo-red "$TEMPLATE not found!"
            exit 1
        fi
    fi

    if [ $HAS_POOL_TEMPLATE = "1" ]; then
        echo-green "Verifying pool template..."

        if [ ! -f "$POOL_TEMPLATE" ]; then
            echo-red "Template not found, verifying global template... "

            if [ ! -f "/etc/vhost/template-pool.conf" ]; then
                echo-red "$POOL_TEMPLATE not found!"
                exit 1
            fi
        fi
    fi

}

#
# Generate pool config file for vhost
#
vhost-generate-pool() {
    vhost-verify-sudo;
    echo-green "Generating pool config for php-fpm"

    FPM_POOL_CONF="/etc/php5/fpm/pool.d/$CONFNAME"

    cp $POOL_TEMPLATE $FPM_POOL_CONF
    sed -i 's#template.webroot#'$WEBROOT'#g' $FPM_POOL_CONF
    sed -i 's#template.name#'$NAME'#g' $FPM_POOL_CONF

}

#
# Creates a new vhost in sites available of apache
#
vhost-generate-vhost() {
    vhost-verify-sudo;
    echo-green "Creating $NAME virtual host with webroot: $WEBROOT"

    APACHE_CONF="/etc/apache2/sites-available/$CONFNAME"

    cp $TEMPLATE $APACHE_CONF

    sed -i 's#template.email#'$EMAIL'#g' $APACHE_CONF
    sed -i 's#template.url#'$URL'#g' $APACHE_CONF
    sed -i 's#template.webroot#'$WEBROOT'#g' $APACHE_CONF
    sed -i 's#template.name#'$NAME'#g' $APACHE_CONF
    sed -i 's#template.logpath#'$LOGPATH'#g' $APACHE_CONF

    if [ $HAS_POOL_TEMPLATE = "1" ]; then
        vhost-generate-pool;
    fi

    if [ ! -f $APACHE_CONF  ]; then
        echo-red "Fail, aborting..."
        exit 1
    fi

}

#
#  Adds the new vhost domain in hosts file
#
vhost-add-url() {
    vhost-verify-sudo;
    HOSTS_PATH="/etc/hosts"

    echo-green "Set local url in $URL /etc/hosts ..."

    if grep -F "$URL" $HOSTS_PATH
    then
        echo-yellow "Url already exists"
    else
        sed -i '1s/^/127.0.0.1       '$URL'\n/' $HOSTS_PATH
    fi

}

#
# Reloads apache server andm php5-fpm, if required
#
vhost-enable-reload() {
    vhost-verify-sudo;
    a2ensite $CONFNAME

    service apache2 reload

    echo-green "Virtual host $CONFNAME created with webroot $WEBROOT for url http://$URL"

    if [ $HAS_POOL_TEMPLATE = "1" ]; then
        service php5-fpm reload
        echo-green "Pool for site with host and pool $CONFNAME enabled"
    fi


}

#
# Initial script
#
vhost-credits;

#
# Loop to read options and arguments
#
while [ $1 ]; do
    case "$1" in
        '-l') vhost-list;;
        '-h'|'--help') vhost-usage;;
        '-rm')
            URL="$2"
            vhost-remove
            ;;
        '-d') WEBROOT="$2";;
        '-t') TEMPLATE="$2";;
        '-pt')
            POOL_TEMPLATE="$2"
            HAS_POOL_TEMPLATE="1"
            ;;
        '-url') URL="$2";;
        '-email') EMAIL="$2";;
        '-logpath') LOGPATH="$2";;
        '-install') vhost-install;;
    esac
    shift
done

#
# Verify the parameters usage
#
if [ "$URL" == "" ]; then
    echo-red "You need to specify the options"
    vhost-usage;
    exit 0;
fi

#
# Do vhost creation process
#
vhost-createFolder;
vhost-template;
vhost-generate-vhost;
vhost-add-url;
vhost-enable-reload;

exit 0
