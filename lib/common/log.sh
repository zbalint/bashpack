#!/bin/bash

require common/common

mkdir -p ${LOG_DIR}
SERVICE_LOG="${LOG_DIR}/$(basename "$0")${LOG_POSTFIX}.log"
EXCLUDE_FUNCS="log log.debug log.info log.warn log.error harvest queue.listen pipe.listen queue.internalCallback parallel.wrapper parallel.harvest"

COLOR_RED=$(tput setaf 1)
COLOR_GREEN=$(tput setaf 2)
COLOR_YELLOW=$(tput setaf 3)
COLOR_WHITE=$(tput setaf 7)
COLOR_CYAN=$(tput setaf 6)
COLOR_RESET=$(tput sgr0)

function log() {
  local nanos=$(printf "%.3s" "$(date '+%N')")
  local dateWithTime=$(printf "%s" "$(date '+%Y-%m-%d %H:%M:%S')")
  local timestamp="$(printf "%s.%s\n" "${dateWithTime}" "${nanos}")"
  if [[ ! -z $handler ]]; then
    local paramScript="[$handler]"
    local appLog="${LOG_DIR}/${app}.log"
  fi
  local script=$(basename "$0")
  local PID=$BASHPID

  if [ -z $LOG_COLOR ]; then
    LOG_COLOR=$COLOR_CYAN
  fi

  if [ -z $LOG_LEVEL ]; then
    LOG_LEVEL="DEBUG"
  fi

  if ! contains "$PID_STACK" "$BASHPID"; then
    PID_STACK="${PID_STACK}\\${BASHPID}"
  fi

  if [ $PID -eq $MAIN_PID ]; then
    PID="main"
  fi
  PID="${PID_STACK}"

  local callStack="${script} ($PID) ["
  for (( idx=${#FUNCNAME[@]}-2 ; idx>=0 ; idx-- )) ; do
    if [[ ! $EXCLUDE_FUNCS == *${FUNCNAME[idx]}* ]]; then
      callStack="${callStack}${FUNCNAME[idx]}\\"
    fi
  done
  callStack="${callStack}]"

  local header="[${timestamp}] [$LOG_LEVEL] $callStack ${paramScript}:\> "

  echo -n "${LOG_COLOR}${header}${COLOR_WHITE}"
  local logLine="$*"

  if contains "${logLine}" "\\n" ; then
    printf "%s\n" "${logLine//\\n/}"
  else
    printf "%s" "${logLine}"
  fi

  echo -n "${COLOR_RESET}"

  (
    printf "%s" "$header" >> "$SERVICE_LOG"
    # printf "$*" >> "$SERVICE_LOG"
    if contains "${logLine}" "\\n" ; then
      printf "%s\n" "${logLine//\\n/}" >> "$SERVICE_LOG"
    else
      printf "%s" "${logLine}" >> "$SERVICE_LOG"
    fi
  ) || (
    echo "****************************************************"
    echo "******************** LOG FAILED ********************"
    echo "LOG STRING: $*"
    echo "****************************************************"
    kernel.panic
    exit 1
  )
  if [ ! $? -eq 0 ]; then
    exit 1
  fi

  if [[ ! -z $handler ]]; then
    printf "$*" >> $appLog
  fi
}

function log.nl() {
    printf "\n" >> "$SERVICE_LOG"
}

function log.debug() {
  LOG_COLOR=$COLOR_CYAN
  LOG_LEVEL="DEBUG"
  log "$*"
}

function log.info() {
  LOG_COLOR=$COLOR_WHITE
  LOG_LEVEL="INFO "
  log "$*"
}

function log.warn() {
  LOG_COLOR=$COLOR_YELLOW
  LOG_LEVEL="WARN "
  log "$*"
}

function log.error() {
  LOG_COLOR=$COLOR_RED
  LOG_LEVEL="ERROR"
  log "$*"
}

function result() {
  local res="$1"
  if [ "$res" == "SUCCESSFUL" ]; then
    echo -n "${COLOR_GREEN}"
  fi
  if [ "$res" == "DONE" ]; then
    echo -n "${COLOR_GREEN}"
  fi
  if [ "$res" == "FAILED" ]; then
    echo -n "${COLOR_RED}"
  fi

  echo "[$res]${COLOR_RESET}"
  echo "$res" >> $SERVICE_LOG
}

function state() {
  local res="$1"
  if [ "$res" == "OFFLINE" ]; then
    echo -n "${COLOR_CYAN}"
  fi
  if [ "$res" == "ONLINE" ]; then
    echo -n "${COLOR_GREEN}"
  fi
  if [ "$res" == "CRASHED" ]; then
    echo -n "${COLOR_RED}"
  fi

  echo "[$res]${COLOR_RESET}"
  echo "$res" >> $SERVICE_LOG
}

function harvest() {
  while IFS= read i; do
    log.debug "$i\n"
  done
}
