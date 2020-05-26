#!/bin/bash

#set -x

#Install prerequisite RPMs and make changes to files

sudo sed -i 's/inet_protocols = all/inet_protocols = ipv4/' /etc/postfix/main.cf

if [ -z $(rpm -qa | grep rpm-build | grep -v lib) ]; then
    sudo yum -q install rpm-build -y
fi

if [ -z $(rpm -qa | grep unzip) ]; then
    sudo yum -q install unzip -y
fi

if [ -z $(rpm -qa | grep mailx) ]; then
    sudo yum -q install mailx -y
fi

if [ -z $(sudo ls /var/spool/postfix/public/pickup) ]; then
    sudo mkfifo /var/spool/postfix/public/pickup && sudo systemctl restart postfix
fi

#Try to download storCLI zip

if [ -z $(find ~ -name 'Unified_storcli_all_os.zip') ]; then 
    wget https://www.supermicro.com/wftp/driver/SAS/LSI/3108/managment/StorCLI/Unified_storcli_all_os.zip ~/
fi

#Install storCLI

function installfunc()
{
mkdir ~/smdrivechk
unzip ~/Unified_storcli_all_os.zip -d ~/smdrivechk/
cd ~/smdrivechk/Linux
sudo chmod +x splitpackage.sh

if [ $(arch) == x86_64 ]; then
    sudo ./splitpackage.sh storcli*noarch.rpm;
    sudo rpm -ivh storcli*x86_64.rpm;
    echo -e "\nThe software has been installed.  Run this script again to see hard drive health status"    

elif [ $(arch) == i386 ]; then
    sudo rpm -ivh storcli*i386.rpm
    echo -e "\nThe software has been installed.  Run this script again to see hard drive health status"

elif [ $(arch) != x86_64 ] or [ $(arch) != i386 ]; then
    sudo rpm -ivh storcli*noarch.rpm
    echo -e "\nThe software has been installed.  Run this script again to see hard drive health status"

else
    echo "This software is incompatible with your OS"

fi

}

#Run storCLI if it has been installed, email a user if the address has been specified

function checkfunc()
{
ctlrcheck=$(sudo /opt/MegaRAID/storcli/storcli64 show all | grep -m 1 -A6 'Ctl' | awk '{ print$1 }' | grep -Eo '[0-9]')

for each in $ctlrcheck; do sudo /opt/MegaRAID/storcli/storcli64 /c$each /eall /sall show all | grep -A1 -B6 -E 'Predictive Failure Count = [0-9]{1,}';done
}


if [ -z $(rpm -qa storcli\*) ]; then
    installfunc

elif [ -n $(rpm -qa storcli\*) ]; then
    checkfunc
    results=$(checkfunc)

    if [ -z "$results" ]; then
    echo "No failed drives detected"; exit 0

    else
    echo "$results" | mailx -r $(hostname -a) -s "Hard drive failure detected" #Remove this comment and add user email here
    fi

fi

