#!/bin/bash

require filesystem/store
require filesystem/lock
require ipc/pipe

function queue.create() {
  local queue
  local store

  queue="$(pipe.create)"
  store=$(store.newWithName "${queue}.store")
  
  echo "${queue}"
}

function queue.internalCallback() {
  local queue="$1"
  local callback="$2"
  local data="$3"
  local store="${queue}.store"
  local oldData
  
  oldData=$(store.get "${store}")

  if [[ "${oldData}" != "${data}" ]]; then
    ${callback} "${data}" &&
    lock.release "${queue}" &&
    store.save "${store}" "${data}"
  else
    sleep 0.1 &&
    store.save "${store}" "invalid"
  fi
}

function queue.listen() {
  local queue="$1"
  local callback="$2"
  pipe.listen "${queue}" "queue.internalCallback ${queue} ${callback}"
}

function queue.write() {
  local queue="$1"
  local data="$2"

  if queue.isClosed "${queue}"; then
    return 1
  fi

  lock.wait "${queue}" &&
  pipe.write "${queue}" "${data}" &&
  lock.create "${queue}"
}

function queue.writeAndClose() {
  local queue="$1"
  local data="$2"

  if queue.isClosed "${queue}"; then
    log.error "Queue already closed: ${queue}\n"
    return 1
  fi

  queue.write "${queue}" "${data}" &&
  queue.close "${queue}"
}

function queue.isOpen() {
  local queue="$1"

  if queue.isClosed "${queue}"; then
    return 1
  fi
  return 0
}

function queue.isClosed() {
  local queue="$1"
  
  if file.isExists "${queue}.closed"; then
    return 0
  fi
  return 1
}

function queue.close() {
  local queue="$1"

  if queue.isOpen "${queue}"; then
    touch "${queue}.closed" &&
    lock.wait "${queue}" &&
    pipe.close "${queue}" &&
    lock.create "${queue}" &&
    store.destroy "${queue}.store"
  fi
}
