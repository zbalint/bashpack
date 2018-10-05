#!/bin/bash

require filesystem/file

function lock.create() {
  local file="${1}.lock"
  file.create "${file}"
}

function lock.wait() {
  local file="${1}.lock"
  local timeout=100
  local counter=0
  while [ -f ${file} ]; do
    local counter=$((counter+1))
    sleep 0.1
    if (( "${counter}" == "${timeout}" )); then
      break
    fi
  done
}

function lock.release() {
  local file="${1}.lock"
  rm -rf "${file}"
}
