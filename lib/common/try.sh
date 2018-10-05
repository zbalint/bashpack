#!/bin/bash

function callStack() {
  local frame=1
  while caller $frame; do
    ((frame++));
  done
}

function data.store() {
  local name="$1"
  local val="$2"
  echo $val > $name
}

function data.retrieve() {
  local name="$1"
  if [ -f $name ]; then
    cat $name
    return 0
  fi
  echo "0"
  return 0
}

function data.clear() {
  local name="$1"
  rm -f $name
}

function try() {
  local tryCallback="$1"
  local catchCallback="$2"
  local afterCallback="$3"
  local exitCode=0

  local id="${RANDOM}"

  (
    $tryCallback
  ) || (
    exitCode=${PIPESTATUS[0]}
    log.error "An error detected in callback '$tryCallback'. Callstack: \n"
    callStack | harvest
    data.store "exitCode${id}" $exitCode
    $catchCallback $exitCode $tryCallback
  )
  exitCode=$(data.retrieve "exitCode${id}")
  data.clear "exitCode${id}"
  if [ ! -z $afterCallback ]; then
    $afterCallback $exitCode $tryCallback
  fi

  return ${exitCode}
}

function catch() {
  local exitCode="$1"
  local callback="$2"
  if [ $exitCode -eq 0 ]; then
    log.debug "The callback '$callback' finished with exit code: ${exitCode}\n"
  else
    log.warn "The callback '$callback' finished with exit code: ${exitCode}\n"
  fi
}

function panic() {
  local exitCode="$1"
  local callback="$2"
  if [ ! $exitCode -eq 0 ]; then
    log.error "An unrecoverable error occured with exit code: $exitCode\n"
    exit $exitCode
  fi
}

function ignore() {
  local exitCode="$1"
  local callback="$2"
  return 0
}
