#!/bin/bash

# instalacion y configuracion inicial
sudo apt update
sudo apt install -y sox
sudo timedatectl set-timezone Europe/Madrid

SHELL=/bin/bash
USERNAME=BirDeep

PASS=BirDeep
SALT="Q9"
CYPPASS=$(perl -e 'print crypt($ARGV[0], Q9)' $PASS)
echo Creating user: $USERNAME $PASS $CYPPASS

sudo useradd -m -d /home/$USERNAME -s "$SHELL" $USERNAME -p $CYPPASS && chmod 700 /home/$USERNAME
sudo cp .bashrc /home/$USERNAME/.bashrc && sudo chown $USERNAME /home/$USERNAME/.bashrc && sudo chgrp $USERNAME /home/$USERNAME/.bashrc
#usermod -aG sudo $USERNAME

sudo mkdir -p /home/$USERNAME/recordings
sudo mkdir -p /home/$USERNAME/sdBackup

sudo chmod +x /home/$USERNAME/record.sh
sudo cp -r FileServerBin spectrogram /home/$USERNAME/

sudo cp audiomoth-live.service /etc/systemd/system/audiomoth-live.service
sudo cp simpleHttpServer.service /etc/systemd/system/simpleHttpServer.service
sudo systemctl enable audiomoth-live.service
sudo systemctl enable simpleHttpServer.service
sudo service audiomoth-live start
sudo service simpleHttpServer start
sudo cp BirdDeep-Admin.nmconnection /etc/NetworkManager/system-connections/