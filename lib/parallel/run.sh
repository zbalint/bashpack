#!/bin/bash

function run() {
  local command="$*"

  log.debug "Running command: ${command}\n"
  local __startTime="${SECONDS}"
  eval "${command}" 2>&1 | tee | harvest
  local result=${PIPESTATUS[0]}
  local __duration=$(( SECONDS - __startTime ))
  log.debug "Command finished in ${__duration}s with exit code: ${result} and status: "

  if [ ${result} -eq 0 ]; then
    result "SUCCESSFUL"
  else
    result "FAILED"
  fi

  if [ ! ${result} -eq 0 ]; then
    log.error "Command exited with non-zero exit code. Code: ${result}\n"
    exit ${result}
  fi

  return ${result}
}

function executionTime() {
  local command="$*"

  log.debug "Measuring execution time of command: ${command}\n"
  local __startTime="${SECONDS}"
  ${command}
  local result=$?
  local __duration=$(( SECONDS - __startTime ))
  log.debug "Command finished in ${__duration}s with exit code: ${result} and status: "

  if [ ${result} -eq 0 ]; then
    result "SUCCESSFUL"
  else
    result "FAILED"
  fi

  if [ ! ${result} -eq 0 ]; then
    log.error "Command exited with non-zero exit code. Code: ${result}\n"
    exit ${result}
  fi

  return ${result}
}
