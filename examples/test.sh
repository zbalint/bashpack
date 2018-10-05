#!/bin/bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
declare -r HOME_DIR="${DIR}"
source lib/import.sh

declare -r MAIN_PID=${BASHPID}
declare -r CLIENT_ID=$(printf "%.16s" "$(echo ${MAIN_PID}${RANDOM} | sha1sum)")
PID_STACK="${MAIN_PID}"
declare -r LOG_DIR="${HOME_DIR}/log"
declare -r DB_DIR="${TEMP_DIR}/db"
declare -r PID_DIR="${TEMP_DIR}/pid"
declare -r LOG_POSTFIX="-$(date '+%Y-%m-%d-%H-%M-%S')"

require common/log
require common/try
require process/parallel
require common/error

function callback() {
  sleep 1 && log.debug "Hello from: ${BASHPID}\n"
}

function parallelTest() {
  log.info "Parallel Test Script\n"

  local counter=0
  local maxCount=4
  for (( i = 0; i < 10; i++ )); do
    counter=$((counter+1))
    parallel.fork callback
    if (( ${counter} == ${maxCount} )); then
      counter=0
      parallel.join
    fi
    parallel.harvest
  done
  parallel.join
}

function errorTest() {
  error "asd\n"
}

function init() {
  return 0
}

function main() {
  errorTest
  return 0
}

init $@
main $@
