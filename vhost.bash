#!/bin/bash

## variaveis
NAME="${!#}.conf"
EMAIL="webmaster@localhost"
URL=""
WEBROOT=""
TEMPLATE="$HOME/.vhost/template.conf"

#colors output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Vhost Manager v0.1.0 By Rubens Fernandes${NC} "

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
    sudo -v
    sudo cp vhost.bash /usr/bin/vhost
    if [ ! -e  ~/.vhost ]; then
        sudo mkdir ~/.vhost
    fi
    sudo cp template.conf ~/.vhost
    echo -e "${GREEN}Script instalado! use: vhost ${NC}"
    exit 0;
}

# delete
vhost-remove() {
    sudo -v
    echo -e "${YELLOW}Removendo $URL de /etc/hosts.${NC}"
    sudo sed -i '/'$URL'/d' /etc/hosts

    echo -e "${YELLOW}Desativando e deletando $NAME virtual host.${NC}"
    sudo a2dissite $NAME
    sudo rm /etc/apache2/sites-available/$NAME
    sudo service apache2 reload
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
    sudo -v
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
            exit 0
        fi
    fi
}

# cria vhost na pasta /etc/apache2/sites-available
vhost-generate-vhost() {
    echo -e "${GREEN}Criando $NAME virtual host com index: $WEBROOT${NC}"

    sudo cp $TEMPLATE /etc/apache2/sites-available/$NAME
    sudo sed -i 's/template.email/'$EMAIL'/g' /etc/apache2/sites-available/$NAME
    sudo sed -i 's/template.url/'$URL'/g' /etc/apache2/sites-available/$NAME
    sudo sed -i 's#template.webroot#'$WEBROOT'#g' /etc/apache2/sites-available/$NAME
}

# add url ao hosts
vhost-add-url() {
    echo -e "${GREEN}Adicionando Url Local $URL /etc/hosts ...${NC}"

    if grep -F "$URL" /etc/hosts
    then
        echo -e "${YELLOW}Url já existe em Hosts${NC}"
    else
        sudo sed -i '1s/^/127.0.0.1       '$URL'\n/' /etc/hosts
    fi
}

vhost-enable-reload() {
    sudo a2ensite $NAME

    sudo service apache2 reload

    echo -e "${GREEN}Virtual host $NAME criado com a index $WEBROOT para url http://$URL${NC}"
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

sudo -v

vhost-createFolder;
vhost-template;
vhost-generate-vhost;
vhost-add-url;
vhost-enable-reload;

exit 0
