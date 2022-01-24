#!/bin/bash
#
# This script is an entry point for a new server \ cluster set up. 
# Depending on choices you make it will include other helper scripts. 
# You may choose Interactive mode or Full Automatic (based on YAML configs).
#
# Restrictions: 
#   - 
# 

set -u          # fail if referencing a variable which is not 
set -e          # immediately exit script if command fails
set -o pipefail # fail if any of the commands in the pipeline failed
#set -x


if [[ $(pwd) != *"/qzhub_butler" ]]; then
  echo "Please run this script from '.../qzhub_butler' directory!"
  exit 1
fi

readonly CONFIG_YAML="butler_config.yaml"
readonly CONFIG_YAML_ANNOTATION="butler_config_annotation.yaml"

# Includes
. ./includes/parse_yaml.sh
. ./includes/helpers.sh
. ./includes/servants.sh

main() {
  local useYamlConfig='n'
  choose_execution_mode # Interactive vs. YAML mode
  
  local serverIP
  local runningOnServer=1 # 0 - true, 1... - false
  detect_exec_on_server # Is the script running on the target server?
  
  if [[ $runningOnServer == 1 ]]; then # script is started on a client 
    upload_files_to_server
  fi

  if [[ $(whoami) == "root" ]]; then
    configure_remote_user
  fi

  #TODO: hardening server security. Don't forget to add config option for non root user to upload files and do config.

  #TODO: kvm installation

}

# Workflow entry point
main "$@"

# Choose type of server k8s | db | hadoop | etc.
# # Based on choice utilize appropriate include script
# Provide ouput message and cleanup


# TODO(sm42): Log every step to an audit file


