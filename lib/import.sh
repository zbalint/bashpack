#!/bin/bash

function import() {
  local file="$1"

  if [ -f "${LIB_DIR}/${file}.sh" ]; then
    source "${LIB_DIR}/${file}.sh"
  else
    printf "%s\n" "Could not import lib: ${file}"
    exit 1
  fi
}

function require() {
  local lib="$1"

  if [ -f "${LIB_DIR}/${lib}.sh" ]; then
    local libsha
    local requireId
    local varName

    libsha="$(echo ${lib} | sha1sum)"
    requireId=${libsha:0:8}
    varName="$(echo REQUIRE_LIB_${requireId})"

    if [ -z ${!varName+x} ]; then
      source "${LIB_DIR}/${lib}.sh"
      eval "REQUIRE_LIB_${requireId}"=0
    else
      return 0
    fi
  else
    printf "%s\n" "Require: The \"${lib}\" library does not exists!"
    exit 1
  fi
}
