#!/bin/bash

function file.isEmpty() {
  local file="$1"
  stat "${file}" 2>&1 | grep "empty" 2>&1 > /dev/null
  return $?
}

function file.isExists() {
  local file="$1"
  if [ -f "${file}" ]; then
    return 0
  fi
  return 1
}

function file.create() {
  local filename="$1"
  touch ${filename}
}

function file.delete() {
  local filename="$1"
  rm ${filename}
}

function file.delete.forced() {
  local filename="$1"
  rm -f ${filename}
}

function file.write() {
  local file="$1"
  set -- "${@:2}"
  local data=("$*")
  echo ${data} > ${file}
}

function file.append() {
  local file="$1"
  set -- "${@:2}"
  local data=("$*")
  echo ${data} >> ${file}
}

function file.read() {
  local file="$1"
  cat ${file}
}
