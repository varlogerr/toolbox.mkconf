# Add relative to the current file directory `bin` directory to
# the PATH, ensured the path is added only once. Just source the
# current file in `~/.bashrc` and you're done:
# ```sh
# echo 'source "<PATH_TO_CURRENT_FILE>"' >> ~/.bashrc
# ```
#
# Supported options:
# --prepend   Put `bin` directory in the beginning of PATH the end
#
# Demo:
# ```sh
# echo 'source "<PATH_TO_CURRENT_FILE>" --prepend' >> ~/.bashrc
# ```
#
# Modify BINDIR variable if required
_iife_pathadd() {
  unset _iife_pathadd

  # do nothing if not in bash or not sourced
  [[ -n "${BASH_SOURCE[0]+x}" ]] || return 1
  # https://stackoverflow.com/a/2684300
  [[ "${0}" == "${BASH_SOURCE[0]}" ]] && return 1

  local self="$(realpath -- "${BASH_SOURCE[0]}")"
  local BINDIR="$(dirname -- "${self}")/bin"

  [[ ":${PATH}:" == *":${BINDIR}:"* ]] && return 0

  # collect arguments
  local PREPEND=false
  while :; do
    [[ -n "${1+x}" ]] || break

    case "${1}" in
      --prepend ) PREPEND=true ;;
      *         ) echo "[pathadd:warn] Invalid source argument: ${1}" >&2 ;;
    esac

    shift
  done

  ${PREPEND} && PATH="${BINDIR}${PATH:+:${PATH}}" || PATH+="${PATH:+:}${BINDIR}"

  return 0
} && _iife_pathadd "${@}"
