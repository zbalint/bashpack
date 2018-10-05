#!/bin/bash

function replace() {
  local source="$1"
  local destination="$2"
  local template="$3"
  local output="$4"
  local temp="$5"

  echo "$*"

  cp ${template} ${temp} || return $?
  sed -i -e "s/${source}/${destination}/g" ${temp} && \
  cat ${temp} >> ${output}
  rm ${temp} || return $?
  return 0
}

function replaceTemplate() {
  local string="$1"
  local template="$2"
  local inFile="$3"
  local outFile="$4"

  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == *"$string"* ]]; then
      cat $inFile >> $outFile
    else
      echo "$line" >> $outFile
    fi
  done < "$template"
}
