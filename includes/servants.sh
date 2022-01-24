#
#

function choose_execution_mode {
  read -p "Do you want to use preconfigured YAML? (y/n): "
  
  if [[ $REPLY == "y" ]]; then
    readonly useYamlConfig=$REPLY
    eval $(parse_yaml $CONFIG_YAML "conf_")
  else
    eval $(parse_yaml $CONFIG_YAML_ANNOTATION "conf_")
  fi
}

function detect_exec_on_server {
  # will go through all IPv4 addresses and compare with target server's IP
  local ipList=$(ip -4 -o addr show | awk '{gsub(/\/.*/,"",$4); print $4}')
  readonly serverIP=$(get_var 'conf_server_ip')

  for ip in ${ipList}; do
    if [[ ${ip} == ${serverIP} ]]; then
      runningOnServer=0
      break
    fi 
  done
  #readonly serverIP
  readonly runningOnServer
}

function upload_files_to_server {
  echo ""
  echo "=== STEP 1: uploading neccessary files to the remote server. ==="
  echo "Looks like you are running this script on a client terminal."
  echo "Now your SSH public key and 'qzhub_butler' directory will be copied to the target server."
  read -p "Should I proceed? (y/n): " 

  if [[ $REPLY == "y" ]]; then
    echo ""
    read -e -p "Specify your public SSH key to be uploaded to server: " \
         -i "$HOME/.ssh/id_rsa.pub" 
    cp $REPLY ./artefacts/public_ssh_key
    # ssh root@$serverIP "mkdir ~/qzhub_butler"       \
    #     && scp -r butler.sh                         \
    #               $CONFIG_YAML                      \
    #               $CONFIG_YAML_ANNOTATION           \
    #               README.md                         \
    #               artefacts/                        \
    #               includes/                         \
    #               root@$serverIP:~/qzhub_butler

    rsync -vvr                              \
          --exclude '.git'                        \
          --exclude '.gitignore'                  \
          --exclude 'qzhub_butler.code-workspace' \
          ../qzhub_butler                         \
          root@$serverIP:~/

    rm -f ./artefacts/public_ssh_key
    echo ""
    echo "Now run this scipt on the target server as 'root'. See you soon!"
  else 
    echo "Good bye!"
  fi

  exit 0
}

function configure_remote_user {
  echo ""
  echo "=== STEP 2: remote user configuration. ==="
  readonly local remoteUserName=$(get_var 'conf_remoteUser_name')
  
  if [[ $(getent passwd $remoteUserName) ]]; then # user already exists
    echo "User '$remoteUserName' already exists. Directory 'qzhub_butler' will be moved to his home dir."
  else # user doesn't exist
    echo "A new user '$remoteUserName' will be created."

    local sudoGroup
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
  fi # if [[ $(getent passwd $remoteUserName) ]]

  mkdir -p -m 700 /home/$remoteUserName/.ssh/
  cat ./artefacts/public_ssh_key >> /home/$remoteUserName/.ssh/authorized_keys
  rm ./artefacts/public_ssh_key
  if [[ -d "/home/$remoteUserName/qzhub_butler" ]]; then
    echo "Directory '/home/$remoteUserName/qzhub_butler' already exists. It will be renamed to 'qzhub_butler.*date_time*'" 
    mv /home/$remoteUserName/qzhub_butler{,.$(date +%Y%m%d_%H%M%S)}
  fi
  mv -f ../qzhub_butler /home/$remoteUserName
  chown -R $remoteUserName:$remoteUserName /home/$remoteUserName/.ssh
  chown -R $remoteUserName:$remoteUserName /home/$remoteUserName/qzhub_butler
  chmod 600 /home/$remoteUserName/.ssh/authorized_keys
  cd /home/$remoteUserName/qzhub_butler/artefacts/
  mv -t /home/$remoteUserName/ .bashrc .bash_aliases
  echo "Directory 'qzhub_butler' was moved to /home/$remoteUserName."
  echo "Now reconnect to the server as '$remoteUserName' via SSH and run this script again."
  exit 0  
}