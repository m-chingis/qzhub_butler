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
  echo "Looks like you are running this script on a client terminal."
  echo "Directory 'qzhub_butler' will be copied to the target server."
  read -p "Should I proceed? (y/n): " 

  if [[ $REPLY == "y" ]]; then

    if [[ $useYamlConfig != "y" ]]; then # if YAML config is used then SSH keys already in there      
      echo ""
      read -e -p "Specify your public SSH key to be uploaded to server: " \
          -i "$HOME/.ssh/id_rsa.pub" 
      cp $REPLY ./artefacts/public_ssh_key
    fi
   
    # ssh root@$serverIP "mkdir ~/qzhub_butler"       \
    #     && scp -r butler.sh                         \
    #               $CONFIG_YAML                      \
    #               $CONFIG_YAML_ANNOTATION           \
    #               README.md                         \
    #               artefacts/                        \
    #               includes/                         \
    #               root@$serverIP:~/qzhub_butler

    local oldPort=$(get_var 'conf_server_oldPort')

    rsync -vvr                                    \
          -e "ssh -p $oldPort"                    \
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

function create_server_users {
  if [[ $useYamlConfig != "y" ]]; then        
    echo "You chose not to use YAML config. Skipping the step."
    return 0
  fi

  local counter=0
  for f in $conf_users_ ; do 
    ((++counter))
    eval local login=\$${f}_login
    eval local sshPubKey=\$${f}_sshPubKey
    eval local groups=\$${f}_groups

    if [[ $(getent passwd $login) ]]; then # user already exists
      echo "$counter: User '$login' already exists. Skipping."
      continue
    fi

    echo "$counter: Creating user '$login', group membership in '$groups'"
    useradd -s /bin/bash -G $groups -m $login

    local pass=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c10)
    echo "Your current password is: $pass" >> /home/$login/README # TODO(sm42): maybe worth adding encryption here.

    chpasswd <<< "$login:$pass"
    # passwd -e $login <-- decided to enable this when I figure out how to send password to users

    mkdir -p -m 700 /home/$login/.ssh/
    echo $sshPubKey >> /home/$login/.ssh/authorized_keys
    chmod 600 /home/$login/.ssh/authorized_keys

    cp -t /home/$login/ ./artefacts/.bash_aliases
    chown -R $login:$login /home/$login
  done
}

function configure_my_user {
  
  if [[ ! $(getent passwd $myUserLogin) ]]; then # user doesn't exists
    echo "A new user '$myUserLogin' will be created."

    local sudoGroup
    if [[ $(cat /proc/version | grep 'Ubuntu') ]]; then
      sudoGroup='sudo'
    elif [[ $(cat /proc/version | grep 'Red Hat') ]]; then
      sudoGroup='wheel'
    else
      read -p "Alas! I was unable to detect your OS family. Please indicate sudo-users group name (e.g.: wheel, sudo): " sudoGroup
    fi
    useradd -s /bin/bash -G $sudoGroup -m $myUserLogin
    
    echo "User '$myUserLogin' was created with 'sudo' rights."
    passwd $myUserLogin
  fi # if [[ ! $(getent passwd $myUserLogin) ]]

  if [[ $useYamlConfig != "y" ]]; then # if YAML config is used then SSH keys already in there, otherwise let's take it from file below
    cp -t /home/$myUserLogin/ ./artefacts/.bash_aliases
    mkdir -p -m 700 /home/$myUserLogin/.ssh/
    cat ./artefacts/public_ssh_key >> /home/$myUserLogin/.ssh/authorized_keys
    rm ./artefacts/public_ssh_key
    chown -R $myUserLogin:$myUserLogin /home/$myUserLogin/.ssh
    chmod 600 /home/$myUserLogin/.ssh/authorized_keys
  fi

  echo "Moving 'qzhub_butler' directory to /home/$myUserLogin/"
  
  if [[ -d "/home/$myUserLogin/qzhub_butler" ]]; then
    echo "Directory '/home/$myUserLogin/qzhub_butler' already exists. It will be renamed to 'qzhub_butler.*date_time*'" 
    mv /home/$myUserLogin/qzhub_butler{,.$(date +%Y%m%d_%H%M%S)}
  fi
  mv -f ../qzhub_butler /home/$myUserLogin
  chown -R $myUserLogin:$myUserLogin /home/$myUserLogin/qzhub_butler

  echo "Directory 'qzhub_butler' was moved to /home/$myUserLogin."
}

function sshd_security_hardening {
  local currentDate=$(date +%Y%m%d_%H%M%S)
  cp /etc/ssh/sshd_config{,.bak.currentDate}
  echo "Backup file: /etc/ssh/sshd_config.bak.$currentDate"

  local server_newPort=$(get_var 'conf_server_newPort')
  sed -i /etc/ssh/sshd_config \
      -re 's/^(\#?)([[:space:]]*)(Port)([[:space:]]+)(.*)/\3 '"$server_newPort"' #Old string: \1\2\3\4\5/' \
      -re 's/^(\#?)([[:space:]]*)(PermitRootLogin)([[:space:]]+)(.*)/\3 no #Old string: \1\2\3\4\5/' \
      -re 's/^(\#?)([[:space:]]*)(PasswordAuthentication)([[:space:]]+)(.*)/\3 no #Old string: \1\2\3\4\5/' 
  
  echo "New settings to /etc/ssh/sshd_config were applied."

  systemctl reload sshd
}