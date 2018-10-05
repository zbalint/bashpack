#!/bin/bash

function error() {
  local message="$*"
  log.error "$*"
  log.error "Callstack: \n"
  callStack | harvest
  whiptail --title "Error" --msgbox "Message: ${message}\nCallstack:\n$(callStack)" 20 70
  exit 1
}
