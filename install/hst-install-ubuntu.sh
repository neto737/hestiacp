#!/bin/bash

# Hestia Ubuntu installer v1.0

#----------------------------------------------------------#
#                  Variables&Functions                     #
#----------------------------------------------------------#
export PATH=$PATH:/sbin
export DEBIAN_FRONTEND=noninteractive
RHOST='apt.hestiacp.com'
GPG='gpg.hestiacp.com'
VERSION='ubuntu'
HESTIA='/usr/local/hestia'
LOG="/root/hst_install_backups/hst_install-$(date +%d%m%Y%H%M).log"
memory=$(grep 'MemTotal' /proc/meminfo |tr ' ' '\n' |grep [0-9])
hst_backups="/root/hst_install_backups/$(date +%d%m%Y%H%M)"
arch=$(uname -i)
spinner="/-\|"
os='ubuntu'
release="$(lsb_release -s -r)"
codename="$(lsb_release -s -c)"
HESTIA_INSTALL_DIR="$HESTIA/install/deb"

# Define software versions
pma_v='4.9.3'
multiphp_v=("5.6" "7.0" "7.1" "7.2" "7.3" "7.4")
fpm_v="7.3"

# Defining software pack for all distros
software="apache2 apache2.2-common apache2-suexec-custom apache2-utils
    apparmor-utils awstats bc bind9 bsdmainutils bsdutils clamav-daemon
    cron curl dnsutils dovecot-imapd dovecot-pop3d e2fslibs e2fsprogs exim4
    exim4-daemon-heavy expect fail2ban flex ftp git idn imagemagick
    libapache2-mod-fcgid libapache2-mod-php$fpm_v libapache2-mod-rpaf
    libapache2-mod-ruid2 lsof mc mariadb-client mariadb-common mariadb-server
    nginx ntpdate php$fpm_v php$fpm_v-cgi php$fpm_v-common php$fpm_v-curl
    phpmyadmin php$fpm_v-mysql php$fpm_v-imap php$fpm_v-ldap php$fpm_v-apcu
    phppgadmin php$fpm_v-pgsql php$fpm_v-zip php$fpm_v-bz2 php$fpm_v-cli
    php$fpm_v-gd php$fpm_v-imagick php$fpm_v-intl php$fpm_v-json
    php$fpm_v-mbstring php$fpm_v-opcache php$fpm_v-pspell php$fpm_v-readline
    php$fpm_v-xml postgresql postgresql-contrib proftpd-basic quota
    roundcube-core roundcube-mysql roundcube-plugins rrdtool rssh spamassassin
    sudo hestia hestia-nginx hestia-php vim-common vsftpd whois zip acl sysstat setpriv"

# Defining help function
help() {
    echo "Usage: $0 [OPTIONS]
  -a, --apache            Install Apache        [yes|no]  default: yes
  -n, --nginx             Install Nginx         [yes|no]  default: yes
  -w, --phpfpm            Install PHP-FPM       [yes|no]  default: no
  -o, --multiphp          Install Multi-PHP     [yes|no]  default: no
  -v, --vsftpd            Install Vsftpd        [yes|no]  default: yes
  -j, --proftpd           Install ProFTPD       [yes|no]  default: no
  -k, --named             Install Bind          [yes|no]  default: yes
  -m, --mysql             Install MariaDB       [yes|no]  default: yes
  -g, --postgresql        Install PostgreSQL    [yes|no]  default: no
  -x, --exim              Install Exim          [yes|no]  default: yes
  -z, --dovecot           Install Dovecot       [yes|no]  default: yes
  -c, --clamav            Install ClamAV        [yes|no]  default: yes
  -t, --spamassassin      Install SpamAssassin  [yes|no]  default: yes
  -i, --iptables          Install Iptables      [yes|no]  default: yes
  -b, --fail2ban          Install Fail2ban      [yes|no]  default: yes
  -q, --quota             Filesystem Quota      [yes|no]  default: no
  -d, --api               Activate API          [yes|no]  default: yes
  -r, --port              Change Backend Port             default: 8083
  -l, --lang              Default language                default: en
  -y, --interactive       Interactive install   [yes|no]  default: yes
  -s, --hostname          Set hostname
  -e, --email             Set admin email
  -p, --password          Set admin password
  -D, --with-debs         Path to Hestia debs
  -f, --force             Force installation
  -h, --help              Print this help

  Example: bash $0 -e demo@hestiacp.com -p p4ssw0rd --apache no --phpfpm yes"
    exit 1
}

# Defining file download function
download_file() {
    wget $1 -q --show-progress --progress=bar:force
}

# Defining password-gen function
gen_pass() {
    MATRIX='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    LENGTH=16
    while [ ${n:=1} -le $LENGTH ]; do
        PASS="$PASS${MATRIX:$(($RANDOM%${#MATRIX})):1}"
        let n+=1
    done
    echo "$PASS"
}

# Defining return code check function
check_result() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2"
        exit $1
    fi
}

# Defining function to set default value
set_default_value() {
    eval variable=\$$1
    if [ -z "$variable" ]; then
        eval $1=$2
    fi
    if [ "$variable" != 'yes' ] && [ "$variable" != 'no' ]; then
        eval $1=$2
    fi
}

# Defining function to set default language value
set_default_lang() {
    if [ -z "$lang" ]; then
        eval lang=$1
    fi
    lang_list="
        ar cz el fa hu ja no pt se ua
        bs da en fi id ka pl ro tr vi
        cn de es fr it nl pt-BR ru tw
        bg ko sr th ur"
    if !(echo $lang_list |grep -w $lang > /dev/null 2>&1); then
        eval lang=$1
    fi
}

# Define the default backend port
set_default_port() {
    if [ -z "$port" ]; then
        eval port=$1
    fi
}


#----------------------------------------------------------#
#                    Verifications                         #
#----------------------------------------------------------#

# Creating temporary file
tmpfile=$(mktemp -p /tmp)

# Translating argument to --gnu-long-options
for arg; do
    delim=""
    case "$arg" in
        --apache)               args="${args}-a " ;;
        --nginx)                args="${args}-n " ;;
        --phpfpm)               args="${args}-w " ;;
        --vsftpd)               args="${args}-v " ;;
        --proftpd)              args="${args}-j " ;;
        --named)                args="${args}-k " ;;
        --mysql)                args="${args}-m " ;;
        --postgresql)           args="${args}-g " ;;
        --exim)                 args="${args}-x " ;;
        --dovecot)              args="${args}-z " ;;
        --clamav)               args="${args}-c " ;;
        --spamassassin)         args="${args}-t " ;;
        --iptables)             args="${args}-i " ;;
        --fail2ban)             args="${args}-b " ;;
        --multiphp)             args="${args}-o " ;;
        --quota)                args="${args}-q " ;;
        --port)                 args="${args}-r " ;;
        --lang)                 args="${args}-l " ;;
        --interactive)          args="${args}-y " ;;
        --api)                  args="${args}-d " ;;
        --hostname)             args="${args}-s " ;;
        --email)                args="${args}-e " ;;
        --password)             args="${args}-p " ;;
        --force)                args="${args}-f " ;;
        --with-debs)            args="${args}-D " ;;
        --help)                 args="${args}-h " ;;
        *)                      [[ "${arg:0:1}" == "-" ]] || delim="\""
                                args="${args}${delim}${arg}${delim} ";;
    esac
done
eval set -- "$args"

# Parsing arguments
while getopts "a:n:w:v:j:k:m:g:d:x:z:c:t:i:b:r:o:q:l:y:s:e:p:D:fh" Option; do
    case $Option in
        a) apache=$OPTARG ;;            # Apache
        n) nginx=$OPTARG ;;             # Nginx
        w) phpfpm=$OPTARG ;;            # PHP-FPM
        o) multiphp=$OPTARG ;;          # Multi-PHP
        v) vsftpd=$OPTARG ;;            # Vsftpd
        j) proftpd=$OPTARG ;;           # Proftpd
        k) named=$OPTARG ;;             # Named
        m) mysql=$OPTARG ;;             # MariaDB
        g) postgresql=$OPTARG ;;        # PostgreSQL
        x) exim=$OPTARG ;;              # Exim
        z) dovecot=$OPTARG ;;           # Dovecot
        c) clamd=$OPTARG ;;             # ClamAV
        t) spamd=$OPTARG ;;             # SpamAssassin
        i) iptables=$OPTARG ;;          # Iptables
        b) fail2ban=$OPTARG ;;          # Fail2ban
        q) quota=$OPTARG ;;             # FS Quota
        r) port=$OPTARG ;;              # Backend Port
        l) lang=$OPTARG ;;              # Language
        d) api=$OPTARG ;;               # Activate API
        y) interactive=$OPTARG ;;       # Interactive install
        s) servername=$OPTARG ;;        # Hostname
        e) email=$OPTARG ;;             # Admin email
        p) vpass=$OPTARG ;;             # Admin password
        D) withdebs=$OPTARG ;;          # Hestia debs path
        f) force='yes' ;;               # Force install
        h) help ;;                      # Help
        *) help ;;                      # Print help (default)
    esac
done

# Defining default software stack
set_default_value 'nginx' 'yes'
set_default_value 'apache' 'yes'
set_default_value 'phpfpm' 'no'
set_default_value 'multiphp' 'no'
set_default_value 'vsftpd' 'yes'
set_default_value 'proftpd' 'no'
set_default_value 'named' 'yes'
set_default_value 'mysql' 'yes'
set_default_value 'postgresql' 'no'
set_default_value 'exim' 'yes'
set_default_value 'dovecot' 'yes'
if [ $memory -lt 1500000 ]; then
    set_default_value 'clamd' 'no'
    set_default_value 'spamd' 'no'
else
    set_default_value 'clamd' 'yes'
    set_default_value 'spamd' 'yes'
fi
set_default_value 'iptables' 'yes'
set_default_value 'fail2ban' 'yes'
set_default_value 'quota' 'no'
set_default_value 'interactive' 'yes'
set_default_value 'api' 'yes'
set_default_port '8083'
set_default_lang 'en'

# Checking software conflicts

if [ "$multiphp" = 'yes' ]; then
    phpfpm='yes'
fi
if [ "$proftpd" = 'yes' ]; then
    vsftpd='no'
fi
if [ "$exim" = 'no' ]; then
    clamd='no'
    spamd='no'
    dovecot='no'
fi
if [ "$iptables" = 'no' ]; then
    fail2ban='no'
fi

# Checking root permissions
if [ "x$(id -u)" != 'x0' ]; then
    check_result 1 "Script can be run executed only by root"
fi

# Checking admin user account
if [ ! -z "$(grep ^admin: /etc/passwd /etc/group)" ] && [ -z "$force" ]; then
    echo 'Please remove admin user account before proceeding.'
    echo 'If you want to do it automatically run installer with -f option:'
    echo -e "Example: bash $0 --force\n"
    check_result 1 "User admin exists"
fi

# Check if a default webserver was set
if [ $apache = 'no' ] && [ $nginx = 'no' ]; then
    check_result 1 "No web server was selected"
fi

# Clear the screen once launch permissions have been verified
clear

# Configure apt to retry downloading on error
if [ ! -f /etc/apt/apt.conf.d/80-retries ]; then
    echo "APT::Acquire::Retries \"3\";" > /etc/apt/apt.conf.d/80-retries
fi

# Welcome message
echo "Welcome to the Hestia Control Panel installer!"
echo 
echo "Please wait a moment while we update your system's repositories and"
echo "install any necessary dependencies required to proceed with the installation..."
echo 

# Update apt repository
apt-get -qq update

# Creating backup directory
mkdir -p $hst_backups

# Checking ntpdate
if [ ! -e '/usr/sbin/ntpdate' ]; then
    echo "(*) Installing ntpdate..."
    apt-get -y install ntpdate >> $LOG
    check_result $? "Can't install ntpdate"
fi

# Checking wget
if [ ! -e '/usr/bin/wget' ]; then
    echo "(*) Installing wget..."
    apt-get -y install wget >> $LOG
    check_result $? "Can't install wget"
fi

# Check if apt-transport-https is installed
if [ ! -e '/usr/lib/apt/methods/https' ]; then
    echo "(*) Installing apt-transport-https..."
    apt-get -y install apt-transport-https >> $LOG
    check_result $? "Can't install apt-transport-https"
fi

# Check if apt-add-repository is installed
if [ ! -e '/usr/bin/apt-add-repository' ]; then
    echo "(*) Installing apt-add-repository..."
    apt-get -y install software-properties-common >> $LOG
    check_result $? "Can't install software-properties-common"
fi

# Check if gnupg or gnupg2 is installed
if [ ! -e '/usr/lib/gnupg2' ] || [ ! -e '/usr/lib/gnupg' ]; then
    echo "(*) Installing gnupg2..."
    apt-get -y install gnupg2 >> $LOG
    check_result $? "Can't install gnupg2"
fi

# Check repository availability
wget --quiet "https://$GPG/deb_signing.key" -O /dev/null
check_result $? "Unable to connect to the Hestia APT repository"

# Check installed packages
tmpfile=$(mktemp -p /tmp)
dpkg --get-selections > $tmpfile
for pkg in exim4 mariadb-server apache2 nginx hestia postfix ufw; do
    if [ ! -z "$(grep $pkg $tmpfile)" ]; then
        conflicts="$pkg* $conflicts"
    fi
done
rm -f $tmpfile
if [ ! -z "$conflicts" ] && [ -z "$force" ]; then
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    echo 'WARNING: The following packages are already installed'
    echo "$conflicts"
    echo
    echo 'It is highly recommended that you remove them before proceeding.'
    echo
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    read -p 'Would you like to remove the conflicting packages? [y/n] ' answer
    if [ "$answer" = 'y' ] || [ "$answer" = 'Y'  ]; then
        apt-get -qq purge $conflicts -y
        check_result $? 'apt-get remove failed'
        unset $answer
    else
        check_result 1 "Hestia Control Panel should be installed on a clean server."
    fi
fi

# Check network configuration
if [ -d /etc/netplan ] && [ -z "$force" ]; then
    if [ -z "$(ls -A /etc/netplan)" ]; then
        echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
        echo
        echo 'WARNING: Your network configuration may not be set up correctly.'
        echo 'Details: The netplan configuration directory is empty.'
        echo ''
        echo 'You may have a network configuration file that was created using'
        echo 'systemd-networkd.'
        echo ''
        echo 'It is strongly recommended to migrate to netplan, which is now the'
        echo 'default network configuration system in newer releases of Ubuntu.'
        echo ''
        echo 'While you can leave your configuration as-is, please note that you'
        echo 'will not be able to use additional IPs properly.'
        echo ''
        echo 'If you wish to continue and force the installation,'
        echo 'run this script with -f option:'
        echo "Example: bash $0 --force"
        echo
        echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
        echo
        check_result 1 "Unable to detect netplan configuration."
    fi
fi


#----------------------------------------------------------#
#                       Brief Info                         #
#----------------------------------------------------------#

# Printing nice ASCII logo
clear
echo
echo '  _   _           _   _        ____ ____  '
echo ' | | | | ___  ___| |_(_) __ _ / ___|  _ \ '
echo ' | |_| |/ _ \/ __| __| |/ _` | |   | |_) |'
echo ' |  _  |  __/\__ \ |_| | (_| | |___|  __/ '
echo ' |_| |_|\___||___/\__|_|\__,_|\____|_|    '
echo
echo '                      Hestia Control Panel'
echo '                                    v1.1.0'
echo -e "\n"
echo "===================================================================="
echo -e "\n"
echo 'The following server components will be installed on your system:'
echo

# Web stack
if [ "$nginx" = 'yes' ]; then
    echo '   - NGINX Web / Proxy Server'
fi
if [ "$apache" = 'yes' ] && [ "$nginx" = 'no' ] ; then
    echo '   - Apache Web Server'
fi
if [ "$apache" = 'yes' ] && [ "$nginx"  = 'yes' ] ; then
    echo '   - Apache Web Server (as backend)'
fi
if [ "$phpfpm"  = 'yes' ]; then
    echo '   - PHP-FPM Application Server'
fi
if [ "$multiphp"  = 'yes' ]; then
    echo '   - Multi-PHP Environment'
fi

# DNS stack
if [ "$named" = 'yes' ]; then
    echo '   - Bind DNS Server'
fi

# Mail stack
if [ "$exim" = 'yes' ]; then
    echo -n '   - Exim Mail Server'
    if [ "$clamd" = 'yes'  ] ||  [ "$spamd" = 'yes' ] ; then
        echo -n ' + '
        if [ "$clamd" = 'yes' ]; then
            echo -n 'ClamAV '
        fi
        if [ "$spamd" = 'yes' ]; then
            if [ "$clamd" = 'yes' ]; then
                echo -n '+ '
            fi
            echo -n 'SpamAssassin'
        fi
    fi
    echo
    if [ "$dovecot" = 'yes' ]; then
        echo '   - Dovecot POP3/IMAP Server'
    fi
fi

# Database stack
if [ "$mysql" = 'yes' ]; then
    echo '   - MariaDB Database Server'
fi
if [ "$postgresql" = 'yes' ]; then
    echo '   - PostgreSQL Database Server'
fi

# FTP stack
if [ "$vsftpd" = 'yes' ]; then
    echo '   - Vsftpd FTP Server'
fi
if [ "$proftpd" = 'yes' ]; then
    echo '   - ProFTPD FTP Server'
fi

# Firewall stack
if [ "$iptables" = 'yes' ]; then
    echo -n '   - Firewall (Iptables)'
fi
if [ "$iptables" = 'yes' ] && [ "$fail2ban" = 'yes' ]; then
    echo -n ' + Fail2Ban Access Monitor'
fi
echo -e "\n"
echo "===================================================================="
echo -e "\n"

# Asking for confirmation to proceed
if [ "$interactive" = 'yes' ]; then
    read -p 'Would you like to continue with the installation? [Y/N]: ' answer
    if [ "$answer" != 'y' ] && [ "$answer" != 'Y'  ]; then
        echo 'Goodbye'
        exit 1
    fi

    # Asking for contact email
    if [ -z "$email" ]; then
        read -p 'Please enter admin email address: ' email
    fi

    # Asking to set FQDN hostname
    if [ -z "$servername" ]; then
        read -p "Please enter FQDN hostname [$(hostname -f)]: " servername
    fi
fi

# Generating admin password if it wasn't set
if [ -z "$vpass" ]; then
    vpass=$(gen_pass)
fi

# Set hostname if it wasn't set
if [ -z "$servername" ]; then
    servername=$(hostname -f)
fi

# Set FQDN if it wasn't set
mask1='(([[:alnum:]](-?[[:alnum:]])*)\.)'
mask2='*[[:alnum:]](-?[[:alnum:]])+\.[[:alnum:]]{2,}'
if ! [[ "$servername" =~ ^${mask1}${mask2}$ ]]; then
    if [ ! -z "$servername" ]; then
        servername="$servername.example.com"
    else
        servername="example.com"
    fi
    echo "127.0.0.1 $servername" >> /etc/hosts
fi

# Set email if it wasn't set
if [ -z "$email" ]; then
    email="admin@$servername"
fi

# Defining backup directory
echo -e "Installation backup directory: $hst_backups"

# Print Log File Path
echo "Installation log file: $LOG"

# Print new line
echo


#----------------------------------------------------------#
#                      Checking swap                       #
#----------------------------------------------------------#

# Checking swap on small instances
if [ -z "$(swapon -s)" ] && [ $memory -lt 1000000 ]; then
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
fi


#----------------------------------------------------------#
#                   Install repository                     #
#----------------------------------------------------------#

# Define apt conf location
apt=/etc/apt/sources.list.d

# Updating system
echo "Adding required repositories to proceed with installation:"
echo

# Installing nginx repo
echo "(*) NGINX"
if [ -e $apt/nginx.list ]; then
    rm $apt/nginx.list
fi
echo "deb [arch=amd64] http://nginx.org/packages/mainline/$VERSION/ $codename nginx" \
    > $apt/nginx.list
wget --quiet http://nginx.org/keys/nginx_signing.key -O /tmp/nginx_signing.key
APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add /tmp/nginx_signing.key > /dev/null 2>&1

# Installing sury php repo
echo "(*) PHP"
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1

# Installing MariaDB repo
echo "(*) MariaDB"
echo "deb [arch=amd64] http://ams2.mirrors.digitalocean.com/mariadb/repo/10.4/$VERSION $codename main" > $apt/mariadb.list
APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8 > /dev/null 2>&1

# Installing hestia repo
echo "(*) Hestia Control Panel"
echo "deb https://$RHOST/ $codename main" > $apt/hestia.list
wget --quiet https://gpg.hestiacp.com/deb_signing.key -O /tmp/deb_signing.key
APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add /tmp/deb_signing.key > /dev/null 2>&1
rm /tmp/deb_signing.key

# Installing postgresql repo
if [ "$postgresql" = 'yes' ]; then
    echo "(*) PostgreSQL"
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $codename-pgdg main" > $apt/postgresql.list
    wget --quiet https://www.postgresql.org/media/keys/ACCC4CF8.asc -O /tmp/psql_signing.key
    APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add /tmp/psql_signing.key > /dev/null 2>&1
    rm /tmp/psql_signing.key
fi

# Echo for a new line
echo

# Updating system
echo -ne "Updating currently installed packages, please wait... "
apt-get -qq update
apt-get -y upgrade >> $LOG &
BACK_PID=$!

# Check if package installation is done, print a spinner
spin_i=1
while kill -0 $BACK_PID > /dev/null 2>&1 ; do
    printf "\b${spinner:spin_i++%${#spinner}:1}"
    sleep 0.5
done

# Do a blank echo to get the \n back
echo

# Check Installation result
check_result $? 'apt-get upgrade failed'


#----------------------------------------------------------#
#                         Backup                           #
#----------------------------------------------------------#

# Creating backup directory tree
mkdir -p $hst_backups
cd $hst_backups
mkdir nginx apache2 php vsftpd proftpd bind exim4 dovecot clamd
mkdir spamassassin mysql postgresql hestia

# Backup nginx configuration
systemctl stop nginx > /dev/null 2>&1
cp -r /etc/nginx/* $hst_backups/nginx > /dev/null 2>&1

# Backup Apache configuration
systemctl stop apache2 > /dev/null 2>&1
cp -r /etc/apache2/* $hst_backups/apache2 > /dev/null 2>&1
rm -f /etc/apache2/conf.d/* > /dev/null 2>&1

# Backup PHP-FPM configuration
systemctl stop php*-fpm > /dev/null 2>&1
cp -r /etc/php/* $hst_backups/php/ > /dev/null 2>&1

# Backup Bind configuration
systemctl stop bind9 > /dev/null 2>&1
cp -r /etc/bind/* $hst_backups/bind > /dev/null 2>&1

# Backup Vsftpd configuration
systemctl stop vsftpd > /dev/null 2>&1
cp /etc/vsftpd.conf $hst_backups/vsftpd > /dev/null 2>&1

# Backup ProFTPD configuration
systemctl stop proftpd > /dev/null 2>&1
cp /etc/proftpd.conf $hst_backups/proftpd > /dev/null 2>&1

# Backup Exim configuration
systemctl stop exim4 > /dev/null 2>&1
cp -r /etc/exim4/* $hst_backups/exim4 > /dev/null 2>&1

# Backup ClamAV configuration
systemctl stop clamav-daemon > /dev/null 2>&1
cp -r /etc/clamav/* $hst_backups/clamav > /dev/null 2>&1

# Backup SpamAssassin configuration
systemctl stop spamassassin > /dev/null 2>&1
cp -r /etc/spamassassin/* $hst_backups/spamassassin > /dev/null 2>&1

# Backup Dovecot configuration
systemctl stop dovecot > /dev/null 2>&1
cp /etc/dovecot.conf $hst_backups/dovecot > /dev/null 2>&1
cp -r /etc/dovecot/* $hst_backups/dovecot > /dev/null 2>&1

# Backup MySQL/MariaDB configuration and data
systemctl stop mysql > /dev/null 2>&1
killall -9 mysqld > /dev/null 2>&1
mv /var/lib/mysql $hst_backups/mysql/mysql_datadir > /dev/null 2>&1
cp -r /etc/mysql/* $hst_backups/mysql > /dev/null 2>&1
mv -f /root/.my.cnf $hst_backups/mysql > /dev/null 2>&1

# Backup Hestia
systemctl stop hestia > /dev/null 2>&1
cp -r $HESTIA/* $hst_backups/hestia > /dev/null 2>&1
apt-get -y purge hestia hestia-nginx hestia-php > /dev/null 2>&1
rm -rf $HESTIA > /dev/null 2>&1


#----------------------------------------------------------#
#                     Package Includes                     #
#----------------------------------------------------------#

if [ "$phpfpm" = 'yes' ]; then
    fpm="php$fpm_v php$fpm_v-common php$fpm_v-bcmath php$fpm_v-cli
         php$fpm_v-curl php$fpm_v-fpm php$fpm_v-gd php$fpm_v-intl
         php$fpm_v-mysql php$fpm_v-soap php$fpm_v-xml php$fpm_v-zip
         php$fpm_v-mbstring php$fpm_v-json php$fpm_v-bz2 php$fpm_v-pspell
         php$fpm_v-imagick"
    software="$software $fpm"
fi


#----------------------------------------------------------#
#                     Package Excludes                     #
#----------------------------------------------------------#

# Excluding packages
software=$(echo "$software" | sed -e "s/apache2.2-common//")
if [ "$nginx" = 'no'  ]; then
    software=$(echo "$software" | sed -e "s/\bnginx\b/ /")
fi
if [ "$apache" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/apache2 //")
    software=$(echo "$software" | sed -e "s/apache2-bin//")
    software=$(echo "$software" | sed -e "s/apache2-utils//")
    software=$(echo "$software" | sed -e "s/apache2-suexec-custom//")
    software=$(echo "$software" | sed -e "s/apache2.2-common//")
    software=$(echo "$software" | sed -e "s/libapache2-mod-ruid2//")
    software=$(echo "$software" | sed -e "s/libapache2-mod-rpaf//")
    software=$(echo "$software" | sed -e "s/libapache2-mod-fcgid//")
    software=$(echo "$software" | sed -e "s/libapache2-mod-php$fpm_v//")
fi
if [ "$vsftpd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/vsftpd//")
fi
if [ "$proftpd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/proftpd-basic//")
    software=$(echo "$software" | sed -e "s/proftpd-mod-vroot//")
fi
if [ "$named" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/bind9//")
fi
if [ "$exim" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/exim4 //")
    software=$(echo "$software" | sed -e "s/exim4-daemon-heavy//")
    software=$(echo "$software" | sed -e "s/dovecot-imapd//")
    software=$(echo "$software" | sed -e "s/dovecot-pop3d//")
    software=$(echo "$software" | sed -e "s/clamav-daemon//")
    software=$(echo "$software" | sed -e "s/spamassassin//")
    software=$(echo "$software" | sed -e "s/roundcube-core//")
    software=$(echo "$software" | sed -e "s/roundcube-mysql//")
    software=$(echo "$software" | sed -e "s/roundcube-plugins//")
fi
if [ "$clamd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/clamav-daemon//")
fi
if [ "$spamd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/spamassassin//")
fi
if [ "$dovecot" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/dovecot-imapd//")
    software=$(echo "$software" | sed -e "s/dovecot-pop3d//")
    software=$(echo "$software" | sed -e "s/roundcube-core//")
    software=$(echo "$software" | sed -e "s/roundcube-mysql//")
    software=$(echo "$software" | sed -e "s/roundcube-plugins//")
fi
if [ "$mysql" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/mariadb-server//")
    software=$(echo "$software" | sed -e "s/mariadb-client//")
    software=$(echo "$software" | sed -e "s/mariadb-common//")
    software=$(echo "$software" | sed -e "s/php$fpm_v-mysql//")
    if [ "$multiphp" = 'yes' ]; then
        for v in "${multiphp_v[@]}"; do
            software=$(echo "$software" | sed -e "s/php$v-mysql//")
            software=$(echo "$software" | sed -e "s/php$v-bz2//")
        done
    fi
    software=$(echo "$software" | sed -e "s/phpmyadmin//")
fi
if [ "$postgresql" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/postgresql-contrib//")
    software=$(echo "$software" | sed -e "s/postgresql//")
    software=$(echo "$software" | sed -e "s/php$fpm_v-pgsql//")
    if [ "$multiphp" = 'yes' ]; then
        for v in "${multiphp_v[@]}"; do
            software=$(echo "$software" | sed -e "s/php$v-pgsql//")
        done
    fi
    software=$(echo "$software" | sed -e "s/phppgadmin//")
fi
if [ "$iptables" = 'no' ] || [ "$fail2ban" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/fail2ban//")
fi
if [ "$phpfpm" = 'yes' ]; then
    software=$(echo "$software" | sed -e "s/php$fpm_v-cgi//")
fi
if [ -d "$withdebs" ]; then
    software=$(echo "$software" | sed -e "s/hestia-nginx//")
    software=$(echo "$software" | sed -e "s/hestia-php//")
    software=$(echo "$software" | sed -e "s/hestia//")
fi

#----------------------------------------------------------#
#                 Disable Apparmor on LXC                  #
#----------------------------------------------------------#

if grep --quiet lxc /proc/1/environ; then
    if [ -f /etc/init.d/apparmor ]; then
        systemctl stop apparmor > /dev/null 2>&1
        systemctl disable apparmor > /dev/null 2>&1
    fi
fi


#----------------------------------------------------------#
#                     Install packages                     #
#----------------------------------------------------------#

# Disabling daemon autostart on apt-get install
echo -e '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d
chmod a+x /usr/sbin/policy-rc.d

# Installing apt packages
echo "Now installing Hestia Control Panel and all required dependencies."
echo -ne "NOTE: This process may take 10 to 15 minutes to complete, please wait... "
echo
apt-get -y install $software > /dev/null 2>&1 &
BACK_PID=$!

# Check if package installation is done, print a spinner
spin_i=1
while kill -0 $BACK_PID > /dev/null 2>&1 ; do
    printf "\b${spinner:spin_i++%${#spinner}:1}"
    sleep 0.5
done

# Do a blank echo to get the \n back
echo

# Check Installation result
check_result $? "apt-get install failed"

# Install Hestia packages from local folder
if [ ! -z "$withdebs" ] && [ -d "$withdebs" ]; then
    dpkg -i $withdebs/hestia_*.deb

    if [ -z $(ls "$withdebs/hestia-php_*.deb" 2>/dev/null) ]; then
        apt-get -y install hestia-php > /dev/null 2>&1
    else
        dpkg -i $withdebs/hestia-php_*.deb
    fi

    if [ -z $(ls "$withdebs/hestia-nginx_*.deb" 2>/dev/null) ]; then
        apt-get -y install hestia-nginx > /dev/null 2>&1
    else
        dpkg -i $withdebs/hestia-nginx_*.deb
    fi
fi

# Restoring autostart policy
rm -f /usr/sbin/policy-rc.d


#----------------------------------------------------------#
#                     Configure system                     #
#----------------------------------------------------------#

echo "(*) Configuring system settings..."
# Enable SSH password authentication
sed -i "s/rdAuthentication no/rdAuthentication yes/g" /etc/ssh/sshd_config

# Enable SFTP subsystem for SSH
sftp_subsys_enabled=$(grep -iE "^#?.*subsystem.+(sftp )?sftp-server" /etc/ssh/sshd_config)
if [ ! -z "$sftp_subsys_enabled" ]; then
    sed -i -E "s/^#?.*Subsystem.+(sftp )?sftp-server/Subsystem sftp internal-sftp/g" /etc/ssh/sshd_config
fi

# Reduce SSH login grace time
sed -i "s/LoginGraceTime 2m/LoginGraceTime 1m/g" /etc/ssh/sshd_config
sed -i "s/#LoginGraceTime 2m/LoginGraceTime 1m/g" /etc/ssh/sshd_config

# Disable SSH suffix broadcast
if [ -z "$(grep "^DebianBanner no" /etc/ssh/sshd_config)" ]; then
    echo '' >> /etc/ssh/sshd_config
    echo 'DebianBanner no' >> /etc/ssh/sshd_config
fi

# Restart SSH daemon
systemctl restart ssh

# Disable AWStats cron
rm -f /etc/cron.d/awstats

# Set directory color
if [ -z "$(grep 'LS_COLORS="$LS_COLORS:di=00;33"' /etc/profile)" ]; then
    echo 'LS_COLORS="$LS_COLORS:di=00;33"' >> /etc/profile
fi

# Registering /usr/sbin/nologin
if [ -z "$(grep nologin /etc/shells)" ]; then
    echo "/usr/sbin/nologin" >> /etc/shells
fi

# Configuring NTP
echo '#!/bin/sh' > /etc/cron.daily/ntpdate
echo "$(which ntpdate) -s pool.ntp.org" >> /etc/cron.daily/ntpdate
chmod 755 /etc/cron.daily/ntpdate
ntpdate -s pool.ntp.org

# Setup rssh
if [ -z "$(grep /usr/bin/rssh /etc/shells)" ]; then
    echo /usr/bin/rssh >> /etc/shells
fi
sed -i 's/#allowscp/allowscp/' /etc/rssh.conf
sed -i 's/#allowsftp/allowsftp/' /etc/rssh.conf
sed -i 's/#allowrsync/allowrsync/' /etc/rssh.conf
chmod 755 /usr/bin/rssh


#----------------------------------------------------------#
#                     Configure Hestia                     #
#----------------------------------------------------------#

echo "(*) Configuring Hestia Control Panel..."
# Installing sudo configuration
mkdir -p /etc/sudoers.d
cp -f $HESTIA_INSTALL_DIR/sudo/admin /etc/sudoers.d/
chmod 440 /etc/sudoers.d/admin

# Configuring system env
echo "export HESTIA='$HESTIA'" > /etc/profile.d/hestia.sh
echo 'PATH=$PATH:'$HESTIA'/bin' >> /etc/profile.d/hestia.sh
echo 'export PATH' >> /etc/profile.d/hestia.sh
chmod 755 /etc/profile.d/hestia.sh
source /etc/profile.d/hestia.sh

# Configuring logrotate for Hestia logs
cp -f $HESTIA_INSTALL_DIR/logrotate/hestia /etc/logrotate.d/hestia

# Building directory tree and creating some blank files for Hestia
mkdir -p $HESTIA/conf $HESTIA/log $HESTIA/ssl $HESTIA/data/ips \
    $HESTIA/data/queue $HESTIA/data/users $HESTIA/data/firewall \
    $HESTIA/data/sessions
touch $HESTIA/data/queue/backup.pipe $HESTIA/data/queue/disk.pipe \
    $HESTIA/data/queue/webstats.pipe $HESTIA/data/queue/restart.pipe \
    $HESTIA/data/queue/traffic.pipe $HESTIA/log/system.log \
    $HESTIA/log/nginx-error.log $HESTIA/log/auth.log
chmod 750 $HESTIA/conf $HESTIA/data/users $HESTIA/data/ips $HESTIA/log
chmod -R 750 $HESTIA/data/queue
chmod 660 $HESTIA/log/*
rm -f /var/log/hestia
ln -s $HESTIA/log /var/log/hestia
chmod 770 $HESTIA/data/sessions

# Generating Hestia configuration
rm -f $HESTIA/conf/hestia.conf > /dev/null 2>&1
touch $HESTIA/conf/hestia.conf
chmod 660 $HESTIA/conf/hestia.conf

# Web stack
if [ "$apache" = 'yes' ] && [ "$nginx" = 'no' ] ; then
    echo "WEB_SYSTEM='apache2'" >> $HESTIA/conf/hestia.conf
    echo "WEB_RGROUPS='www-data'" >> $HESTIA/conf/hestia.conf
    echo "WEB_PORT='80'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL_PORT='443'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL='mod_ssl'"  >> $HESTIA/conf/hestia.conf
    echo "STATS_SYSTEM='awstats'" >> $HESTIA/conf/hestia.conf
fi
if [ "$apache" = 'yes' ] && [ "$nginx"  = 'yes' ] ; then
    echo "WEB_SYSTEM='apache2'" >> $HESTIA/conf/hestia.conf
    echo "WEB_RGROUPS='www-data'" >> $HESTIA/conf/hestia.conf
    echo "WEB_PORT='8080'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL_PORT='8443'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL='mod_ssl'"  >> $HESTIA/conf/hestia.conf
    echo "PROXY_SYSTEM='nginx'" >> $HESTIA/conf/hestia.conf
    echo "PROXY_PORT='80'" >> $HESTIA/conf/hestia.conf
    echo "PROXY_SSL_PORT='443'" >> $HESTIA/conf/hestia.conf
    echo "STATS_SYSTEM='awstats'" >> $HESTIA/conf/hestia.conf
fi
if [ "$apache" = 'no' ] && [ "$nginx"  = 'yes' ]; then
    echo "WEB_SYSTEM='nginx'" >> $HESTIA/conf/hestia.conf
    echo "WEB_PORT='80'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL_PORT='443'" >> $HESTIA/conf/hestia.conf
    echo "WEB_SSL='openssl'"  >> $HESTIA/conf/hestia.conf
    echo "STATS_SYSTEM='awstats'" >> $HESTIA/conf/hestia.conf
fi

if [ "$phpfpm" = 'yes' ] || [ "$multiphp" = 'yes' ]; then
    echo "WEB_BACKEND='php-fpm'" >> $HESTIA/conf/hestia.conf
fi

# FTP stack
if [ "$vsftpd" = 'yes' ]; then
    echo "FTP_SYSTEM='vsftpd'" >> $HESTIA/conf/hestia.conf
fi
if [ "$proftpd" = 'yes' ]; then
    echo "FTP_SYSTEM='proftpd'" >> $HESTIA/conf/hestia.conf
fi

# DNS stack
if [ "$named" = 'yes' ]; then
    echo "DNS_SYSTEM='bind9'" >> $HESTIA/conf/hestia.conf
fi

# Mail stack
if [ "$exim" = 'yes' ]; then
    echo "MAIL_SYSTEM='exim4'" >> $HESTIA/conf/hestia.conf
    if [ "$clamd" = 'yes'  ]; then
        echo "ANTIVIRUS_SYSTEM='clamav-daemon'" >> $HESTIA/conf/hestia.conf
    fi
    if [ "$spamd" = 'yes' ]; then
        echo "ANTISPAM_SYSTEM='spamassassin'" >> $HESTIA/conf/hestia.conf
    fi
    if [ "$dovecot" = 'yes' ]; then
        echo "IMAP_SYSTEM='dovecot'" >> $HESTIA/conf/hestia.conf
    fi
fi

# Cron daemon
echo "CRON_SYSTEM='cron'" >> $HESTIA/conf/hestia.conf

# Firewall stack
if [ "$iptables" = 'yes' ]; then
    echo "FIREWALL_SYSTEM='iptables'" >> $HESTIA/conf/hestia.conf
fi
if [ "$iptables" = 'yes' ] && [ "$fail2ban" = 'yes' ]; then
    echo "FIREWALL_EXTENSION='fail2ban'" >> $HESTIA/conf/hestia.conf
fi

# Disk quota
if [ "$quota" = 'yes' ]; then
    echo "DISK_QUOTA='yes'" >> $HESTIA/conf/hestia.conf
fi

# Backups
echo "BACKUP_SYSTEM='local'" >> $HESTIA/conf/hestia.conf

# Language
echo "LANGUAGE='$lang'" >> $HESTIA/conf/hestia.conf

# Version & Release Branch
echo "VERSION='1.1.0'" >> $HESTIA/conf/hestia.conf
echo "RELEASE_BRANCH='release'" >> $HESTIA/conf/hestia.conf

# Installing hosting packages
cp -rf $HESTIA_INSTALL_DIR/packages $HESTIA/data/

# Update nameservers in hosting package
IFS='.' read -r -a domain_elements <<< "$servername"
if [ ! -z "${domain_elements[-2]}" ] && [ ! -z "${domain_elements[-1]}" ]; then
    serverdomain="${domain_elements[-2]}.${domain_elements[-1]}"
    sed -i s/"domain.tld"/"$serverdomain"/g $HESTIA/data/packages/*.pkg
fi

# Installing templates
cp -rf $HESTIA_INSTALL_DIR/templates $HESTIA/data/

mkdir -p /var/www/html
mkdir -p /var/www/document_errors

# Install default success page
cp -rf $HESTIA_INSTALL_DIR/templates/web/unassigned/index.html /var/www/html/
cp -rf $HESTIA_INSTALL_DIR/templates/web/skel/document_errors/* /var/www/document_errors/

# Installing firewall rules
cp -rf $HESTIA_INSTALL_DIR/firewall $HESTIA/data/

# Configuring server hostname
$HESTIA/bin/v-change-sys-hostname $servername > /dev/null 2>&1

# Generating SSL certificate
echo "(*) Generating default self-signed SSL certificate..."
$HESTIA/bin/v-generate-ssl-cert $(hostname) $email 'US' 'California' \
     'San Francisco' 'Hestia Control Panel' 'IT' > /tmp/hst.pem

# Parsing certificate file
crt_end=$(grep -n "END CERTIFICATE-" /tmp/hst.pem |cut -f 1 -d:)
key_start=$(grep -n "BEGIN RSA" /tmp/hst.pem |cut -f 1 -d:)
key_end=$(grep -n  "END RSA" /tmp/hst.pem |cut -f 1 -d:)

# Adding SSL certificate
echo "(*) Adding SSL certificate to Hestia Control Panel..."
cd $HESTIA/ssl
sed -n "1,${crt_end}p" /tmp/hst.pem > certificate.crt
sed -n "$key_start,${key_end}p" /tmp/hst.pem > certificate.key
chown root:mail $HESTIA/ssl/*
chmod 660 $HESTIA/ssl/*
rm /tmp/hst.pem

# Adding nologin as a valid system shell
if [ -z "$(grep nologin /etc/shells)" ]; then
    echo "/usr/sbin/nologin" >> /etc/shells
fi

# Install dhparam.pem
cp -f $HESTIA_INSTALL_DIR/ssl/dhparam.pem /etc/ssl

#----------------------------------------------------------#
#                     Configure Nginx                      #
#----------------------------------------------------------#

if [ "$nginx" = 'yes' ]; then
    echo "(*) Configuring NGINX..."
    rm -f /etc/nginx/conf.d/*.conf
    cp -f $HESTIA_INSTALL_DIR/nginx/nginx.conf /etc/nginx/
    cp -f $HESTIA_INSTALL_DIR/nginx/status.conf /etc/nginx/conf.d/
    cp -f $HESTIA_INSTALL_DIR/nginx/phpmyadmin.inc /etc/nginx/conf.d/
    cp -f $HESTIA_INSTALL_DIR/nginx/phppgadmin.inc /etc/nginx/conf.d/
    cp -f $HESTIA_INSTALL_DIR/logrotate/nginx /etc/logrotate.d/
    mkdir -p /etc/nginx/conf.d/domains
    mkdir -p /var/log/nginx/domains

    # Update dns servers in nginx.conf
    dns_resolver=$(cat /etc/resolv.conf | grep -i '^nameserver' | cut -d ' ' -f2 | tr '\r\n' ' ' | xargs)
    for ip in $dns_resolver; do
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            resolver="$ip $resolver"
        fi
    done
    if [ ! -z "$resolver" ]; then
        sed -i "s/1.0.0.1 1.1.1.1/$resolver/g" /etc/nginx/nginx.conf
        sed -i "s/1.0.0.1 1.1.1.1/$resolver/g" /usr/local/hestia/nginx/conf/nginx.conf
    fi

    update-rc.d nginx defaults > /dev/null 2>&1
    systemctl start nginx >> $LOG
    check_result $? "nginx start failed"
fi


#----------------------------------------------------------#
#                    Configure Apache                      #
#----------------------------------------------------------#

if [ "$apache" = 'yes' ]; then
    echo "(*) Configuring Apache Web Server..."
    cp -f $HESTIA_INSTALL_DIR/apache2/apache2.conf /etc/apache2/
    cp -f $HESTIA_INSTALL_DIR/apache2/status.conf /etc/apache2/mods-enabled/
    cp -f $HESTIA_INSTALL_DIR/logrotate/apache2 /etc/logrotate.d/
    a2enmod rewrite > /dev/null 2>&1
    a2enmod suexec > /dev/null 2>&1
    a2enmod ssl > /dev/null 2>&1
    a2enmod actions > /dev/null 2>&1
    a2enmod ruid2 > /dev/null 2>&1
    mkdir -p /etc/apache2/conf.d
    mkdir -p /etc/apache2/conf.d/domains
    echo "# Powered by hestia" > /etc/apache2/sites-available/default
    echo "# Powered by hestia" > /etc/apache2/sites-available/default-ssl
    echo "# Powered by hestia" > /etc/apache2/ports.conf
    echo -e "/home\npublic_html/cgi-bin" > /etc/apache2/suexec/www-data
    touch /var/log/apache2/access.log /var/log/apache2/error.log
    mkdir -p /var/log/apache2/domains
    chmod a+x /var/log/apache2
    chmod 640 /var/log/apache2/access.log /var/log/apache2/error.log
    chmod 751 /var/log/apache2/domains

    update-rc.d apache2 defaults > /dev/null 2>&1
    systemctl start apache2 >> $LOG
    check_result $? "apache2 start failed"
else
    update-rc.d apache2 disable > /dev/null 2>&1
    systemctl stop apache2 > /dev/null 2>&1
fi


#----------------------------------------------------------#
#                     Configure PHP-FPM                    #
#----------------------------------------------------------#

if [ "$multiphp" = 'yes' ] ; then
    for v in "${multiphp_v[@]}"; do
        cp -r /etc/php/$v/ /root/hst_install_backups/php$v/
        rm -f /etc/php/$v/fpm/pool.d/*

        $HESTIA/bin/v-add-web-php "$v"
    done
fi

if [ "$phpfpm" = 'yes' ]; then
    echo "(*) Configuring PHP-FPM..."
    $HESTIA/bin/v-add-web-php "$fpm_v"
    cp -f $HESTIA_INSTALL_DIR/php-fpm/www.conf /etc/php/$fpm_v/fpm/pool.d/www.conf
    update-rc.d php$fpm_v-fpm defaults > /dev/null 2>&1
    systemctl start php$fpm_v-fpm >> $LOG
    check_result $? "php-fpm start failed"
fi


#----------------------------------------------------------#
#                     Configure PHP                        #
#----------------------------------------------------------#

echo "(*) Configuring PHP..."
ZONE=$(timedatectl > /dev/null 2>&1|grep Timezone|awk '{print $2}')
if [ -z "$ZONE" ]; then
    ZONE='UTC'
fi
for pconf in $(find /etc/php* -name php.ini); do
    sed -i "s%;date.timezone =%date.timezone = $ZONE%g" $pconf
    sed -i 's%_open_tag = Off%_open_tag = On%g' $pconf
done

# Cleanup php session files not changed in the last 7 days (60*24*7 minutes)
echo '#!/bin/sh' > /etc/cron.daily/php-session-cleanup
echo "find -O3 /home/*/tmp/ -ignore_readdir_race -depth -mindepth 1 -name 'sess_*' -type f -cmin '+10080' -delete > /dev/null 2>&1" >> /etc/cron.daily/php-session-cleanup
echo "find -O3 $HESTIA/data/sessions/ -ignore_readdir_race -depth -mindepth 1 -name 'sess_*' -type f -cmin '+10080' -delete > /dev/null 2>&1" >> /etc/cron.daily/php-session-cleanup
chmod 755 /etc/cron.daily/php-session-cleanup


#----------------------------------------------------------#
#                    Configure Vsftpd                      #
#----------------------------------------------------------#

if [ "$vsftpd" = 'yes' ]; then
    echo "(*) Configuring Vsftpd server..."
    cp -f $HESTIA_INSTALL_DIR/vsftpd/vsftpd.conf /etc/
    touch /var/log/vsftpd.log
    chown root:adm /var/log/vsftpd.log
    chmod 640 /var/log/vsftpd.log
    touch /var/log/xferlog
    chown root:adm /var/log/xferlog
    chmod 640 /var/log/xferlog
    update-rc.d vsftpd defaults
    systemctl start vsftpd >> $LOG
    check_result $? "vsftpd start failed"

fi


#----------------------------------------------------------#
#                    Configure ProFTPD                     #
#----------------------------------------------------------#

if [ "$proftpd" = 'yes' ]; then
    echo "(*) Configuring ProFTPD server..."
    echo "127.0.0.1 $servername" >> /etc/hosts
    cp -f $HESTIA_INSTALL_DIR/proftpd/proftpd.conf /etc/proftpd/
    update-rc.d proftpd defaults > /dev/null 2>&1
    systemctl start proftpd >> $LOG
    check_result $? "proftpd start failed"
fi


#----------------------------------------------------------#
#                  Configure MariaDB                       #
#----------------------------------------------------------#

if [ "$mysql" = 'yes' ]; then
    echo "(*) Configuring MariaDB database server..."
    mycnf="my-small.cnf"
    if [ $memory -gt 1200000 ]; then
        mycnf="my-medium.cnf"
    fi
    if [ $memory -gt 3900000 ]; then
        mycnf="my-large.cnf"
    fi

    # Configuring MariaDB
    cp -f $HESTIA_INSTALL_DIR/mysql/$mycnf /etc/mysql/my.cnf
    mysql_install_db >> $LOG

    update-rc.d mysql defaults > /dev/null 2>&1
    systemctl start mysql >> $LOG
    check_result $? "mariadb start failed"

    # Securing MariaDB installation
    mpass=$(gen_pass)
    mysqladmin -u root password $mpass >> $LOG
    echo -e "[client]\npassword='$mpass'\n" > /root/.my.cnf
    chmod 600 /root/.my.cnf

    # Clear MariaDB Test Users and Databases
    mysql -e "DELETE FROM mysql.user WHERE User=''"
    mysql -e "DROP DATABASE test" > /dev/null 2>&1
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
    mysql -e "DELETE FROM mysql.user WHERE user='';"
    mysql -e "DELETE FROM mysql.user WHERE password='' AND authentication_string='';"

    # Configuring phpMyAdmin
    if [ "$apache" = 'yes' ]; then
        cp -f $HESTIA_INSTALL_DIR/pma/apache.conf /etc/phpmyadmin/
        ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf.d/phpmyadmin.conf
    fi
    cp -f $HESTIA_INSTALL_DIR/pma/config.inc.php /etc/phpmyadmin/
    chmod 777 /var/lib/phpmyadmin/tmp
fi


#----------------------------------------------------------#
#                    Configure phpMyAdmin                  #
#----------------------------------------------------------#

if [ "$mysql" = 'yes' ]; then
    # Display upgrade information
    echo "(*) Installing phpMyAdmin version v$pma_v..."

    # Download latest phpmyadmin release
    wget --quiet https://files.phpmyadmin.net/phpMyAdmin/$pma_v/phpMyAdmin-$pma_v-all-languages.tar.gz

    # Unpack files
    tar xzf phpMyAdmin-$pma_v-all-languages.tar.gz

    # Delete file to prevent error
    rm -fr /usr/share/phpmyadmin/doc/html

    # Overwrite old files
    cp -rf phpMyAdmin-$pma_v-all-languages/* /usr/share/phpmyadmin

    # Set config and log directory
    sed -i "s|define('CONFIG_DIR', '');|define('CONFIG_DIR', '/etc/phpmyadmin/');|" /usr/share/phpmyadmin/libraries/vendor_config.php
    sed -i "s|define('TEMP_DIR', './tmp/');|define('TEMP_DIR', '/var/lib/phpmyadmin/tmp/');|" /usr/share/phpmyadmin/libraries/vendor_config.php

    # Create temporary folder and change permission
    mkdir /usr/share/phpmyadmin/tmp
    chmod 777 /usr/share/phpmyadmin/tmp

    # Clear Up
    rm -fr phpMyAdmin-$pma_v-all-languages
    rm -f phpMyAdmin-$pma_v-all-languages.tar.gz
fi


#----------------------------------------------------------#
#                   Configure PostgreSQL                   #
#----------------------------------------------------------#

if [ "$postgresql" = 'yes' ]; then
    echo "(*) Configuring PostgreSQL database server..."
    ppass=$(gen_pass)
    cp -f $HESTIA_INSTALL_DIR/postgresql/pg_hba.conf /etc/postgresql/*/main/
    systemctl restart postgresql
    sudo -iu postgres psql -c "ALTER USER postgres WITH PASSWORD '$ppass'"

    # Configuring phpPgAdmin
    if [ "$apache" = 'yes' ]; then
        cp -f $HESTIA_INSTALL_DIR/pga/phppgadmin.conf /etc/apache2/conf.d/
    fi
    cp -f $HESTIA_INSTALL_DIR/pga/config.inc.php /etc/phppgadmin/
fi


#----------------------------------------------------------#
#                      Configure Bind                      #
#----------------------------------------------------------#

if [ "$named" = 'yes' ]; then
    echo "(*) Configuring Bind DNS server..."
    cp -f $HESTIA_INSTALL_DIR/bind/named.conf /etc/bind/
    cp -f $HESTIA_INSTALL_DIR/bind/named.conf.options /etc/bind/
    chown root:bind /etc/bind/named.conf
    chown root:bind /etc/bind/named.conf.options
    chown bind:bind /var/cache/bind
    chmod 640 /etc/bind/named.conf
    chmod 640 /etc/bind/named.conf.options
    aa-complain /usr/sbin/named > /dev/null 2>&1
    echo "/home/** rwm," >> /etc/apparmor.d/local/usr.sbin.named 2> /dev/null
    if ! grep --quiet lxc /proc/1/environ; then
        systemctl status apparmor > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            systemctl restart apparmor >> $LOG
        fi
    fi
    update-rc.d bind9 defaults
    systemctl start bind9
    check_result $? "bind9 start failed"

    # Workaround for OpenVZ/Virtuozzo
    if [ -e "/proc/vz/veinfo" ] && [ -e "/etc/rc.local" ]; then
        sed -i "s/^exit 0/service bind9 restart\nexit 0/" /etc/rc.local
    fi
fi


#----------------------------------------------------------#
#                      Configure Exim                      #
#----------------------------------------------------------#

if [ "$exim" = 'yes' ]; then
    echo "(*) Configuring Exim mail server..."
    gpasswd -a Debian-exim mail > /dev/null 2>&1
    cp -f $HESTIA_INSTALL_DIR/exim/exim4.conf.template /etc/exim4/
    cp -f $HESTIA_INSTALL_DIR/exim/dnsbl.conf /etc/exim4/
    cp -f $HESTIA_INSTALL_DIR/exim/spam-blocks.conf /etc/exim4/
    touch /etc/exim4/white-blocks.conf

    if [ "$spamd" = 'yes' ]; then
        sed -i "s/#SPAM/SPAM/g" /etc/exim4/exim4.conf.template
    fi
    if [ "$clamd" = 'yes' ]; then
        sed -i "s/#CLAMD/CLAMD/g" /etc/exim4/exim4.conf.template
    fi

    chmod 640 /etc/exim4/exim4.conf.template
    rm -rf /etc/exim4/domains
    mkdir -p /etc/exim4/domains

    rm -f /etc/alternatives/mta
    ln -s /usr/sbin/exim4 /etc/alternatives/mta
    update-rc.d -f sendmail remove > /dev/null 2>&1
    systemctl stop sendmail > /dev/null 2>&1
    update-rc.d -f postfix remove > /dev/null 2>&1
    systemctl stop postfix > /dev/null 2>&1

    update-rc.d exim4 defaults
    systemctl start exim4 >> $LOG
    check_result $? "exim4 start failed"
fi


#----------------------------------------------------------#
#                     Configure Dovecot                    #
#----------------------------------------------------------#

if [ "$dovecot" = 'yes' ]; then
    echo "(*) Configuring Dovecot POP/IMAP mail server..."
    gpasswd -a dovecot mail > /dev/null 2>&1
    cp -rf $HESTIA_INSTALL_DIR/dovecot /etc/
    cp -f $HESTIA_INSTALL_DIR/logrotate/dovecot /etc/logrotate.d/
    if [ "$release" = '18.04' ]; then
        rm -f /etc/dovecot/conf.d/15-mailboxes.conf
    fi
    chown -R root:root /etc/dovecot*
    update-rc.d dovecot defaults
    systemctl start dovecot >> $LOG
    check_result $? "dovecot start failed"
fi


#----------------------------------------------------------#
#                     Configure ClamAV                     #
#----------------------------------------------------------#

if [ "$clamd" = 'yes' ]; then
    gpasswd -a clamav mail > /dev/null 2>&1
    gpasswd -a clamav Debian-exim > /dev/null 2>&1
    cp -f $HESTIA_INSTALL_DIR/clamav/clamd.conf /etc/clamav/
    update-rc.d clamav-daemon defaults
    echo -ne "(*) Installing ClamAV anti-virus definitions... "
    /usr/bin/freshclam >> $LOG &
    BACK_PID=$!
    spin_i=1
    while kill -0 $BACK_PID > /dev/null 2>&1 ; do
        printf "\b${spinner:spin_i++%${#spinner}:1}"
        sleep 0.5
    done
    echo
    systemctl start clamav-daemon >> $LOG
    check_result $? "clamav-daemon start failed"
fi


#----------------------------------------------------------#
#                  Configure SpamAssassin                  #
#----------------------------------------------------------#

if [ "$spamd" = 'yes' ]; then
    echo "(*) Configuring SpamAssassin..."
    update-rc.d spamassassin defaults > /dev/null 2>&1
    sed -i "s/ENABLED=0/ENABLED=1/" /etc/default/spamassassin
    systemctl start spamassassin >> $LOG
    check_result $? "spamassassin start failed"
    unit_files="$(systemctl list-unit-files |grep spamassassin)"
    if [[ "$unit_files" =~ "disabled" ]]; then
        systemctl enable spamassassin > /dev/null 2>&1
    fi
fi


#----------------------------------------------------------#
#                   Configure Roundcube                    #
#----------------------------------------------------------#

if [ "$dovecot" = 'yes' ] && [ "$exim" = 'yes' ] && [ "$mysql" = 'yes' ]; then
    echo "(*) Configuring Roundcube webmail client..."
    if [ "$apache" = 'yes' ]; then
        cp -f $HESTIA_INSTALL_DIR/roundcube/apache.conf /etc/roundcube/
        ln -s /etc/roundcube/apache.conf /etc/apache2/conf.d/roundcube.conf
    fi
    if [ "$nginx" = 'yes' ]; then
        cp -f $HESTIA_INSTALL_DIR/nginx/webmail.inc /etc/nginx/conf.d/
    fi
    cp -f $HESTIA_INSTALL_DIR/roundcube/main.inc.php /etc/roundcube/config.inc.php
    cp -f $HESTIA_INSTALL_DIR/roundcube/db.inc.php /etc/roundcube/debian-db-roundcube.php
    cp -f $HESTIA_INSTALL_DIR/roundcube/config.inc.php /etc/roundcube/plugins/password/
    cp -f $HESTIA_INSTALL_DIR/roundcube/hestia.php /usr/share/roundcube/plugins/password/drivers/
    touch /var/log/roundcube/errors
    chmod 640 /etc/roundcube/config.inc.php
    chown root:www-data /etc/roundcube/config.inc.php
    chmod 640 /etc/roundcube/debian-db-roundcube.php
    chown root:www-data /etc/roundcube/debian-db-roundcube.php
    chmod 640 /var/log/roundcube/errors
    chown www-data:adm /var/log/roundcube/errors

    r="$(gen_pass)"
    rcDesKey="$(openssl rand -base64 30 | tr -d "/" | cut -c1-24)"
    mysql -e "CREATE DATABASE roundcube"
    mysql -e "GRANT ALL ON roundcube.*
        TO roundcube@localhost IDENTIFIED BY '$r'"
    sed -i "s/%password%/$r/g" /etc/roundcube/debian-db-roundcube.php
    sed -i "s/%des_key%/$rcDesKey/g" /etc/roundcube/config.inc.php
    sed -i "s/localhost/$servername/g" /etc/roundcube/plugins/password/config.inc.php
    mysql roundcube < /usr/share/dbconfig-common/data/roundcube/install/mysql

    # Configure webmail alias
    echo "WEBMAIL_ALIAS='webmail'" >> $HESTIA/conf/hestia.conf

    # Add robots.txt
    echo "User-agent: *" > /var/lib/roundcube/robots.txt
    echo "Disallow: /" >> /var/lib/roundcube/robots.txt

    phpenmod mcrypt > /dev/null 2>&1

    # Restart services
    if [ "$apache" = 'yes' ]; then
        systemctl restart apache2 >> $LOG
    fi
    if [ "$nginx" = 'yes' ]; then
        systemctl restart nginx >> $LOG
    fi
fi


#----------------------------------------------------------#
#                    Configure Fail2Ban                    #
#----------------------------------------------------------#

if [ "$fail2ban" = 'yes' ]; then
    echo "(*) Configuring fail2ban access monitor..."
    cp -rf $HESTIA_INSTALL_DIR/fail2ban /etc/
    if [ "$dovecot" = 'no' ]; then
        fline=$(cat /etc/fail2ban/jail.local |grep -n dovecot-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
    fi
    if [ "$exim" = 'no' ]; then
        fline=$(cat /etc/fail2ban/jail.local |grep -n exim-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
    fi
    if [ "$vsftpd" = 'yes' ]; then
        #Create vsftpd Log File
        if [ ! -f "/var/log/vsftpd.log" ]; then
            touch /var/log/vsftpd.log
        fi
        fline=$(cat /etc/fail2ban/jail.local |grep -n vsftpd-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/false/true/" /etc/fail2ban/jail.local
    fi
    if [ -f /etc/fail2ban/jail.d/defaults-debian.conf ]; then
        rm -f /etc/fail2ban/jail.d/defaults-debian.conf
    fi

    update-rc.d fail2ban defaults
    systemctl start fail2ban >> $LOG
    check_result $? "fail2ban start failed"
fi


#----------------------------------------------------------#
#                       Configure API                      #
#----------------------------------------------------------#

if [ "$api" = 'yes' ]; then
    echo "API='yes'" >> $HESTIA/conf/hestia.conf
else
    rm -r $HESTIA/web/api
    echo "API='no'" >> $HESTIA/conf/hestia.conf
fi


#----------------------------------------------------------#
#                      Fix phpmyadmin                      #
#----------------------------------------------------------#
# Special thanks to Pavel Galkin (https://skurudo.ru)
# https://github.com/skurudo/phpmyadmin-fixer

if [ "$mysql" = 'yes' ]; then
    source $HESTIA_INSTALL_DIR/phpmyadmin/pma.sh > /dev/null 2>&1
fi


#----------------------------------------------------------#
#                   Configure Admin User                   #
#----------------------------------------------------------#

# Deleting old admin user
if [ ! -z "$(grep ^admin: /etc/passwd)" ] && [ "$force" = 'yes' ]; then
    chattr -i /home/admin/conf > /dev/null 2>&1
    userdel -f admin > /dev/null 2>&1
    chattr -i /home/admin/conf > /dev/null 2>&1
    mv -f /home/admin  $hst_backups/home/ > /dev/null 2>&1
    rm -f /tmp/sess_* > /dev/null 2>&1
fi
if [ ! -z "$(grep ^admin: /etc/group)" ] && [ "$force" = 'yes' ]; then
    groupdel admin > /dev/null 2>&1
fi

# Enable sftp jail
$HESTIA/bin/v-add-sys-sftp-jail > /dev/null 2>&1
check_result $? "can't enable sftp jail"

# Adding Hestia admin account
$HESTIA/bin/v-add-user admin $vpass $email default System Administrator
check_result $? "can't create admin user"
$HESTIA/bin/v-change-user-shell admin nologin
$HESTIA/bin/v-change-user-language admin $lang

# Configuring system IPs
$HESTIA/bin/v-update-sys-ip > /dev/null 2>&1

# Get main IP
ip=$(ip addr|grep 'inet '|grep global|head -n1|awk '{print $2}'|cut -f1 -d/)

# Configuring firewall
if [ "$iptables" = 'yes' ]; then
    $HESTIA/bin/v-update-firewall
fi

# Get public IP
pub_ip=$(curl --ipv4 -s https://ip.hestiacp.com/)
if [ ! -z "$pub_ip" ] && [ "$pub_ip" != "$ip" ]; then
    if [ -e /etc/rc.local ]; then
        sed -i '/exit 0/d' /etc/rc.local
    fi
    echo "$HESTIA/bin/v-update-sys-ip" >> /etc/rc.local
    echo "exit 0" >> /etc/rc.local
    chmod +x /etc/rc.local
    systemctl enable rc-local
    $HESTIA/bin/v-change-sys-ip-nat $ip $pub_ip > /dev/null 2>&1
    ip=$pub_ip
fi

# Configuring libapache2-mod-remoteip
if [ "$apache" = 'yes' ] && [ "$nginx"  = 'yes' ] ; then
    cd /etc/apache2/mods-available
    echo "<IfModule mod_remoteip.c>" > remoteip.conf
    echo "  RemoteIPHeader X-Real-IP" >> remoteip.conf
    if [ "$local_ip" != "127.0.0.1" ] && [ "$pub_ip" != "127.0.0.1" ]; then
        echo "  RemoteIPInternalProxy 127.0.0.1" >> remoteip.conf
    fi
    if [ ! -z "$local_ip" ] && [ "$local_ip" != "$pub_ip" ]; then
        echo "  RemoteIPInternalProxy $local_ip" >> remoteip.conf
    fi
    if [ ! -z "$pub_ip" ]; then
        echo "  RemoteIPInternalProxy $pub_ip" >> remoteip.conf
    fi
    echo "</IfModule>" >> remoteip.conf
    sed -i "s/LogFormat \"%h/LogFormat \"%a/g" /etc/apache2/apache2.conf
    a2enmod remoteip >> $LOG
    systemctl restart apache2
fi

# Configuring MariaDB host
if [ "$mysql" = 'yes' ]; then
    $HESTIA/bin/v-add-database-host mysql localhost root $mpass
fi

# Configuring PostgreSQL host
if [ "$postgresql" = 'yes' ]; then
    $HESTIA/bin/v-add-database-host pgsql localhost postgres $ppass
fi

# Adding default domain
$HESTIA/bin/v-add-web-domain admin $servername
check_result $? "can't create $servername domain"

# Adding cron jobs
export SCHEDULED_RESTART="yes"
command="sudo $HESTIA/bin/v-update-sys-queue restart"
$HESTIA/bin/v-add-cron-job 'admin' '*/2' '*' '*' '*' '*' "$command"
systemctl restart cron

command="sudo $HESTIA/bin/v-update-sys-queue disk"
$HESTIA/bin/v-add-cron-job 'admin' '15' '02' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-update-sys-queue traffic"
$HESTIA/bin/v-add-cron-job 'admin' '10' '00' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-update-sys-queue webstats"
$HESTIA/bin/v-add-cron-job 'admin' '30' '03' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-update-sys-queue backup"
$HESTIA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-backup-users"
$HESTIA/bin/v-add-cron-job 'admin' '10' '05' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-update-user-stats"
$HESTIA/bin/v-add-cron-job 'admin' '20' '00' '*' '*' '*' "$command"
command="sudo $HESTIA/bin/v-update-sys-rrd"
$HESTIA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"

# Enable automatic updates
$HESTIA/bin/v-add-cron-hestia-autoupdate

# Building initital rrd images
$HESTIA/bin/v-update-sys-rrd

# Enabling file system quota
if [ "$quota" = 'yes' ]; then
    $HESTIA/bin/v-add-sys-quota
fi

# Set backend port
$HESTIA/bin/v-change-sys-port $port

# Set default theme
$HESTIA/bin/v-change-sys-theme 'default'

# Starting Hestia service
update-rc.d hestia defaults
systemctl start hestia
check_result $? "hestia start failed"
chown admin:admin $HESTIA/data/sessions


#----------------------------------------------------------#
#                   Hestia Access Info                     #
#----------------------------------------------------------#

# Comparing hostname and IP
host_ip=$(host $servername| head -n 1 |awk '{print $NF}')
if [ "$host_ip" = "$ip" ]; then
    ip="$servername"
fi

echo -e "\n"
echo "===================================================================="
echo -e "\n"

# Sending notification to admin email
echo -e "Congratulations!

You have successfully installed Hestia Control Panel on your server.

Ready to get started? Log in using the following credentials:

    Admin URL:  https://$ip:$port
    Username:   admin
    Password:   $vpass

Thank you for choosing Hestia Control Panel to power your full stack web server,
we hope that you enjoy using it as much as we do!

Please feel free to contact us at any time if you have any questions,
or if you encounter any bugs or problems:

E-mail:  info@hestiacp.com
Web:     https://www.hestiacp.com/
Forum:   https://forum.hestiacp.com/
GitHub:  https://www.github.com/hestiacp/hestiacp

Note: Automatic updates are enabled by default. If you would like to disable them,
please log in and navigate to Server > Updates to turn them off.

Help support the Hestia Contol Panel project by donating via PayPal:
https://www.hestiacp.com/donate
--
Sincerely yours,
The Hestia Control Panel development team

Made with love & pride by the open-source community around the world.
" > $tmpfile

send_mail="$HESTIA/web/inc/mail-wrapper.php"
cat $tmpfile | $send_mail -s "Hestia Control Panel" $email

# Congrats
echo
cat $tmpfile
rm -f $tmpfile

# Add welcome message to notification panel
$HESTIA/bin/v-add-user-notification admin 'Welcome!' 'For more information on how to use Hestia Control Panel, click on the Help icon in the top right corner of the toolbar.<br><br>Please report any bugs or issues on GitHub at<br>https://github.com/hestiacp/hestiacp/issues<br><br>Have a great day!'

echo "(!) IMPORTANT: You must logout or restart the server before continuing."
echo ""
if [ "$interactive" = 'yes' ]; then
    echo -n " Do you want to logout now? [Y/N] "
    read resetshell

    if [ "$resetshell" = "Y" ] || [ "$resetshell" = "y" ]; then
        exit
    fi
fi

# EOF
