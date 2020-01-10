#!/bin/sh

# Hestia Control Panel upgrade script for target version 1.1.0

#######################################################################################
#######                      Place additional commands below.                   #######
#######################################################################################

# Set default theme
if [ -z $THEME ]; then
    echo "(*) Enabling support for themes..."
    $BIN/v-change-sys-theme 'default'
fi

# Reduce SSH login grace time
if [ -e /etc/ssh/sshd_config ]; then
    echo "(*) Hardening SSH daemon configuration..."
    sed -i "s/LoginGraceTime 2m/LoginGraceTime 1m/g" /etc/ssh/sshd_config
    sed -i "s/#LoginGraceTime 2m/LoginGraceTime 1m/g" /etc/ssh/sshd_config
fi

# Implement recidive jail for fail2ban
if [ ! -z "$FIREWALL_EXTENSION" ]; then
    if ! cat /etc/fail2ban/jail.local | grep -q "\[recidive\]"; then
        echo -e "\n\n[recidive]\nenabled  = true\nfilter   = recidive\naction   = hestia[name=HESTIA]\nlogpath  = /var/log/fail2ban.log\nmaxretry = 3\nfindtime = 86400\nbantime  = 864000" >> /etc/fail2ban/jail.local
    fi
fi

# Enable OCSP SSL stapling and harden nginx configuration for roundcube
if [ ! -z "$IMAP_SYSTEM" ]; then
    echo "(*) Hardening security of Roundcube webmail..."
    $BIN/v-update-mail-templates > /dev/null 2>&1
    if [ -e /etc/nginx/conf.d/webmail.inc ]; then
        cp -f /etc/nginx/conf.d/webmail.inc $HESTIA_BACKUP/conf/
        sed -i "s/config|temp|logs/README.md|config|temp|logs|bin|SQL|INSTALL|LICENSE|CHANGELOG|UPGRADING/g" /etc/nginx/conf.d/webmail.inc
    fi
fi

# Fix restart queue
if [ -z "$($BIN/v-list-cron-jobs admin | grep 'v-update-sys-queue restart')" ]; then
    command="sudo $BIN/v-update-sys-queue restart"
    $BIN/v-add-cron-job 'admin' '*/2' '*' '*' '*' '*' "$command"
fi

# Remove deprecated line from ClamAV configuration file
if [ -e "/etc/clamav/clamd.conf" ]; then
    clamd_conf_update_check=$(grep DetectBrokenExecutables /etc/clamav/clamd.conf)
    if [ ! -z "$clamd_conf_update_check" ]; then
        echo "(*) Updating ClamAV configuration..."
        sed -i '/DetectBrokenExecutables/d' /etc/clamav/clamd.conf
    fi
fi

# Remove errornous history.log file created by certain builds due to bug in v-restart-system
if [ -e $HESTIA/data/users/history.log ]; then
    rm -f $HESTIA/data/users/history.log
fi

# Use exim4 server hostname instead of mail domain and remove hardcoded mail prefix
if [ ! -z "$MAIL_SYSTEM" ]; then
    if cat /etc/exim4/exim4.conf.template | grep -q 'helo_data = mail.${sender_address_domain}'; then
        echo "(*) Updating exim configuration..."
        sed -i 's/helo_data = mail.${sender_address_domain}/helo_data = ${primary_hostname}/g' /etc/exim4/exim4.conf.template
    fi
fi

# Members of admin group should be permitted to enter admin folder
if [ -d /home/admin ]; then
    setfacl -m "g:admin:r-x" /home/admin
fi

# Fix sftp jail cronjob
if [ -e "/etc/cron.d/hestia-sftp" ]; then
    if ! cat /etc/cron.d/hestia-sftp | grep -q 'admin'; then
        echo "@reboot admin /usr/local/hestia/bin/v-add-sys-sftp-jail" > /etc/cron.d/hestia-sftp
    fi
fi

# Create default writeable folders for all users
echo "(*) Updating default writable folders for all users..."
for user in $($HESTIA/bin/v-list-sys-users plain); do
    mkdir -p \
        $HOMEDIR/$user/.config \
        $HOMEDIR/$user/.local \
        $HOMEDIR/$user/.composer \
        $HOMEDIR/$user/.ssh

    chown $user:$user \
        $HOMEDIR/$user/.config \
        $HOMEDIR/$user/.local \
        $HOMEDIR/$user/.composer \
        $HOMEDIR/$user/.ssh
done

# Remove redundant fail2ban jail
if fail2ban-client status sshd > /dev/null 2>&1 ; then
    fail2ban-client stop sshd >/dev/null 2>&1
    if [ -f /etc/fail2ban/jail.d/defaults-debian.conf ]; then
        mkdir -p $HESTIA_BACKUP/conf/fail2ban/jail.d
        mv /etc/fail2ban/jail.d/defaults-debian.conf $HESTIA_BACKUP/conf/fail2ban/jail.d/
    fi
fi

# Update Office 365/Microsoft 365 DNS template
if [ -e "$HESTIA/data/templates/dns/office365.tpl" ]; then
    echo "(*) Updating DNS template for Office 365..."
    cp -f $HESTIA/install/deb/templates/dns/office365.tpl $HESTIA/data/templates/dns/office365.tpl
fi

# Ensure that backup compression level is correctly set
GZIP_LVL_CHECK=$(cat $HESTIA/conf/hestia.conf | grep BACKUP_GZIP)
if [ -z "$GZIP_LVL_CHECK" ]; then
    echo "(*) Updating backup compression level variable..."
    $BIN/v-change-sys-config-value "BACKUP_GZIP" '9'
fi

# Randomize Roundcube des_key for better security
if [ -f "/etc/roundcube/config.inc.php" ]; then
    rcDesKey="$(openssl rand -base64 30 | tr -d "/" | cut -c1-24)"
    sed -i "s/vtIOjLZo9kffJoqzpSbm5r1r/$rcDesKey/g" /etc/roundcube/config.inc.php
fi

# Place robots.txt to prevent webmail crawling by search engine bots.
if [ -e "/var/lib/roundcube/" ]; then
    if [ ! -f "/var/lib/roundcube/robots.txt" ]; then
        echo "User-agent: *" > /var/lib/roundcube/robots.txt
        echo "Disallow: /" >> /var/lib/roundcube/robots.txt
    fi
fi

# Installing postgresql repo
if [ -e "/etc/postgresql" ]; then
    osname="$(cat /etc/os-release | grep "^ID\=" | sed "s/ID\=//g")"
    if [ "$osname" = "ubuntu" ]; then
        codename="$(lsb_release -s -c)"
    else
        codename="$(cat /etc/os-release |grep VERSION= |cut -f 2 -d \(|cut -f 1 -d \))"
    fi
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $codename-pgdg main" > /etc/apt/sources.list.d/postgresql.list
    wget --quiet https://www.postgresql.org/media/keys/ACCC4CF8.asc -O /tmp/psql_signing.key
    APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add /tmp/psql_signing.key > /dev/null 2>&1
    rm /tmp/psql_signing.key
fi

# Hardening MySQL configuration, prevent local infile.
if [ -e "/etc/mysql/my.cnf" ]; then
    mysql_local_infile_check=$(grep local-infile /etc/mysql/my.cnf)
    if [ -z "$mysql_local_infile_check" ]; then
        echo "(*) Hardening MySQL configuration..."
        sed -i '/symbolic-links\=0/a\local-infile=0' /etc/mysql/my.cnf
    fi
fi
