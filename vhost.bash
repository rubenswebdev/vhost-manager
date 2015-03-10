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
# ---------------------------------------------------------------------------  #

vhost-credits() {
    echo -e "${GREEN}"
    cat <<splash
Vhost Manager v0.2.0 By
    - Rubens Fernandes <rubensdrk@gmail.com>
    - Reinaldo A. C. Rauch <reinaldorauch@gmail.com>
splash
    echo -e "${NC}"

}

vhost-verify-sudo() {
    if [ "$EUID" -ne 0 ]
      then echo -e "${RED}Execute com sudo, ou como root${NC}"
      exit
    fi
}


# Help
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

# install script
vhost-install() {
    cp vhost.bash /usr/bin/vhost

    CONFDIR="/etc/vhost"

    if [ ! -e  "$CONFDIR" ]; then
        mkdir "$CONFDIR"
    fi
    cp template.conf template-phpfpm.conf template-pool.conf $CONFDIR
    echo -e "${GREEN}Script instalado! use: vhost ${NC}"
    exit 0;
}

# delete
vhost-remove() {
    FPM_POOL_CONF="/etc/php5/fpm/pool.d/$CONFNAME"

    echo -e "${YELLOW}Removendo $URL de /etc/hosts.${NC}"
    sed -i '/'$URL'/d' /etc/hosts

    echo -e "${YELLOW}Desativando e deletando $CONFNAME virtual host.${NC}"
    a2dissite $CONFNAME
    rm /etc/apache2/sites-available/$CONFNAME
    service apache2 reload

    if [ -f "$FPM_POOL_CONF" ]; then
        echo -e "${YELLOW}Desativando pool do php5-fpm${NC}"
        rm "$FPM_POOL_CONF"
        service php5-fpm reload
    fi

    exit 0
}

# list
vhost-list() {
    echo -e "${YELLOW}Virtual hosts disponiveis:${NC}"
    ls -l /etc/apache2/sites-available/
    echo -e "${GREEN}Virtual hosts ativados:${NC}"
    ls -l /etc/apache2/sites-enabled/
    exit 0
}

# verificar se a pasta existe
vhost-createFolder() {
    # verificar se a pasta existe
    if [ ! -d "$WEBROOT" ]; then
        echo -e "${GREEN}Creating $WEBROOT directory${NC}"
        mkdir -p $WEBROOT
    fi
}

# verificar template
vhost-template() {
    echo -e "${GREEN}Verificando template...${NC}"

    if [ ! -f "$TEMPLATE" ]; then
        echo -e "${RED}template não encontrado verificando template global...${NC}"

        if [ ! -f "$HOME/.vhost/template.conf" ]; then
            echo -e "${RED}$TEMPLATE não encontrado!${NC}"
            exit 1
        fi
    fi

    if [ HAS_POOL_TEMPLATE = "1" ]; then
        echo -e "${GREEN}Verificando pool template...${NC}"

        if [ ! -f "$POOL_TEMPLATE" ]; then
            echo -e "${RED}Template nao encontrado, verificando template global... ${NC}"

            if [ ! -f "$HOME/.vhost/template-pool.conf" ]; then
                echo -e "${RED}$POOL_TEMPLATE não encontrado!${NC}"
                exit 1
            fi
        fi
    fi
}

vhost-generate-pool() {
    echo -e "${GREEN}Generating pool config for php-fpm${NC}"

    FPM_POOL_CONF="/etc/php5/fpm/pool.d/$CONFNAME"

    cp $POOL_TEMPLATE $FPM_POOL_CONF
    sed -i 's#template.webroot#'$WEBROOT'#g' $FPM_POOL_CONF
    sed -i 's#template.name#'$NAME'#g' $FPM_POOL_CONF
}

# cria vhost na pasta /etc/apache2/sites-available
vhost-generate-vhost() {
    echo -e "${GREEN}Criando $NAME virtual host com index: $WEBROOT${NC}"

    APACHE_CONF="/etc/apache2/sites-available/$CONFNAME"

    cp $TEMPLATE $APACHE_CONF
    sed -i 's#template.email#'$EMAIL'#g' $APACHE_CONF
    sed -i 's#template.url#'$URL'#g' $APACHE_CONF
    sed -i 's#template.webroot#'$WEBROOT'#g' $APACHE_CONF
    sed -i 's#template.name#'$NAME'#g' $APACHE_CONF

    if [ HAS_POOL_TEMPLATE = "1" ]; then
        vhost-generate-pool;
    fi
}

# add url ao hosts
vhost-add-url() {
    echo -e "${GREEN}Adicionando Url Local $URL /etc/hosts ...${NC}"

    if grep -F "$URL" /etc/hosts
    then
        echo -e "${YELLOW}Url já existe em Hosts${NC}"
    else
        sed -i '1s/^/127.0.0.1       '$URL'\n/' /etc/hosts
    fi
}

vhost-enable-reload() {
    a2ensite $CONFNAME

    service apache2 reload

    echo -e "${GREEN}Virtual host $CONFNAME criado com a index $WEBROOT para url http://$URL${NC}"

    if [ HAS_POOL_TEMPLATE="1" ]; then
        service php5-fpm reload
    fi

    echo -e "${GREEN}Pool for site with host and pool $CONFNAME enabled${NC}"
}


# Loop to read options and arguments
while [ $1 ]; do
    case "$1" in
        '-l') vhost-list;;
        '-h'|'--help') vhost-usage;;
        '-rm') URL="$2"
               vhost-remove;;
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

if [ "$URL" == "" ] ;then
    echo -e "${RED} Parametros incorretos ${NC}"
    vhost-usage;
    exit 0;
fi

vhost-credits;
vhost-verify-sudo;
vhost-createFolder;
vhost-template;
vhost-generate-vhost;
vhost-add-url;
vhost-enable-reload;

exit 0
