#!/bin/bash
#TODO(sm42): add description and credits 

#TODO(sm42): add comprehensive descriptions for each function
function get_var {
  local var="${!1}"
  if [[ ${use_config} == "y" ]]; then        
    echo $var
  else # variable is empty
    read -p "$var: " var
    echo $var
  fi
}