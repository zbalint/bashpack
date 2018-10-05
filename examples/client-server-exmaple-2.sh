#!/bin/bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
declare -r HOME_DIR="${DIR}"
declare -r TEMP_DIR="/dev/shm/bashpack"
mkdir -p ${TEMP_DIR}
source lib/import.sh

declare -r MAIN_PID=${BASHPID}
declare -r CLIENT_ID=$(printf "%.16s" "$(echo ${MAIN_PID}${RANDOM} | sha1sum)")
PID_STACK="${MAIN_PID}"
declare -r LOG_DIR="${HOME_DIR}/log"
declare -r DB_DIR="${TEMP_DIR}/db"
declare -r PID_DIR="${TEMP_DIR}/pid"
declare -r LOG_POSTFIX="-$(date '+%Y-%m-%d-%H-%M-%S')"

declare -r SERVER_PID_STORE="${PID_DIR}/server.pid"
declare -r SERVER_USER_STORE="${DB_DIR}/server-user.store"
declare -r SERVER_TIME_STORE="${DB_DIR}/server-time.store"
declare -r SERVER_QUEUE_STORE="${DB_DIR}/server-queue.store"
declare -r SERVER_STATUS_STORE="${DB_DIR}/server-status.store"

declare -r CLIENT_PID_STORE="${PID_DIR}/client-${CLIENT_ID}.pid"
declare -r CLIENT_USER_STORE="${DB_DIR}/client-${CLIENT_ID}-user.store"
declare -r CLIENT_TIME_STORE="${DB_DIR}/client-${CLIENT_ID}-time.store"
declare -r CLIENT_QUEUE_STORE="${DB_DIR}/client-${CLIENT_ID}-queue.store"

import common/common
import common/log
import common/try
import process/run
import process/parallel
import process/fork
import ipc/pipe
import ipc/queue
import filesystem/store
import filesystem/file

function client.listener() {
  local message="$*"
  log.debug "Response: ${message}\n"
  cat ${message}
}

function server.listener() {
  local message="$*"
  log.debug "Message: ${message}\n"
  if contains "${message}" "STATUS"; then
    store.save ${SERVER_STATUS_STORE} "ONLINE"
  fi
  if contains "${message}" "="; then
    if contains "${message}" "connect"; then
      local temp="${message#*=*}"
      local client="${temp%*:*}"
      queue.writeAndClose ${client} "Hello client!"
    fi
  fi
}

function server() {
  local queue="$1"

  log.info "Server started with PID: ${BASHPID} and listening on Queue: ${queue}\n"
  queue.listen ${queue} server.listener
  log.info "Server going to shutdown. PID: ${BASHPID}, Queue: ${queue}\n"
  return 0
}


function start() {
  if isExists ${SERVER_PID_STORE}; then
    local serverPid=$(store.get ${SERVER_PID_STORE})
    if isRunning ${serverPid}; then
      log.info "Server already running!\n"
      return 0
    fi
  fi

  store.save "${SERVER_USER_STORE}" "$(whoami)"
  store.save "${SERVER_TIME_STORE}" "$(date '+%Y-%m-%d %H:%M:%S.%N')"
  store.save "${SERVER_QUEUE_STORE}" "$(queue.create)"
  local logFile="${LOG_DIR}/$(basename "$0")-daemon${LOG_POSTFIX}.log"
  local queue=$(store.get ${SERVER_QUEUE_STORE})
  chmod 666 ${queue}
  log.info "Starting server with queue: ${queue}, status: "

  server ${queue} 0<&- &> "${logFile}" &
  local serverPid=$!
  disown ${serverPid}

  if isRunning ${serverPid}; then
    result "SUCCESSFUL"
  else
    result "FAILED"
    return 1
  fi

  queue.write ${queue} "Hello from the client: ${BASHPID}"

  store.save "${SERVER_PID_STORE}" "${serverPid}"
  return 0
}

function stop() {
  if isExists ${SERVER_PID_STORE}; then
    local queue=$(store.get ${SERVER_QUEUE_STORE})
    log.info "Stopping server with queue: ${queue}, status: "
    queue.writeAndClose ${queue} "Close by the client: ${BASHPID}"
    sleep 0.5
    local serverPid=$(store.get ${SERVER_PID_STORE})
    if isRunning ${serverPid}; then
      result "FAILED"
    else
      result "SUCCESSFUL"
      file.delete "$(store.get ${SERVER_QUEUE_STORE})"
      store.destroy "${SERVER_PID_STORE}"
      store.destroy "${SERVER_USER_STORE}"
      store.destroy "${SERVER_TIME_STORE}"
      store.destroy "${SERVER_QUEUE_STORE}"
    fi
  else
    log.info "The server does not running!\n"
  fi

  return 0
}

function status() {
  log.info "---------------------------------------------------------\n"
  log.info "BashPack status:\n"
  log.info "---------------------------------------------------------\n"
  log.info "BashPack client status: "; state "ONLINE"
  log.info "BashPack client PID: $(store.get ${CLIENT_PID_STORE})\n"
  log.info "BashPack client user: $(store.get ${CLIENT_USER_STORE})\n"
  log.info "BashPack client start time: $(store.get ${CLIENT_TIME_STORE})\n"
  log.info "BashPack client queue: $(store.get ${CLIENT_QUEUE_STORE})\n"
  log.info "---------------------------------------------------------\n"
  if isExists ${SERVER_PID_STORE}; then
    local serverPid=$(store.get ${SERVER_PID_STORE})
    if isRunning ${serverPid}; then
      log.info "BashPack server status: "; state "ONLINE"
      queue.write $(store.get ${SERVER_QUEUE_STORE}) "Hello from the client: ${BASHPID}"
    else
      local queue=$(store.get ${SERVER_QUEUE_STORE})
      queue.write ${queue} "STATUS" && sleep 0.4
      if isExists ${SERVER_STATUS_STORE}; then
        log.info "BashPack server status: "; state "ONLINE"
        queue.write $(store.get ${SERVER_QUEUE_STORE}) "Hello from the client: ${BASHPID}"
      else
        log.info "BashPack server status: "; state "CRASHED"
      fi
      store.destroy ${SERVER_STATUS_STORE}
    fi
    log.info "BashPack server PID: $(store.get ${SERVER_PID_STORE})\n"
    log.info "BashPack server user: $(store.get ${SERVER_USER_STORE})\n"
    log.info "BashPack server start time: $(store.get ${SERVER_TIME_STORE})\n"
    log.info "BashPack server queue: $(store.get ${SERVER_QUEUE_STORE})\n"
  else
    log.info "BashPack server status: "; state "OFFLINE"
  fi
  log.info "---------------------------------------------------------\n"
}

function usage() {
  log.info "Usage: ./$(basename $0) <start | stop | status>\n"
  return 0
}

function init() {
  mkdir -p ${PID_DIR}
  mkdir -p ${DB_DIR}
  store.save "${CLIENT_PID_STORE}" "${MAIN_PID}"
  store.save "${CLIENT_USER_STORE}" "$(whoami)"
  store.save "${CLIENT_TIME_STORE}" "$(date '+%Y-%m-%d %H:%M:%S.%N')"
  store.save "${CLIENT_QUEUE_STORE}" "$(queue.create)"
  return 0
}


function destroy() {
  file.delete "$(store.get ${CLIENT_QUEUE_STORE})"
  store.destroy "${CLIENT_PID_STORE}"
  store.destroy "${CLIENT_USER_STORE}"
  store.destroy "${CLIENT_TIME_STORE}"
  store.destroy "${CLIENT_QUEUE_STORE}"
  return 0
}

function main() {
  local arg="$1"

  case "${arg}" in
    "start" )
      start
      ;;
    "stop" )
      stop
      ;;
    "status" )
      status
      ;;
    * )
      usage
      ;;
  esac

  return 0
}

init $@
main $@
destroy
