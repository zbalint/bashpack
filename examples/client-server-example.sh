#!/bin/bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
declare -r HOME_DIR="${DIR}"
declare LIB_DIR="${DIR}/lib"
source lib/import.sh

declare -r MAIN_PID=${BASHPID}
PID_STACK="${MAIN_PID}"
declare -r LOG_DIR="${DIR}/log"
declare -r DB_DIR="${DIR}/db"
declare -r PID_DIR="${DIR}/pid"
declare -r LOG_POSTFIX="-$(date '+%Y-%m-%d-%H-%M-%S')"
declare -r SERVER_QUEUE_STORE="${DB_DIR}/server_queue.store"
declare -r CLIENT_QUEUE_STORE="${DB_DIR}/client_queue.store"

require common/common
require common/log
require common/try
require process/run
require process/parallel
require process/fork
require ipc/pipe
require ipc/queue
require filesystem/store
require filesystem/file

function testFunc() {
  local clientQueueStore="${CLIENT_QUEUE_STORE}"
  local clientQueue="$(store.get ${clientQueueStore})"
  while IFS= read i; do
    queue.write ${clientQueue} "$i"
  done
}

function serverListener() {
  local message="$*"
  if contains "${message}" "="; then
    if contains "${message}" "queue"; then
      local clientQueue="${message#*=*}"
      log.warn "Client queue received: ${clientQueue}\n"
      queue.write ${clientQueue} "Hello from the server: ${BASHPID}"
      # queue.writeAndClose ${clientQueue} "Close by the server: ${BASHPID}"
    fi
    if contains "${message}" "command"; then
      local command="${message#*=*}"
      local clientQueueStore="${CLIENT_QUEUE_STORE}"
      local clientQueue="$(store.get ${clientQueueStore})"
      log.warn "Client command received: ${command}\n"
      ${command} | testFunc
      log.warn "Client command processing finished: ${command}\n"
      queue.writeAndClose ${clientQueue} "Close by the server: ${BASHPID}"
    fi
  else
    log.debug "Message: ${message}\n"
  fi
}

function clientListener() {
  local message="$*"
  log.debug "Message: ${message}\n"
}

function server() {
  local serverQueue="$1"

  log.info "Server started with PID: ${BASHPID} and listening on Queue: ${serverQueue}\n"
  queue.listen ${serverQueue} serverListener
  log.info "Server going to shutdown. PID: ${BASHPID}, Queue: ${serverQueue}\n"
}

function client() {
  local serverQueue="$1"
  local clientQueue="$2"

  log.info "Client started with PID: ${BASHPID} and listening on Queue: ${clientQueue}\n"
  queue.write ${serverQueue} "Hello from the client: ${BASHPID}"
  queue.write ${serverQueue} "queue=${clientQueue}"

  local command="ls"
  log.info "Sending command for exection to the server:${command}\n"
  queue.write ${serverQueue} "command=${command}"
  log.warn "Waiting for command result...\n"
  queue.listen ${clientQueue} clientListener
  log.info "Client going to shutdown. PID: ${BASHPID}, Queue: ${clientQueue}\n"
  queue.writeAndClose ${serverQueue} "Close by the client: ${BASHPID}"
}

function init() {
  log.debug "Starting initialization process of bashpack.\n"
  mkdir -p ${PID_DIR}
  mkdir -p ${DB_DIR}

  log.info "Creating store for main PID... "
  local pidFile="${PID_DIR}/main.pid"
  local mainPidStore="$(store.new ${pidFile})"
  store.save ${mainPidStore} $BASHPID
  result "DONE"

  log.info "Creating queue for server process... "
  local serverQueue=$(queue.create)
  result "DONE"

  log.info "Creating queue for client process... "
  local clientQueue=$(queue.create)
  result "DONE"

  log.info "Creating store for server queue... "
  local serverQueueStoreFile="${SERVER_QUEUE_STORE}"
  local serverQueueStore="$(store.new ${serverQueueStoreFile})"
  store.save ${serverQueueStore} "${serverQueue}"
  result "DONE"

  log.info "Creating store for client queue... "
  local clientQueueStoreFile="${CLIENT_QUEUE_STORE}"
  local clientQueueStore="$(store.new ${clientQueueStoreFile})"
  store.save ${clientQueueStore} "${clientQueue}"
  result "DONE"

  log.debug "Initialization finished.\n"
  return 0
}

function main() {
  log.debug "Starting bashpack main function.\n"
  local pidFile="${PID_DIR}/main.pid"
  local mainPidStore="${pidFile}"
  local serverQueueStore="${SERVER_QUEUE_STORE}"
  local clientQueueStore="${CLIENT_QUEUE_STORE}"

  log.debug "Reading server queue address from store... "
  local serverQueue="$(store.get ${serverQueueStore})"
  result "DONE"

  log.debug "Reading client queue address from store... "
  local clientQueue="$(store.get ${clientQueueStore})"
  result "DONE"

  log.debug "Forking processes...\n"
  fork server ${serverQueue}
  fork client ${serverQueue} ${clientQueue}
  join

  log.debug "Deleting temporary stores... "
  store.destroy ${serverQueueStore}
  store.destroy ${clientQueueStore}
  store.destroy ${mainPidStore}
  result "DONE"

  log.debug "Bashpack main function finished.\n"
  return 0
}

init $@
main $@
