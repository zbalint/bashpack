#!/bin/bash

function equals() {
  local left="$1"
  local right="$2"

  if [ "$left" == "$right" ]; then
    return 0
  fi

  return 1
}

function contains() {
  local left="$1"
  local right="$2"

  if [[ "$left" == *"$right"* ]]; then
    return 0
  fi

  return 1
}

function isRunning() {
  local pid="$1"
  if kill -0 $pid > /dev/null 2>&1; then
    return 0
  fi
  return 1
}

function isDirectory() {
  local file="$1"

  if [ -d ${file} ]; then
    return 0
  fi
  return 1
}

function isExists() {
  local file="$1"

  if [ -f ${file} ]; then
    return 0
  fi
  return 1
}

function isEmpty() {
  local var="$1"
  if [ -z $var ]; then
    return 0
  fi
  return 1
}

function percentage() {
  local left="$1"
  local right="$2"
  awk -v var1=$left -v var2=$right 'BEGIN { print  ( var1 / var2 * 100 ) }'
}

function toUppercase() {
  local string="$*"
  echo $string | awk '{print toupper($0)}'
}

function trimPreAndSuffix() {
  local string="$1"
  local prefix="$2"
  local suffix="$3"
  local tmp="${string#*${prefix}*}"
  local tmp="${tmp%*${suffix}*}"
  echo ${tmp}
}
