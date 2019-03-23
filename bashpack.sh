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

require common/common
require common/try
require common/log
require communication/queue
require filesystem/store
require filesystem/file

function runner() {
  local command="$*"

  try "run ${command}" catch ignore
}

function client.listener() {
  local message="$*"
  log.debug "Server message: ${message}\n"
  sleep 0.1
}

function server.listener() {
  local message="$*"
  log.debug "Client message: ${message}\n"
  if contains "${message}" "STATUS"; then
    store.save ${SERVER_STATUS_STORE} "ONLINE"
  fi
  if contains "${message}" "="; then
    if contains "${message}" "connect"; then
      local temp="${message#*=*}"
      local client="${temp%*:*}"
      log.info "Received connect message from client: ${message}\n"
      queue.writeAndClose ${client} "Hello client!"
    fi
    if contains "${message}" "command"; then
      local temp="${message#*=*}"
      local client="${temp%*:*}"
      local command="${temp#*:*}"
      local output="/tmp/${CLIENT_ID}.out"
      file.create ${output}
      runner "${command}" > ${output} 2>&1
      queue.writeAndClose ${client} "${output}"
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
  if isExists ${SERVER_PID_STORE}; then
    local serverPid=$(store.get ${SERVER_PID_STORE})
    if isRunning ${serverPid}; then
      local server="$(store.get ${SERVER_QUEUE_STORE})"
      local client="$(store.get ${CLIENT_QUEUE_STORE})"
      log.info "Sending connect message to server: connect=${client}\n"
      queue.write ${server} "connect=${client}"
      queue.listen ${client} client.listener
    fi
  fi
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
