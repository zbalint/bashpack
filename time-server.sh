#!/bin/bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
# shellcheck disable=SC2034
declare -r HOME_DIR="${DIR}"
# shellcheck disable=SC2034
declare LIB_DIR="${DIR}/lib"
# shellcheck disable=1091
source lib/import.sh

declare -r MAIN_PID=${BASHPID}
# shellcheck disable=SC2034
PID_STACK="${MAIN_PID}"
# shellcheck disable=SC2034
declare -r LOG_DIR="${DIR}/log"
# shellcheck disable=SC2034
# shellcheck disable=SC2155
declare -r LOG_POSTFIX="-$(date '+%Y-%m-%d-%H-%M-%S')"

require common/common
require common/log
require common/try
require common/error
require process/run
require process/parallel
require process/fork
require ipc/pipe
require ipc/queue
require filesystem/store
require filesystem/file

function init() {
  return 0
}

counter=0

function listener() {
  local message="$*"
  counter=$((counter+1))
  log.info "message [${counter}]: ${message}\n"
}

function server() {
  local serverChannel="$1"

  log.info "Connection open.\n"
  queue.listen "${serverChannel}" "listener"
  log.info "Connection closed.\n"
}

function client() {
  local serverChannel="$1"
  
  for (( i=1; i<=10; i++ )); do
    local message="Hello from $BASHPID: ${i}!"
    
    if queue.isOpen "${serverChannel}"; then
      log.debug "Sending message: ${message}\n"
      queue.write "${serverChannel}" "${message}"
    else
      log.error "Delivery failure: Server queue is closed. Message: ${message}\n"
      break
    fi
  done
  
  sleep 0.1
  log.info "Closing connection with server!\n"
  queue.close "${serverChannel}"
}


function main() {
  local serverChannel
  serverChannel="$(queue.create)"

  log.info "Forking server.\n"
  fork server "$serverChannel" && sleep 0.1
  
  log.info "Forking clients.\n"
  fork client "$serverChannel"
  
  join
  return 0
}

init "$@"
main "$@"
