#!/bin/bash

require filesystem/store

function task.new() {
  local name="$1"
  local callback=${@:2}
  local store=$(store.new "${name}")
  store.save "${store}" "${callback}"
  echo ${store}
}

function task.callback() {
  local name="$1"
  store.get "${name}"
}

function task.run() {
  local name="$1"
  local callback=$(task.callback ${name})
  ${callback}
  local exitValue="$?"
  task.clear ${name}
  return ${exitValue}
}

function task.clear() {
  local name="$1"
  store.destroy ${name}
}
