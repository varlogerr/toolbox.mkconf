# will be used for log prefix
LOG_TOOLNAME="${TOOLNAME}"
. "${LIBDIR}/lib.sh"

mkconf_trap_help_opt mkconf_help "${@}"

[[ -n "${1:+x}" ]] || trap_fatal $? "Module required"

# after this section we
# * either have a module
# * or catch some mkconf flag and exit
# * or fail
grep -qFx -f <(echo "${MODULE_LIST}") <<< "${1}" \
  || trap_fatal $? "Invalid module: ${1}"

declare MODULE="${1}"
shift

_iife_run() {
  unset _iife_run

  # TPLDIR is only available when running
  # through the current iife
  declare TPLDIR="${MODDIR}/${MODULE}/tpl"
  . "${MODDIR}/${MODULE}/run.sh"
}; _iife_run "${@}"
