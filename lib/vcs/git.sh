#!/bin/bash

require common/log
require process/run

function git.clone() {
  local group="$1"
  local name="$2"
  local url="git@lnvdevsbx1.erste.hu:${group}/${name}"
  log "Clone URL: ${url}\n"
  run git clone --quiet $url
  local result=$?
  return ${result}
}

function git.add() {
  local files="$*"
  run git add ${files}
}

function git.addAll() {
  run git add .
}

function git.commit() {
  local message="$1"
  run git commit -m "$message"
}

function git.push() {
  run git push
  run git push --tag
}

function git.tag() {
  local version="$1"
  run git tag -a "${version}" -m "${version}"
}

function git.branch.create() {
  local branch="$1"
  run git checkout -b "${branch}"
}

function git.branch.checkout() {
  local branch="$1"
  run git checkout "${branch}"
}

function git.getAuthor() {
  local authorFullString=$(git log -1 | grep Author)
  IFS=' ' read -ra PARTS <<< "$authorFullString"
  echo ${PARTS[1]}
}

function git.status() {
  run git status
}
