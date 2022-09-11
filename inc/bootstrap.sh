# will be used for log prefix
LOG_TOOLNAME="${TOOLNAME}"
. "${LIBDIR}/lib.sh"

trap_help_opt mkconf_help "${@}" && exit $? || {
  declare rc=$?
  [[ $rc -gt 1 ]] && exit $rc
}

[[ -n "${1:+x}" ]] || trap_fatal --rc $? "Module required"

# after this section we
# * either have a module
# * or catch some mkconf flag and exit
# * or fail
declare MODULE
grep -qFx -f <(echo "${MODULE_LIST}") <<< "${1}" && {
  MODULE="${1}"
  shift
} || {
  trap_mkconf_opts "${@}" && exit $?
  trap_fatal --rc $? "Invalid module: ${1}"
}

declare TPLDIR="${MODDIR}/${MODULE}/tpl"
. "${MODDIR}/${MODULE}/run.sh"
