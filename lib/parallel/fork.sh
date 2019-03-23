#!/bin/bash

require common/common

function fork() {
  local callback="$*"
  wrapper $callback & >> $SERVICE_LOG 2>&1
  FORK_PID=$!
}

function wrapper() {
  local callback="$*"

  if ! contains "$PID_STACK" "$BASHPID"; then
    PID_STACK="${PID_STACK}\\${BASHPID}"
  fi

  $callback
}

function join() {
  local pid="$1"
  wait ${pid}
}

function getCallStack() {
  local callStack=""
  for (( idx=${#FUNCNAME[@]}-2 ; idx>=0 ; idx-- )) ; do
    callStack="${callStack} > ${FUNCNAME[idx]}"
  done
  echo $callStack
}
