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

# URL do virtual host
URL=""

# pasta dos arquivos
WEBROOT=""

# Template padrao para o vhost apache
TEMPLATE="$HOME/.vhost/template.conf"

# Template padrao para a pool do php5-fpm
POOL_TEMPLATE="$HOME/.vhost/pool-template.conf"

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
Vhost Manager v0.2.2 By
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
      then echo-red "Execute com sudo, ou como root"
      exit 1
    fi

}

#
# Shows usage information to user
#
vhost-usage() {

    echo -e "${YELLOW}"
    cat <<"USAGE"

Uso: vhost [OPÇÕES] <nome da config>
    -h|--help   comandos
    -url        url local do site
    -rm         remove um vhost e exclui da /etc/hosts
    -d          para especificar a pasta web default do site (index)
    -email      email administrador do vhost (default "webmaster@localhost")
    -l          listas os vhost existentes
    -t          define um template para o vhost
    -pt         define um template para o pool do php5-fpm
    -install    instala o script globalmente

Exemplos:
vhost -d ~/projetos/silex/web -url silex.dev -t template.conf silex - cria um vhost chamado "silex.conf" para url "silex.dev" na pasta ~/projetos/silex/web com o template "template.conf"
vhost -rm silex.dev silex - remove o vhost "silex.conf" e remove a url do arquivo "/etc/hosts"

USAGE
    echo -e "${NC}"
    exit 0

}

#
# install script, instal option to add the script in bin directory
#
vhost-install() {

    cp vhost.bash /usr/bin/vhost

    CONFDIR="/etc/vhost"

    if [ ! -e  "$CONFDIR" ]; then
        mkdir "$CONFDIR"
    fi

    cp template.conf template-phpfpm.conf template-pool.conf $CONFDIR

    echo-green "Script instalado! use: vhost"

    exit 0;

}

#
# Removes the added files by the script
#
vhost-remove() {

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

    echo-yellow "Virtual hosts disponiveis:"
    ls -l "/etc/apache2/sites-available/"

    echo-green "Virtual hosts ativados:"
    ls -l "/etc/apache2/sites-enabled/"

    exit 0

}

#
# verificar se a pasta existe
#
vhost-createFolder() {

    if [ ! -d "$WEBROOT" ]; then
        echo-green "Creating $WEBROOT directory"
        mkdir -p $WEBROOT
    fi

}

#
# Validate template's existance
#
vhost-template() {

    echo-green "Verificando template..."

    if [ ! -f "$TEMPLATE" ]; then
        echo-red "template não encontrado verificando template global..."

        if [ ! -f "$HOME/.vhost/template.conf" ]; then
            echo-red "$TEMPLATE não encontrado!"
            exit 1
        fi
    fi

    if [ $HAS_POOL_TEMPLATE = "1" ]; then
        echo-green "Verificando pool template..."

        if [ ! -f "$POOL_TEMPLATE" ]; then
            echo-red "Template nao encontrado, verificando template global... "

            if [ ! -f "$HOME/.vhost/template-pool.conf" ]; then
                echo-red "$POOL_TEMPLATE não encontrado!"
                exit 1
            fi
        fi
    fi

}

#
# Generate pool config file for vhost
#
vhost-generate-pool() {

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

    echo-green "Criando $NAME virtual host com index: $WEBROOT"

    APACHE_CONF="/etc/apache2/sites-available/$CONFNAME"

    cp $TEMPLATE $APACHE_CONF

    sed -i 's#template.email#'$EMAIL'#g' $APACHE_CONF
    sed -i 's#template.url#'$URL'#g' $APACHE_CONF
    sed -i 's#template.webroot#'$WEBROOT'#g' $APACHE_CONF
    sed -i 's#template.name#'$NAME'#g' $APACHE_CONF

    if [ $HAS_POOL_TEMPLATE = "1" ]; then
        vhost-generate-pool;
    fi

    if [ ! -f $APACHE_CONF  ]; then
        echo-red "O arquivo de vhost nao foi criado, abortando..."
        exit 1
    fi

}

#
#  Adds the new vhost domain in hosts file
#
vhost-add-url() {

    HOSTS_PATH="/etc/hosts"

    echo-green "Adicionando Url Local $URL /etc/hosts ..."

    if grep -F "$URL" $HOSTS_PATH
    then
        echo-yellow "Url já existe em Hosts"
    else
        sed -i '1s/^/127.0.0.1       '$URL'\n/' $HOSTS_PATH
    fi

}

#
# Reloads apache server andm php5-fpm, if required
#
vhost-enable-reload() {

    a2ensite $CONFNAME

    service apache2 reload

    echo-green "Virtual host $CONFNAME criado com a index $WEBROOT para url http://$URL"

    if [ $HAS_POOL_TEMPLATE = "1" ]; then
        service php5-fpm reload
    fi

    echo-green "Pool for site with host and pool $CONFNAME enabled"

}

#
# Initial script
#
vhost-credits;
vhost-verify-sudo;

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
        '-install') vhost-install;;
    esac
    shift
done

#
# Verify the parameters usage
#
if [ "$URL" == "" ]; then
    echo-red "Parametros incorretos"
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
