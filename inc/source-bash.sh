_iife_pathadd() {
  unset _iife_pathadd

  # override BINDIR value for the current context in
  # order to handle symlinked tool
  local BINDIR
  BINDIR="$(dirname -- "${1}")"
  shift

  # do nothing if not in bash or not sourced
  [[ -n "${BASH_SOURCE[0]+x}" ]] || return 1
  [[ "${0}" == "${BASH_SOURCE[-1]}" ]] && return 1

  [[ ":${PATH}:" == *":${BINDIR}:"* ]] && return 0

  # collect arguments
  local PREPEND=false
  while :; do
    [[ -n "${1+x}" ]] || break

    case "${1}" in
      --prepend ) PREPEND=true ;;
      *         ) echo "[mkconf:source:warn] Invalid source argument: ${1}" >&2 ;;
    esac

    shift
  done

  ${PREPEND} && PATH="${BINDIR}${PATH:+:${PATH}}" || PATH+="${PATH:+:}${BINDIR}"

  return 0
} && _iife_pathadd "${@}" \
&& _iife_completion() {
  unset _iife_completion

  # add completion
  . "${LIBDIR}/complete.sh"
  complete -o default -F _mkconfig_complete "$(basename -- "${1}")" 2>/dev/null

  return 0
} && _iife_completion "${@}"
