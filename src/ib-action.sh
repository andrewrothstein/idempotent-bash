#!/usr/bin/env bash

# Copyright 2016 Metaist LLC
# MIT License

# bash strict mode
set -uo pipefail
IFS=$'\n\t'

# script information
IB_SCRIPT_NAME=${0:-""}
IB_SCRIPT_VERSION="1.0.0"

# terminal colors
if [[ $(command -v tput) ]]; then
  IB_COLOR_RED=$(tput setaf 1)
  IB_COLOR_GREEN=$(tput setaf 2)
  IB_COLOR_NORMAL=$(tput sgr0)
else
  IB_COLOR_RED="\e[31m"
  IB_COLOR_GREEN="\e[32m"
  IB_COLOR_NORMAL="\e[0m"
fi

# path to log file
IB_LOG="/dev/null"

# path to screen out
IB_STDOUT="/dev/stdout"

# last action executed
IB_LAST_ACTION=""

# Did the action cause a change?
IB_CHANGED=false
ib-changed?() { $IB_CHANGED; }

# Evaluate a command and echo "true" or "false" depending on the return code.
# Args:
#   *: command to execute
ib-ok?() {
  eval "$@" > /dev/null && echo "true" || echo "false"
}

# Is this non-empty or truthy?
# Args:
#   1: item (str, boolean)
ib-truthy?() {
  local item=${1:-''}
  [[ "$item" != "" && "$item" != false ]]
}

# Is this empty or falsy?
# Args:
#   1: item (str, boolean)
ib-falsy?() {
  local item=${1:-''}
  [[ "$item" == "" || "$item" == false ]]
}

# Is this command valid?
# Args:
#   1: item (str)
#   2: warning (str)
ib-command?() {
  local item=${1:-''}
  local warning=${2:-"WARNING: $item not installed"}
  if ib-falsy? $(command -v $item); then
    if ib-truthy? $warning; then
      echo "$warning" |& tee -a $IB_LOG
    fi
    return 1
  fi
  return 0
}

# Join an array with a separator.
# Args:
#   1: separator
#   *: array to join
ib-join() {
  local IFS="$1"
  shift
  echo "$*"
}

# Print the start of an action.
# Args:
#   1: label (str)
ib-action-start() {
  local label=${1:-"[action] run"}
  printf "$IB_COLOR_NORMAL[ .. ] ==> $label\r" >> $IB_STDOUT
}

# Print the status of an action.
# Args:
#   1: label (str)
#   2: tried (bool)
#   3: value (int)
ib-action-stop() {
  local label=${1:-"[action] run"}
  local tried=${2:-""}
  local value=${3:-""}

  IB_CHANGED=false
  if [[ "$tried" == false ]]; then # already done
    printf "$IB_COLOR_GREEN[ OK ]$IB_COLOR_NORMAL ==> $label\n" >> $IB_STDOUT
  elif [[ "$tried" == true && "$value" == 0 ]]; then  # changed
    IB_CHANGED=true
    printf "$IB_COLOR_GREEN[DONE] ==> $label$IB_COLOR_NORMAL\n" >> $IB_STDOUT
  else  # failed
    printf "$IB_COLOR_RED[FAIL] ==> $label$IB_COLOR_NORMAL\n" >> $IB_STDOUT
    if [[ "$IB_LOG" != "/dev/null" ]]; then # there is a log file
      printf "\n== LOG OUTPUT ==\n" >> $IB_STDOUT
      cat $IB_LOG >> $IB_STDOUT
    fi
    exit $value
  fi
  return $value
}

# Echo the usage string for the build.
ib-usage() {
  cat << EOF
Usage: $IB_SCRIPT_NAME [args]

Keyword Arguments:
  -h, --help  (show usage and exit)
  --version   (show version and exit)
  -l, --label (str, default command)
  -s, --skip  (boolean, default false)
  -q, --quiet (boolean, default false)
  -e, --      (varags, command to execute)

Note that -e (or --) must preceed the bash command to execute.

Example:
  $IB_SCRIPT_NAME --label "[bash] make a directory" -- mkdir -p foo
EOF
}

# Perform an idempotent action.
# Keyword Arguments:
#   -h, --help  (show usage and exit)
#   --version   (show version and exit)
#   -l, --label (str, default command)
#   -s, --skip  (boolean, default false)
#   -q, --quiet (boolean, default false)
#   -e, --      (varags, command to execute)
#
# Note that `-e` (or `--`) must preceed the bash command to execute.
#
# Example:
#   ib-action --label "[bash] make a directory" -- mkdir -p foo
ib-action() {
  local label=""
  local skip=false
  local quiet=false

  local tried=false
  local value=0

  while [[ "$#" > 0 ]]; do
    case ${1:-""} in
      -h|--help) ib-usage; exit; break;;
      --version)
        echo "$(basename ${IB_SCRIPT_NAME%.*}) v$IB_SCRIPT_VERSION"
        exit 0
        break;;
      -l|--label) label=${2:-""}; shift 2;;
      -s|--skip) skip=${2:-""}; shift 2;;
      -q|--quiet) quiet=true; shift 1;;
      -e|--) shift 1; break;;
      *) echo "Unknown paramter: $1"; ib-usage; exit 1; break;;
    esac
  done

  if [[ "$label" == "" ]]; then label="[bash] $(ib-join ' ' $@)"; fi

  if ib-falsy? "$quiet"; then ib-action-start "$label"; fi
  if ib-falsy? "$skip"; then
    tried=true
    IB_LAST_ACTION="$@"
    echo -e "\n\$ $@" >> $IB_LOG
    eval "$@" &>> $IB_LOG
    value=$?
  fi
  if ib-falsy? "$quiet"; then ib-action-stop "$label" "$tried" "$value"; fi

  return $value
}

# Run an idempotent bash function.
# Args:
#   1: action
#   *: paramters to ib-${action} function
#
# Keyword Args:
#   -l, --label
#   -q, --quiet
ib() {
  local action=${1:-''}
  shift 1;

  local label=""
  local quiet=""

  while [[ "$#" > 0 ]]; do
    case ${1:-""} in
      -l|--label) label=${2:-""}; shift 2;;
      -q|--quiet) quiet="-q"; shift 1;;
      --) shift 1; break;;
      *) break;;
    esac
  done

  ib-$action "$label" "$quiet" $@
}

if [[ "${BASH_SOURCE[0]}" == "${IB_SCRIPT_NAME}" ]]; then
  ib-action $@
  exit
fi
