#!/bin/bash

require common/common
require common/try
require common/log

function gradle.wrapper() {
  local command="$*"
  (
    run $command &
    wait $!
    echo $? > gradle.wrapper.out
  )

  if isExists gradle.wrapper.out; then
    local result=$(cat gradle.wrapper.out)
    rm gradle.wrapper.out
    return ${result}
  fi

  return 1
}

function gradle.command() {
  local command="$*"
  gradle.wrapper gradle $*
}

function gradle.build() {
  gradle.wrapper gradle --no-daemon --console plain --stacktrace --refresh-dependencies build
}

function gradle.migrate() {
  ##schema update + grants
  try "gradle.wrapper gradle --no-daemon --console plain migrateLiquibaseGroovy -PlogLevel=INFO updateSQL" gradle.catch gradle.finish
  try "gradle.wrapper gradle --no-daemon --console plain createUpdateSQLFile -PlogLevel=INFO" gradle.catch gradle.finish

  ##schema rollback
  try "gradle.wrapper gradle --no-daemon --console plain migrateLiquibaseGroovy -PlogLevel=INFO futureRollbackSQL" gradle.catch gradle.finish
  try "gradle.wrapper gradle --no-daemon --console plain createRollbackSQLFile -PlogLevel=INFO" gradle.catch gradle.finish

  ##proxy schema update + grants
  try "gradle.wrapper gradle --no-daemon --console plain migrateProxyDatabase migrateLiquibaseGroovy -PlogLevel=INFO updateSQL" gradle.catch gradle.finish
  try "gradle.wrapper gradle --no-daemon --console plain migrateProxyDatabase createUpdateSQLFile -PlogLevel=INFO" gradle.catch gradle.finish

  ##proxy schema rollback
  try "gradle.wrapper gradle --no-daemon --console plain migrateProxyDatabase migrateLiquibaseGroovy -PlogLevel=INFO futureRollbackSQL" gradle.catch gradle.finish
  try "gradle.wrapper gradle --no-daemon --console plain task migrateProxyDatabase createRollbackSQLFile -PlogLevel=INFO" gradle.catch gradle.finish
}

function gradle.catch() {
  local exitCode="$1"
  local command="$2"
  log.warn "Gradle task '${command}' failed with code: ${exitCode}\n"
  return ${exitCode}
}

function gradle.finish() {
  local exitCode="$1"
  local command="$2"

  if [ $exitCode -eq 0 ]; then
    log.debug "Build successful "
    result "SUCCESSFUL"
  else
    log.debug "Build failed "
    result "FAILED"
  fi

  return 0
}
