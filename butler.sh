#!/bin/bash
#
# This script is an entry point for a new server \ cluster set up. 
# Depending on choices you make it will include other helper scripts. 
# You may choose Interactive mode or Full Automatic (based on YAML configs).
#
# Restrictions: 
#   - 
# 

if [[ $(pwd) != *"/qzhub_butler" ]]; then
  echo "Please run this script from '.../qzhub_butler' directory!"
  exit 1
fi

# Includes
. ./includes/parse_yaml.sh
. ./includes/helpers.sh

# Workflow entry point
#TODO(sm42): local (?) use_config 

# Interactive or YAML mode?
read -p "Do you want to use preconfigured YAML? (y/n): " use_config
readonly use_config 
if [[ ${use_config} == "y" ]]; then
  eval $(parse_yaml butler_config.yaml "conf_")
else
  eval $(parse_yaml butler_config_description.yaml "conf_")
fi

# Is the script running on the target server?
ipList=$(ip -4 -o addr show | awk '{gsub(/\/.*/,"",$4); print $4}')
targetServerIP=$(get_var 'conf_server_ip')
runningOnServer=0
for ip in $ipList; do
  if [[ ${ip} == ${targetServerIP} ]]; then
    ((runningOnServer++))
    break
  fi 
done

if [[ $runningOnServer == 0 ]]; then # script is started on a client
  echo ""
  echo "STEP 1: uploading neccessary files to the remote server."
  echo "Looks like you are running this script on a local computer."
  echo "Now your SSH public key and 'qzhub_butler' directory will be copied to the target server."
  read -p "Should I proceed? (y/n): " 

  if [[ $REPLY == "y" ]]; then
    echo ""
    read -e -p "Specify your public SSH key to be uploaded to server: " \
         -i "$HOME/.ssh/id_rsa.pub" 
    cp $REPLY ./public_ssh_key
    scp -r ../qzhub_butler root@$targetServerIP:~/
    rm -f ./public_ssh_key
    echo ""
    echo "Now run this scipt on the target server as 'root'. See you soon!"
  else 
    echo "Good bye!"
  fi

  exit 0

else # script is running on the target server. Let's check who is running the script
  if [[ $(whoami) == "root" ]]; then
    echo "STEP 2: remote user configuration."
    remoteUserName=$(get_var 'conf_remoteUser_name')
    # checking if the user already exists
    if [[ $(getent passwd $remoteUserName) ]]; then # user exists
      read -p "User $remoteUserName already exists. Directory 'qzhub_butler' will be moved to his home dir. Continue? (y/n): "
      [[ $REPLY != "y" ]] && { echo "Good bye!"; exit 0; }
    else # user doesn't exist
      read -p "I will create a new user '$remoteUserName'. Continue? (y/n): "
      [[ $REPLY != "y" ]] && { echo "Good bye!"; exit 0; }

      if [[ $(cat /proc/version | grep 'Ubuntu') ]]; then
        sudoGroup='sudo'
      elif [[ $(cat /proc/version | grep 'Red Hat') ]]; then
        sudoGroup='wheel'
      else
        read -p "Alas! I was unable to detect your OS family. Please indicate sudo-users group name (e.g.: wheel, sudo): " sudoGroup
      fi

      useradd -s /bin/bash -G $sudoGroup -m $remoteUserName
      echo "User '$remoteUserName' was created with 'sudo' rights."
      passwd $remoteUserName
    fi
    
    mkdir -p -m 700 /home/$remoteUserName/.ssh/
    cat ./public_ssh_key >> /home/$remoteUserName/.ssh/authorized_keys
    rm ./public_ssh_key
    mv ../qzhub_butler /home/$remoteUserName
    chown -R $remoteUserName:$remoteUserName /home/$remoteUserName/.ssh
    chown -R $remoteUserName:$remoteUserName /home/$remoteUserName/qzhub_butler
    chmod 600 /home/$remoteUserName/.ssh/authorized_keys
    cd /home/$remoteUserName/qzhub_butler/artefacts/
    mv -t /home/$remoteUserName/ .bashrc .bash_aliases
    echo "Directory 'qzhub_butler' was moved to /home/$remoteUserName."
    echo "Now reconnect to the server as '$remoteUserName' via SSH and run this script again."
    exit 0
  fi # if [[ $(whoami) == "root" ]]; then
fi # if [[ $runningOnServer == 0 ]]; then


echo "STEP 3: "
# Choose type of server k8s | db | hadoop | etc.
# # Based on choice utilize appropriate include script
# Provide ouput message and cleanup


# TODO(sm42): Log every step to an audit file


