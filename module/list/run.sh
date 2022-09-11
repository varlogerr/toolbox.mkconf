help_intro() {
  echo "List available modules"
}

# halt outer iffe
[[ -n "${TPLDIR}" ]] || return

list_help() {
  help_intro
}

mkconf_trap_help_opt list_help "${@}"

declare -a modules_arr
declare len="$(wc -L <<< "${MODULE_LIST}")"
[[ -n "${MODULE_LIST}" ]] && mapfile -t modules_arr <<< "${MODULE_LIST}"

# unset TPLDIR in order to load only help_intro func
unset TPLDIR
local mod; for mod in "${modules_arr[@]}"; do
  . "${MODDIR}/${mod}/run.sh"

  printf '%-'"$((len + 2))"'s %s\n' "${mod}" "$(help_intro)"
done
