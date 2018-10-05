#!/bin/bash

function store.newWithName() {
  local store="$1"
  touch "${store}"
  echo "${store}"
}

function store.new() {
  local store="${1}"
  if [ -z "${store}" ]; then
    store=$(mktemp)
  else
    touch "${store}"
  fi
  echo "${store}"
}

function store.save() {
  local store="$1"
  local data="$2"
  echo "${data}" > "${store}"
}

function store.get() {
  local store="$1"
  cat "${store}"
}

function store.destroy() {
  local store="$1"
  rm -f "${store}"
}
