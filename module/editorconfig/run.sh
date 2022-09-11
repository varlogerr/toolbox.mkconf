help_intro() {
  echo "Generate sample editorconfig"
}

# halt outer iffe
[[ -n "${TPLDIR}" ]] || return

editorconfig_help() {
  help_intro
  echo
  get_path_force_help_usage
  echo
  get_path_force_help_opts
  echo
  get_path_force_help_demo
}

mkconf_trap_help_opt editorconfig_help "${@}"

declare -A ARGS
trap_path_force_args ARGS "${@}" || exit $?

local -a files
[[ -n "${ARGS[paths]+x}" ]] && mapfile -t files <<< "${ARGS[paths]}"

mkconf_file2dest "${ARGS[force]}" '#' "${TPLDIR}/editorconfig" "${files[@]}"
