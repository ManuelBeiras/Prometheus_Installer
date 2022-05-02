#!/bin/bash
#########################################################################################################
##Prometheus installation script 											                           ##
##Date: 14/10/2021                                                                                     ##
##Version 1.0:  Allows simple installation of Prometheus.							                   ##
##        If the installation of all components is done on the same machine                            ##
##        a fully operational version remains. If installed on different machines                      ##
##        it is necessary to modify the configuration manually.                                        ##
##        Fully automatic installation only requires a password change at the end if you want.         ##
##                                                                                                     ##
##Authors:                                                                                             ##
##			Manuel José Beiras Belloso																   ##
##			Rubén Míguez Bouzas										                                   ##
##			Luis Mera Castro										                                   ##
#########################################################################################################

# Initial check if the user is root and the OS is Ubuntu
function initialCheck() {
	if ! isRoot; then
		echo "The script must be executed as a root"
		exit 1
	fi
}

# Check if the user is root
function isRoot() {
    if [ "$EUID" -ne 0 ]; then
		return 1
	fi
	checkOS
}

# Check the operating system
function checkOS() {
    source /etc/os-release
	if [[ $ID == "ubuntu" ]]; then
	    OS="ubuntu"
	    MAJOR_UBUNTU_VERSION=$(echo "$VERSION_ID" | cut -d '.' -f1)
	    if [[ $MAJOR_UBUNTU_VERSION -lt 20 ]]; then
            echo "⚠️ This script it's not tested in your Ubuntu version. You want to continue?"
			echo ""
			CONTINUE='false'
			until [[ $CONTINUE =~ (y|n) ]]; do
			    read -rp "Continue? [y/n]: " -e CONTINUE
			done
			if [[ $CONTINUE == "n" ]]; then
				exit 1
			fi
		fi
		questionsMenu
	else
        echo "Your OS it's not Ubuntu, in the case you are using Centos you can continue from here. Press [Y]"
		CONTINUE='false'
		until [[ $CONTINUE =~ (y|n) ]]; do
			read -rp "Continue? [y/n]: " -e CONTINUE
		done
		if [[ $CONTINUE == "n" ]]; then
			exit 1
		fi
		OS="centos"
		questionsMenu
	fi
}

function questionsMenu() {
    echo -e "What you want to do ?"
	echo "1. Install Prometheus."
	echo "2. Uninstall Prometheus."
    echo "0. exit."
    read -e CONTINUE
    if [[ $CONTINUE == 1 ]]; then
        installPrometheus
    elif [[ $CONTINUE == 2 ]]; then
        uninstallPrometheus
    elif [[ $CONTINUE == 0 ]]; then
        exit 1
    else
		echo "invalid option !"
        clear
		questionsMenu
    fi
}

function installPrometheus() {
    if [[ $OS == "ubuntu" ]]; then
        if dpkg -l | grep prometheus > /dev/null; then
            echo "Prometheus it's already installed on your system."
            echo "Installation cancelled."
        else
            apt update -y
            # Download the Prometheus release package.
            wget https://github.com/prometheus/prometheus/releases/download/v2.31.0/prometheus-2.31.0.linux-amd64.tar.gz
            # Extract the downloaded archive.
            tar xvf prometheus-2.31.0.linux-amd64.tar.gz
            # Change directory to the extracted archive.
            cd prometheus-2.31.0.linux-amd64
            # Create the configuration file directory.
            mkdir -p /etc/prometheus
            # Create the data directory.
            mkdir -p /var/lib/prometheus
            # Move the binary files prometheus and promtool to /usr/local/bin/.
            mv prometheus promtool /usr/local/bin/
            # Move console files in console directory and library files in console_libraries directory to /etc/prometheus/ directory.
            mv consoles/ console_libraries/ /etc/prometheus/
            # Move the template configuration file prometheus.yml to /etc/prometheus/ directory
            mv prometheus.yml /etc/prometheus/prometheus.yml
            # Create a prometheus group.
            groupadd --system prometheus
            # Create a user prometheus and assign it to the created prometheus group.
            useradd -s /sbin/nologin --system -g prometheus prometheus
            # Set the ownership of Prometheus files and data directories to the prometheus group and user.
            chown -R prometheus:prometheus /etc/prometheus/  /var/lib/prometheus/
            chmod -R 775 /etc/prometheus/ /var/lib/prometheus/
            # Create a systemd service file for Prometheus to start at boot time.
            cat << EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Restart=always
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF
            # Start the Prometheus service.
            systemctl start prometheus
            # Enable the Prometheus service to run at system startup.
            systemctl enable prometheus
            echo ""
            echo ""
            echo "Prometheus installation succeded."
            echo ""
            echo ""
        fi
    fi
}

function uninstallPrometheus() {
    service prometheus stop
    rm -f /etc/prometheus
    rm -f /var/lib/prometheus/
    rm /etc/systemd/system/prometheus.service
    echo ""
    echo ""
    echo ""
    echo "Prometheus uninstalled."
    echo ""
    echo ""
    echo ""
}

initialCheck