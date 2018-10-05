#!/bin/bash

function setTrap() {
  local signal="$1"
  local callback="$2"
  trap "${callback}" $signal
}

function registerSignalHandler() {
  local signal="$1"
  local callback="$2"
  log.debug "Registering handler '${callback}' for signal: ${signal}... "
  setTrap "${signal}" "${callback}"
  result "DONE"
}

function registerHandler() {
  local signal="$1"
  local callback="$2"
  registerSignalHandler "${signal}" "${callback}"
}

function kernel.panic() {
  echo "***************************************************************************************"
  echo "******************** Critical error occurred during the execution! ********************"
  echo "***************************************************************************************"
  exit 1
}
