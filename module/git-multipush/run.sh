git_multipush_help() {
  print_decore "
    Generate template for push to multiple git repos
  "
  echo
  get_path_force_help_usage
  echo
  get_path_force_help_opts
  echo
  get_path_force_help_demo
}

trap_help_opt git_multipush_help "${@}" && exit $? || {
  declare rc=$?
  [[ $rc -gt 1 ]] && exit $rc
}

declare -A ARGS
trap_path_force_args ARGS "${@}" || exit $?

local -a files
[[ -n "${ARGS[paths]+x}" ]] && mapfile -t files <<< "${ARGS[paths]}"

mkconf_file2dest "${ARGS[force]}" ';' "${TPLDIR}/config.ini" "${files[@]}"
