#!/bin/bash

read -p "Deseja Instalar o Banco de Dados? [Sim | Não] " INSTALL_DB

#Parameters to APT
sudo sh -c 'echo "Acquire::http::No-Cache true;" >> /etc/apt/apt.conf'
sudo sh -c 'echo "Acquire::http::Pipeline-Depth 0;" >> /etc/apt/apt.conf'

# Update Server
sudo apt update
sudo apt full-upgrade -y
sudo locale-gen pt_BR.UTF-8

# Install Dependencies SO
cat dependencias/ubuntu/apt3 | xargs sudo apt install -y

sudo -H pip3 install --upgrade pip
sudo -H pip3 install --upgrade setuptools
cat dependencias/ubuntu/pip3 | xargs sudo -H pip3 install

# Install PostgreSQL Server

if [ $INSTALL_DB == "Sim" ]; then
  codename=`lsb_release --codename | cut -f2`
  sudo sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ $codename-pgdg main' >> /etc/apt/sources.list"
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
  sudo apt-get update
  sudo apt-get install postgresql-9.6
  sudo su - postgres -c "createuser -s odoo" 2> /dev/null || true
  sudo -u postgres -- psql -c "ALTER USER postgres WITH PASSWORD '123';"
  sudo -u postgres -- psql -c "DROP ROLE odoo;"
  sudo -u postgres -- psql -c "CREATE ROLE odoo LOGIN ENCRYPTED PASSWORD 'md50a8f125a3f41f36c0507203a63cde9ad' NOSUPERUSER INHERIT CREATEDB CREATEROLE REPLICATION"
  sudo sed -i s/"listen_addresses = 'localhost'"/"listen_addresses = ''"/g /etc/postgresql/9.6/main/postgresql.conf
  sudo sed -i s/"local   all             all                                     ident"/"local   all             all                                     trust"/g /etc/postgresql/9.6/main/pg_hba.conf
  sudo sed -i s/"32            ident"/"32            md5"/g /etc/postgresql/9.6/main/pg_hba.conf
fi

# Criando usuario odoo no SO
sudo adduser --system --quiet --shell=/bin/bash --home=/odoo --gecos 'ODOO' --group odoo
#The user should also be added to the sudo'ers group.
sudo adduser odoo sudo

# Criando diretorio para arquivos de log
sudo mkdir /var/log/odoo
sudo chown odoo:odoo /var/log/odoo

# Install ODOO
sudo git clone -b 11.0 https://github.com/odoo/odoo /odoo/odoo-server --depth 1

#Alterando a permissão da pasta do Odoo
sudo chown -R odoo:odoo /odoo/

# Config File Odoo
#Adiciona o odoo-server.conf
cat <<EOF > /etc/odoo-server.conf
[options]
; This is the password that allows database operations:
; admin_passwd = admin
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = /odoo/odoo-server/addons
log_db = False
log_db_level = warning
log_handler = :INFO
log_level = info
logfile = /var/log/odoo/odoo-server.log
xmlrpc_port = 8069
EOF

# Adding ODOO as a deamon (initscript)
sudo cp dependencias/ubuntu/odoo-server /etc/init.d/
sudo chmod 755 /etc/init.d/odoo-server
sudo chown root: /etc/init.d/odoo-server
sudo update-rc.d odoo-server defaults
