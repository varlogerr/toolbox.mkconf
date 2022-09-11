pathadd_help() {
  print_decore "
    Generate sample 'add to PATH' file to stdout or DEST files
  "
  echo
  get_path_force_help_usage
  echo
  get_path_force_help_opts
  echo
  get_path_force_help_demo
}

trap_help_opt pathadd_help "${@}" && exit $? || {
  declare rc=$?
  [[ $rc -gt 1 ]] && exit $rc
}

declare -A ARGS
trap_path_force_args ARGS "${@}" || exit $?

local -a files
[[ -n "${ARGS[paths]+x}" ]] && mapfile -t files <<< "${ARGS[paths]}"

mkconf_file2dest "${ARGS[force]}" '#' "${TPLDIR}/pathadd.sh" "${files[@]}"
