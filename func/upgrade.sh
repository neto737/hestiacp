#!/bin/bash

# Hestia Control Panel - Upgrade Control Script

#####################################################################
#######                Functions & Initialization             #######
#####################################################################

upgrade_welcome_message() {
    echo
    echo '                _   _           _   _        ____ ____                  '
    echo '               | | | | ___  ___| |_(_) __ _ / ___|  _ \                 '
    echo '               | |_| |/ _ \/ __| __| |/ _` | |   | |_) |                '
    echo '               |  _  |  __/\__ \ |_| | (_| | |___|  __/                 '
    echo '               |_| |_|\___||___/\__|_|\__,_|\____|_|                    '
    echo "                                                                        "
    echo "                  Hestia Control Panel Software Update                  "
    echo "                            Version: $new_version                       "
    echo "========================================================================"
    echo
    echo "(!) IMPORTANT INFORMATION:                                              "
    echo
    echo "Default configuration files and templates may be modified or replaced   "
    echo "during the upgrade process. You may restore these files from:           "
    echo ""
    echo "Backup directory: $HESTIA_BACKUP/                                       "
    echo
    echo "This process may take a few minutes, please wait...                     "
    echo
    echo "========================================================================"
    echo
}

upgrade_complete_message() {
    # Add notification to panel
    $HESTIA/bin/v-add-user-notification admin 'Upgrade complete' 'Your server has been updated to Hestia Control Panel <b>v'$new_version'</b>.<br><br>Please tell us about any bugs or issues by opening an issue report on <a href="https://github.com/hestiacp/hestiacp/issues" target="_new"><i class="fab fa-github"></i> GitHub</a> or e-mail <a href="mailto:info@hestiacp.com?Subject="['$new_version'] Bug Report: ">info@hestiacp.com</a>.<br><br><b>Have a wonderful day!</b><br><br><i class="fas fa-heart status-icon red"></i> The Hestia Control Panel development team'

    # Echo message to console output
    echo
    echo "========================================================================"
    echo
    echo "Upgrade complete! If you encounter any issues or find a bug,            "
    echo "please take a moment to report it to us on GitHub at the URL below:     "
    echo "https://github.com/hestiacp/hestiacp/issues                             "
    echo
    echo "We hope that you enjoy using this version of Hestia Control Panel,      "
    echo "have a wonderful day!                                                   "
    echo
    echo "Sincerely,                                                              "
    echo "The Hestia Control Panel development team                               "
    echo
    echo "Web:      https://www.hestiacp.com/                                     "
    echo "Forum:    https://forum.hestiacp.com/                                   "
    echo "GitHub:   https://github.com/hestiacp/hestiacp/                        "
    echo "E-mail:   info@hestiacp.com                                             "
    echo 
    echo "Made with love & pride by the open-source community around the world.   "
    echo
    echo
}

upgrade_init_backup() {
    # Ensure that backup directories are created
    mkdir -p $HESTIA_BACKUP/conf/
    mkdir -p $HESTIA_BACKUP/packages/
    mkdir -p $HESTIA_BACKUP/templates/
}

upgrade_refresh_config() {
    source /usr/local/hestia/conf/hestia.conf
    source /usr/local/hestia/func/main.sh
}

upgrade_start_routine() {
    #####################################################################
    #######       Ensure that release branch variable exists      #######
    #####################################################################
    release_branch_check=$(cat $HESTIA/conf/hestia.conf | grep RELEASE_BRANCH)
    if [ -z "$release_branch_check" ]; then
        echo "(*) Adding global release branch variable to system configuration..."
        $BIN/v-change-sys-config-value 'RELEASE_BRANCH' 'release'
    fi

    #####################################################################
    #######         Start upgrade for pre-release builds          #######
    #######     Ensures clean upgrade path from v1.0.1 onwards    #######
    #######             DO NOT MODIFY THIS SECTION                #######
    #####################################################################

    if [ $VERSION = "0.9.8-25" ] || [ $VERSION = "0.9.8-26" ] || [ $VERSION = "0.9.8-27" ] || [ $VERSION = "0.9.8-28" ] || [ $VERSION = "0.9.8-29" ] || [ $VERSION = "0.10.0" ] || [ $VERSION = "1.00.0-190618" ] || [ $VERSION = "1.00.0-190621" ] || [ $VERSION = "1.0.0" ]; then
        source $HESTIA/install/upgrade/versions/previous/0.9.8-29.sh
        source $HESTIA/install/upgrade/versions/previous/1.00.0-190618.sh
        source $HESTIA/install/upgrade/versions/previous/1.0.1.sh
        VERSION="1.0.1"
        upgrade_refresh_config
    fi
    
    #####################################################################
    #######             Start standard upgrade process            #######
    #######  Place instructions for all post v1.0.1 builds below  #######
    #####################################################################

    # Ensure that latest upgrade commands are processed if version is the same
    if [ $VERSION = "$new_version" ]; then
        echo "(!) The latest version of Hestia Control Panel is already installed."
        echo "    Verifying configuration..."
        echo ""
        source $HESTIA/install/upgrade/versions/latest.sh
        VERSION="$new_version"
        upgrade_refresh_config
    fi

    # Upgrade to Version 1.0.2
    if [ $VERSION = "1.0.1" ]; then
        source $HESTIA/install/upgrade/versions/previous/1.0.2.sh
        VERSION="1.0.2"
        upgrade_refresh_config
    fi

    # Upgrade to Version 1.0.3
    if [ $VERSION = "1.0.2" ]; then
        source $HESTIA/install/upgrade/versions/previous/1.0.3.sh
        VERSION="1.0.3"
        upgrade_refresh_config
    fi

    # Upgrade to Version 1.0.4
    if [ $VERSION = "1.0.3" ]; then
        source $HESTIA/install/upgrade/versions/previous/1.0.4.sh
        VERSION="1.0.4"
        upgrade_refresh_config
    fi

    # Upgrade to Version 1.0.5
    if [ $VERSION = "1.0.4" ]; then
        source $HESTIA/install/upgrade/versions/previous/1.0.5.sh
        VERSION="1.0.5"
        upgrade_refresh_config
    fi

    # Upgrade to Version 1.0.6
    if [ $VERSION = "1.0.5" ]; then
        source $HESTIA/install/upgrade/versions/previous/1.0.6.sh
        VERSION="1.0.6"
        upgrade_refresh_config
    fi

    # Upgrade to Version 1.1.0
    if [ $VERSION = "1.0.6" ]; then
        source $HESTIA/install/upgrade/versions/latest.sh
        VERSION="1.1.0"
        upgrade_refresh_config
    fi

    # Upgrade to Version 1.1.1
    if [ $VERSION = "1.1.0" ]; then
        source $HESTIA/install/upgrade/versions/latest.sh
        VERSION="1.1.1"
        upgrade_refresh_config
    fi

    # Upgrade to Version 1.2.0
    if [ $VERSION = "1.1.1" ]; then
        source $HESTIA/install/upgrade/versions/latest.sh
        VERSION="$new_version"
        upgrade_refresh_config
    fi

    #####################################################################
    #######     End version-specific upgrade instruction sets     #######
    #####################################################################
}

upgrade_phpmyadmin() {
    # Check if MariaDB/MySQL is installed on the server before attempting to install or upgrade phpMyAdmin
    if [ "$DB_SYSTEM" = "mysql" ]; then
        # Define version check function
        function version_ge(){ test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" -o ! -z "$1" -a "$1" = "$2"; }

        pma_release_file=$(ls /usr/share/phpmyadmin/RELEASE-DATE-* 2>/dev/null |tail -n 1)
        if version_ge "${pma_release_file##*-}" "$pma_v"; then
            echo "(!) phpMyAdmin v${pma_release_file##*-} is already installed, skipping update..."
        else
            # Display upgrade information
            echo "(*) Upgrading phpMyAdmin to version v$pma_v..."
            [ -d /usr/share/phpmyadmin ] || mkdir -p /usr/share/phpmyadmin

            # Download latest phpMyAdmin release
            wget --quiet https://files.phpmyadmin.net/phpMyAdmin/$pma_v/phpMyAdmin-$pma_v-all-languages.tar.gz

            # Unpack files
            tar xzf phpMyAdmin-$pma_v-all-languages.tar.gz

            # Delete file to prevent error
            rm -fr /usr/share/phpmyadmin/doc/html

            # Overwrite old files
            cp -rf phpMyAdmin-$pma_v-all-languages/* /usr/share/phpmyadmin

            # Set config and log directory
            sed -i "s|define('CONFIG_DIR', ROOT_PATH);|define('CONFIG_DIR', '/etc/phpmyadmin/');|" /usr/share/phpmyadmin/libraries/vendor_config.php
            sed -i "s|define('TEMP_DIR', ROOT_PATH . 'tmp/');|define('TEMP_DIR', '/var/lib/phpmyadmin/tmp/');|" /usr/share/phpmyadmin/libraries/vendor_config.php

            # Create temporary folder and change permissions
            if [ ! -d /usr/share/phpmyadmin/tmp ]; then
                mkdir /usr/share/phpmyadmin/tmp
                chmod 777 /usr/share/phpmyadmin/tmp
            fi

            # Clean up source files
            rm -fr phpMyAdmin-$pma_v-all-languages
            rm -f phpMyAdmin-$pma_v-all-languages.tar.gz
        fi
    fi
}

upgrade_fm_configuration() {
    if [ -e "$HESTIA/web/fm/configuration.php" ]; then
        echo "(*) Updating File Manager Configuration..."
        cp -f $HESTIA_INSTALL_DIR/filemanager/filegator/configuration.php $HESTIA/web/fm/configuration.php
    fi
}

upgrade_get_version() {
    # Retrieve new version number for Hestia Control Panel from .deb package
    new_version=$(dpkg -l | awk '$2=="hestia" { print $3 }')
}

upgrade_set_version() {
    # Set new version number in hestia.conf
    sed -i "/VERSION/d" $HESTIA/conf/hestia.conf
    echo "VERSION='$new_version'" >> $HESTIA/conf/hestia.conf
}

upgrade_rebuild_users() {
    for user in $($HESTIA/bin/v-list-sys-users plain); do
        echo "(*) Rebuilding domains and account for user: $user..."
        if [ ! -z "$WEB_SYSTEM" ]; then
            $BIN/v-rebuild-web-domains $user 'no' >/dev/null 2>&1
        fi
        if [ ! -z "$DNS_SYSTEM" ]; then
            $BIN/v-rebuild-dns-domains $user 'no' >/dev/null 2>&1
        fi
        if [ ! -z "$MAIL_SYSTEM" ]; then 
            $BIN/v-rebuild-mail-domains $user 'no' >/dev/null 2>&1
        fi
    done
}

upgrade_restart_services() {
    # Refresh user interface theme
    if [ "$THEME" ]; then
        if [ "$THEME" != "default" ]; then
            echo "(*) Applying user interface updates..."
            $BIN/v-change-sys-theme $THEME
        fi
    fi

    echo "(*) Restarting services..."
    sleep 5
    if [ ! -z "$MAIL_SYSTEM" ]; then
        $BIN/v-restart-mail $restart
    fi
    if [ ! -z "$WEB_SYSTEM" ]; then
        $BIN/v-restart-web $restart
        $BIN/v-restart-proxy $restart
    fi
    if [ ! -z "$DNS_SYSTEM" ]; then
        $BIN/v-restart-dns $restart
    fi
    for v in `ls /etc/php/`; do
        if [ -e /etc/php/$v/fpm ]; then
            $BIN/v-restart-service php$v-fpm $restart
        fi
    done
    if [ ! -z "$FTP_SYSTEM" ]; then
        $BIN/v-restart-ftp $restart
    fi
    if [ ! -z "$FIREWALL_EXTENSION" ]; then
        $BIN/v-restart-service $FIREWALL_EXTENSION yes
    fi

    # Restart SSH daemon and Hestia Control Panel service
    $BIN/v-restart-service ssh $restart
    $BIN/v-restart-service hestia $restart
}

