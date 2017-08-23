util.get_concourse_api_version() {
  # Returns the running concourse version.
  # $1 Concourse server URL.
  local _url=$1
  (
    curl -sSL --max-time 10 "${_url}/api/v1/info" | jq .version
  ) 2>/dev/null
}

util.log() {
  echo "$(date '+%Y-%m-%d %T %Z') $*";
}

util.log_error() {
  util.log "ERROR: $*" >&2;
}

util.mkpasswd() {
  # Generate a random password.
  # $1 Password length, capped at 45 characters [default: 12]
  local _length=${1:-12}
  _password=$(openssl rand -base64 32)
  echo "${_password:0:_length}"
}

util.run_preview() {
  # Previews a command before runing it.
  # $1    Preamble message
  # $2-$# Command and arguments.
  local _msg=$1
  shift
  util.log "${_msg} $*"
  "$@"
}
