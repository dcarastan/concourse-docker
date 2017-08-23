concourse.setup() {
  util.log "Setup Concourse"
  mkdir -p "${db_dir}" "${web_dir}" "${worker_dir}"

  for f in "${web_dir}"/{tsa_host,session_signing}_key "${worker_dir}/worker_key"; do
    if [ -f "${f}" ]; then
      util.log "Using Concourse certificate ${f}"
    else
      util.log "Generate Concourse certificate ${f}"
      ssh-keygen -t rsa -f "${f}" -N ''
    fi
  done
  # Authorize worker keys.
  cp -v "${worker_dir}/worker_key.pub" "${web_dir}/authorized_worker_keys"
  # Pass the TSA key to workers.
  cp -v "${web_dir}/tsa_host_key.pub" "${worker_dir}"
}
