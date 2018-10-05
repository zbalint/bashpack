#!/bin/bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
declare -r HOME_DIR="${DIR}"
declare LIB_DIR="${DIR}/lib"
source lib/import.sh

declare -r MAIN_PID=${BASHPID}
declare -r RUN_ID=$(printf "%.16s" "$(echo ${MAIN_PID}${RANDOM} | sha1sum)")
PID_STACK="${MAIN_PID}"
declare -r LOG_DIR="${HOME_DIR}/log"
declare -r DB_DIR="${TEMP_DIR}/db"
declare -r PID_DIR="${TEMP_DIR}/pid"
declare -r LOG_POSTFIX="-$(date '+%Y-%m-%d-%H-%M-%S')"

require common/common
require common/log
require process/run

function compile() {
  local script="$1"

  tar -czvf "${script}.tgz" "${script}.tmp" && 
  rm "${script}.tmp" &&
  cat "${script}.tgz" | base64 -w0 > "${script}.b64" && 
  rm "${script}.tgz"

  echo "#!/bin/bash" > "${script/.sh/.csh}"
  echo "echo \"$(cat ${script}.b64)\" | base64 -d > ${script}-temp.tgz && tar -xvf ${script}-temp.tgz --to-stdout | bash -s -- \$@; rm ${script}-temp.tgz" >> "${script/.sh/.csh}"
  rm "${script}.b64"
}

function progress() {
  local counter=0
  while IFS= read -r i; do
    counter=$((counter+4))
    echo "$counter"
  done | whiptail --gauge "Progress" 8 70 0
}

function compress() {
  local libDir="$1"
  local currentDir

  currentDir="$(pwd)"

  cd "${libDir}" && cd ..
  run tar -czvf lib.tgz lib/ #| progress
  cd "${currentDir}" || exit 1
}

function transform() {
  local compressedLibFile="$1"
  run "cat ${compressedLibFile} | base64 -w 0 > lib.b64 && rm lib.tgz"
}

function generate() {
  local transformedLibFile="$1"
  local script="$2"

  local data="
scriptSha=\$(echo \$(basename \$0) | sha1sum)
scriptId=\${scriptSha:0:8}
tempLibDir=/dev/shm/lib/\${scriptId}
compressedLibFile=\${tempLibDir}/lib.tgz
mkdir -p \${tempLibDir} &&
echo \"$(cat ${transformedLibFile})\" | base64 -d > \${compressedLibFile} &&
cd \${tempLibDir} &&
tar -xvf \${compressedLibFile} > /dev/null &&
cd - > /dev/null &&
unset scriptSha; unset scriptId; unset compressedLibFile
declare -r LIB_DIR=\${tempLibDir}/lib
source \${tempLibDir}/lib/import.sh
  "

  while IFS='' read -r line || [[ -n "${line}" ]]; do
    if [[ ${line} == "source lib/import.sh" ]]; then
      printf "%s\n" "${data}" >> ${script}.tmp
    else
      printf "%s\n" "${line}" >> ${script}.tmp
    fi
  done < "${script}"
  rm lib.b64
}

function init() {
  local script="$1"

  if isEmpty "${script}"; then
    log.error "Missing parameter: script name\n"
    exit 1
  fi

  if ! isExists "${script}"; then
    log.error "Script does not exists: ${script}\n"
    exit 1
  fi


  return 0
}

function main() {
  local script="$1"
  local libDir="${DIR}/lib"

  compress "${libDir}"
  transform "lib.tgz"
  generate "lib.b64" "${script}"
  compile "${script}"

  return 0
}

init $@
main $@
