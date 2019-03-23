#!/bin/bash

function pipe.isExists() {
  local pipe="$1"
  if [[ -p ${pipe} ]]; then
    return 1
  fi
  return 0
}

function pipe.create() {
  local pipe
  
  pipe=$(mktemp)
  
  echo "${pipe}"
}

function pipe.close() {
  local pipe="$1"
  echo "close" > "${pipe}"
}

function pipe.listen() {
  local pipe="$1"
  local callback="$2"

  if ! pipe.isExists "${pipe}"; then
    return 1
  fi

  while true
  do
    if read -r line <"${pipe}"; then
      if [[ "${line}" == "close" ]]; then
        break
      fi
      ${callback} "${line}"
    fi
  done
  return 0
}

function pipe.write() {
  local pipe="$1"
  local data="$2"

  if ! pipe.isExists "${pipe}"; then
    return 1
  fi

  echo "${data}" > "${pipe}"
  return 0
}

function pipe.destroy() {
  local pipe="$1"

  if pipe.isExists "${pipe}"; then
    rm -r "${pipe}"
  fi
}
