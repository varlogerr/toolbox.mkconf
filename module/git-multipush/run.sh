help_intro() {
  echo "Generate template for push to multiple git repos"
}

git_multipush_help() {
  help_intro
  echo
  get_path_force_help_usage
  echo
  get_path_force_help_opts
  echo
  get_path_force_help_demo
}

mkconf_trap_help_opt git_multipush_help "${@}"

declare -A ARGS
trap_path_force_args ARGS "${@}" || exit $?

local -a files
[[ -n "${ARGS[paths]+x}" ]] && mapfile -t files <<< "${ARGS[paths]}"

mkconf_file2dest "${ARGS[force]}" ';' "${TPLDIR}/config.ini" "${files[@]}"
