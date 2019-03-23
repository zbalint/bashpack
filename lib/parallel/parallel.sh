#!/bin/bash

require common/log

PARALLEL_TEMP_DIR="$(mktemp -d)"
trap parallel.__cleanUp EXIT

function parallel.__cleanUp() {
    parallel.wait
    rm -rf ${PARALLEL_TEMP_DIR}
}

function parallel.wrapper() {
    local callback="$1"
    local output="$2"
    (${callback} > ${output} 2>&1)
    local exitCode=$?
    echo ${exitCode} > ${output}.exitCode
    mv ${output} ${output}.finished
    return ${exitCode}
}

function parallel.fork() {
    local callback="$*"
    local generatedId=$(echo ${callback}${RANDOM}${RANDOM}${RANDOM} | sha1sum)
    local forkId=${generatedId:0:8}
    local output="${PARALLEL_TEMP_DIR}/${forkId}.parallel.out"
    log.debug "Running parallel task '${callback}' with id '${forkId}'.\n"
    parallel.wrapper "${callback}" "${output}" &
}

function parallel.harvest() {
    local harvestId=${RANDOM}
    local finishedProcessOutputsFile="${PARALLEL_TEMP_DIR}/finished-${harvestId}.txt"
    local finishedProcessExitCodeFile="${PARALLEL_TEMP_DIR}/exitCode-${harvestId}.txt"
    ls ${PARALLEL_TEMP_DIR}/*.finished > /dev/null 2>&1
    if (( $? == 0 ));  then
        ls ${PARALLEL_TEMP_DIR}/*.exitCode > ${finishedProcessExitCodeFile}
        ls ${PARALLEL_TEMP_DIR}/*.finished > ${finishedProcessOutputsFile}
        while read -r outputFile; do
            local forkId="$(trimPreAndSuffix ${outputFile} ${PARALLEL_TEMP_DIR}/ .parallel)"
            local exitCodeFile="${outputFile%*.finished*}.exitCode"
            local exitCode=$(cat ${exitCodeFile})
            log.debug "Parallel porcess finished. Id: '${forkId}', Exit code: ${exitCode}\n"
            cat ${outputFile}
            if (( ${exitCode} != 0 )); then
                return ${exitCode}
            fi
        done < ${finishedProcessOutputsFile}
        rm $(cat ${finishedProcessOutputsFile})
        rm $(cat ${finishedProcessExitCodeFile})
        rm ${finishedProcessOutputsFile}
    fi
}

function parallel.wait() {
    wait
}

function parallel.join() {
    parallel.wait
    parallel.harvest
    rm ${PARALLEL_TEMP_DIR}/*.parallel.out* > /dev/null 2>&1
}
