bash_lib_help() {
  print_decore "
    Generate basic bash library to stdout or DEST files
   .
    USAGE
    =====
    ${TOOLNAME} ${MODULE} [-f] [--prefix PREFIX] [--] [DEST...]
   .
    OPTIONS
    =======
    --            End of options
    -f, --force   Override existing files. Requires DEST
    --prefix      Override default 'shlib_' prefix
  "
  echo
  get_path_force_help_demo
}

trap_bash_lib_args() {
  local -n _args="${1}"
  shift

  _args+=(
    [force]=false
  )

  local _endopts=false
  local _key
  local -a _inval
  local -a _errbag
  while :; do
    [[ -n "${1+x}" ]] || break
    ${_endopts} && _key='*' || _key="${1}"

    case "${_key}" in
      --          ) _endopts=true ;;
      -f|--force  ) _args[force]=true ;;
      --prefix    ) shift; _args[prefix]="${1}" ;;
      -*          ) _inval+=("${1}") ;;
      *           )
        if [[ -n "${1}" ]]; then
          _args[paths]+="${_args[paths]+$'\n'}${1}"
        else
          [[ ${#_errbag[@]} -lt 1 ]] && _errbag+=("DEST requires a non-blank value")
        fi
        ;;
    esac

    shift
  done

  [[ ${#_inval[@]} -gt 0 ]] && {
    _errbag+=(
      "Invalid or incompatible arguments:"
      "$(printf -- '* %s\n' "${_inval[@]}")"
    )
  }

  ${_args[force]} && [[ -z "${_args[paths]+x}" ]] \
    && _errbag+=("FORCE flag requires DEST")

  [[ ${#_errbag[@]} -lt 1 ]] || {
    log_err "${_errbag[@]}"
    return 1
  }

  return 0
}

trap_help_opt bash_lib_help "${@}" && exit $? || {
  declare rc=$?
  [[ $rc -gt 1 ]] && exit $rc
}

declare -A ARGS
trap_bash_lib_args ARGS "${@}" || exit $?

local -a files
[[ -n "${ARGS[paths]+x}" ]] && mapfile -t files <<< "${ARGS[paths]}"

content="$(cat "${TPLDIR}/lib.sh")"
[[ -n "${ARGS[prefix]+x}" ]] && {
  prefix="${ARGS[prefix]}"
  prefix_lc="$(sed_quote_replace "${prefix,,}")"
  prefix_uc="$(sed_quote_replace "${prefix^^}")"
  content="$(
    sed -e 's/shlib_/'"${prefix_lc}"'/g' \
        -e 's/SHLIB_/'"${prefix_uc}"'/g' \
    <<< "${content}"
  )"
}

mkconf_file2dest "${ARGS[force]}" '#' <(cat <<< "${content}") "${files[@]}"
