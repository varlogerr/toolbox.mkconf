_iife_source_bash() {
  unset _iife_source_bash
  [[ -n "${BASH_VERSION+x}" ]] || return

  local self="$(realpath -- "${BASH_SOURCE[0]}")"
  local dir="$(dirname "${self}")"

  . "${dir}/bin/mkconfig"
}; _iife_source_bash "${@}"
