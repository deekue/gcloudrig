#!/usr/bin/env bash

# exit on error
set -e

set -x

# full path to script dir
DIR="$( cd "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# load globals
# shellcheck source=globals.sh
source "$DIR/globals.sh"
init_setup # init_gcloudrig;

# # create/recreate instance group; uses the startup template by default
gcloudrig_delete_instance_group
gcloudrig_create_instance_group

while read -n 1 -p "Would you like to automatically install some things? [y/n] " ; do
  case $REPLY in
    y|Y)
      echo
      gcloudrig_enable_software_setup
      break
      ;;
    n|N)
      echo
      break
      ;;
  esac
done

echo "Done!  Run './scale-up.sh' to start your instance."
