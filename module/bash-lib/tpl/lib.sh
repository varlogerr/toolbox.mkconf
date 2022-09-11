##### {CONF}
#####
#
# Tool name to be used in log prefix.
# Leave blank to use only log type for prefix
SHLIB_LOG_TOOLNAME="${SHLIB_LOG_TOOLNAME:-}"
#
# This three are used for logging (see logs functions description)
# Available values:
# * none    - don't log
# * major   - log only major
# * minor   - log everything
# If not defined or values misspelled, defaults to 'major'
SHLIB_LOG_INFO_LEVEL="${SHLIB_LOG_INFO_LEVEL-major}"
SHLIB_LOG_WARN_LEVEL="${SHLIB_LOG_WARN_LEVEL-major}"
SHLIB_LOG_ERR_LEVEL="${SHLIB_LOG_ERR_LEVEL-major}"
#
# Profiler
SHLIB_PROFILER_ENABLED="${SHLIB_PROFILER_ENABLED-false}"
#
#####
##### {/CONF}

# FUNCTIONS:
# * shlib_file2dest [-f] [--tag TAG] [--tag-prefix TAG_PREFIX] [--] SOURCE [DEST...]
# * shlib_print_stderr MSG...               (stdin MSG is supported)
# * shlib_print_stdout MSG...               (stdin MSG is supported)
# * shlib_log_* [-t LEVEL_TAG] [--] MSG...  (stdin MSG is supported)
# * shlib_text_ltrim TEXT...    (stdin TEXT is supported)
# * shlib_text_rtrim TEXT...    (stdin TEXT is supported)
# * shlib_text_trim TEXT...     (stdin TEXT is supported)
# * shlib_text_rmblank TEXT...  (stdin TEXT is supported)
# * shlib_text_clean TEXT...    (stdin TEXT is supported)
# * shlib_text_decore TEXT...   (stdin TEXT is supported)
# * shlib_trap_help_opt ARG...
# * shlib_trap_fatal [--decore] [--] RC [MSG...]
# * shlib_tag_node_set [--prefix PREFIX] [--suffix SUFFIX] [--] TAG CONTENT TEXT...
#   (stdin TEXT is supported)
# * shlib_tag_node_get [--prefix PREFIX] [--suffix SUFFIX] [--strip] [--] TAG TEXT...
#   (stdin TEXT is supported)
# * shlib_tag_node_rm [--prefix PREFIX] [--suffix SUFFIX] [--] TAG TEXT...
#   (stdin TEXT is supported)
# * shlib_rc_add INIT_RC ADD_RC
# * shlib_rc_has INIT_RC CHECK_RC
# * shlib_check_bool VALUE
# * shlib_check_unix_login VALUE
# * shlib_check_ip4 VALUE
# * shlib_check_loopback_ip4 VALUE
# * shlib_gen_rand [--len LEN] [--num] [--special] [--uc]
# * shlib_uniq_ordered [-r] -- FILE...      (stdin FILE_TEXT is supported)
# * shlib_template_compile [-o] [-f] [-s] [--KEY VALUE...] [--] FILE...
#   (stdin FILE_TEXT is supported)
# * shlib_sed_quote_pattern PATTERN         (stdin PATTERN is supported)
# * shlib_sed_quote_replace REPLACE         (stdin REPLACE is supported)

##############################
##### PRINTING / LOGGING #####
##############################

# Print SOURCE file to DEST files. Logging via stderr
# with prefixed DEST. Prefixes:
# '{{ success }}' - successfully generated
# '{{ skipped }}' - already exists, not overridden
# '{{ failed }}'  - failed to generate files
#
# OPTIONS
# =======
# --            End of options
# -f, --force   Force override if DEST exists
# --tag         Tag to put content to
# --tag-prefix  Prefix for tag, must be comment symbol, defaults to '#'
#
# USAGE:
#   shlib_file2dest [-f] [--tag TAG] [--tag-prefix TAG_PREFIX] [--] SOURCE [DEST...]
# RC:
#   * 0 - all is fine
#   * 1 - some of destinations are skipped
#   * 2 - some of destinations are not created
#   * 4 - source can't be read, fatal, provides no output
# DEMO:
#   # copy to files and address all kinds of logs
#   shlib_file2dest ./lib.sh ./libs/lib{0..9}.sh /dev/null/subzero ~/.bashrc \
#   2> >(
#     tee \
#       >(template_compile -o -f --success 'Success: ' | log_info) \
#       >(template_compile -o -f --skipped 'Skipped: ' | log_warn) \
#       >(template_compile -o -f --failed 'Failed: ' | log_err) \
#       >/dev/null
#   ) | cat
shlib_file2dest() {
  local source
  local SOURCE_TXT
  local -a DESTS
  local FORCE=false
  local TAG
  local TAG_PREFIX='#'

  local endopts=false
  local arg; while :; do
    [[ -n "${1+x}" ]] || break
    ${endopts} && arg='*' || arg="${1}"

    case "${arg}" in
      --            ) endopts=true ;;
      -f|--force    ) FORCE=true ;;
      --tag         ) shift; TAG="${1}" ;;
      --tag-prefix  ) shift; TAG_PREFIX="${1}" ;;
      *             )
        [[ -z "${source+x}" ]] \
          && source="${1}" || DESTS+=("${1}")
      ;;
    esac

    shift
  done

  SOURCE_TXT="$(cat -- "${source}" 2>/dev/null)" || return 4

  [[ ${#DESTS[@]} -lt 1 ]] && DESTS+=(/dev/stdout)

  local dir
  local real
  local dest_content
  local rc=0
  local f; for f in "${DESTS[@]}"; do
    real="$(realpath -m -- "${f}" 2>/dev/null)"

    ! ${FORCE} && [[ -f "${real}" ]] && {
      rc=$(shlib_rc_add ${rc} 1)
      shlib_print_stderr "{{ skipped }}${f}"
      continue
    }

    dir="$(dirname -- "${f}" 2>/dev/null)" \
    && mkdir -p -- "${dir}" 2>/dev/null

    [[ -n "${TAG}" ]] && {
      [[ -f "${f}" ]] && dest_content="$(cat "${f}" 2>/dev/null)"
      SOURCE_TXT="$(
        shlib_tag_node_set --prefix "${TAG_PREFIX} {" --suffix '}' \
          -- "${TAG}" "${SOURCE_TXT}" "${dest_content}"
      )"
    }

    (cat <<< "${SOURCE_TXT}" > "${f}") 2>/dev/null && {
      # don't bother logging for generated to stdout and other devnulls
      if [[ -f ${real} ]]; then shlib_print_stderr "{{ success }}${f}"; fi
    } || {
      rc=$(shlib_rc_add ${rc} 2)
      shlib_print_stderr "{{ failed }}${f}"
      continue
    }
  done

  return ${rc}
}

shlib_print_stderr() {
  shlib_print_stdout "${@}" >/dev/stderr
}

shlib_print_stdout() {
  [[ ${#} -gt 0 ]] && printf -- '%s\n' "${@}" || cat
}

# Log to stderr prefixed with ${SHLIB_LOG_TOOLNAME} and log type
#
# OPTIONS
# =======
# --          End of options
# -t, --tag   Log level tag. Available: major, minor
#             Defaults to major
#
# USAGE
#   shlib_log_* [-t LEVEL_TAG] [--] MSG...
#   shlib_log_* [-t LEVEL_TAG] <<< MSG
#   # combined with `shlib_text_decore`
#   shlib_text_decore MSG... | shlib_log_* [-t LEVEL_TAG]
# LEVELS
#   # Configure level you want to log
#   SHLIB_LOG_INFO_LEVEL=major
#
#   # ... some code here ...
#
#   # This will not log
#   shlib_log_info -t minor "HELLO MINOR"
#
#   # And this will, as major is default
#   shlib_log_info "HELLO MAJOR"
#
#   # This will never log
#   SHLIB_LOG_INFO_LEVEL=none shlib_log_info "HELLO MAJOR"
shlib_log_info() {
  LEVEL="${SHLIB_LOG_INFO_LEVEL}" \
  _shlib_log_type info "${@}"
}
shlib_log_warn() {
  LEVEL="${SHLIB_LOG_WARN_LEVEL}" \
  _shlib_log_type warn "${@}"
}
shlib_log_err() {
  LEVEL="${SHLIB_LOG_ERR_LEVEL}" \
  _shlib_log_type err "${@}"
}

_shlib_log_type() {
  local TYPE="${1}"
  local TAG=major
  local -a MSGS
  shift

  local endopts=false
  local arg; while :; do
    [[ -n "${1+x}" ]] || break
    ${endopts} && arg='*' || arg="${1}"

    case "${arg}" in
      --        ) endopts=true ;;
      -t|--tag  ) shift; TAG="${1:-${TAG}}" ;;
      *         ) MSGS+=("${1}") ;;
    esac

    shift
  done

  [[ "${TAG}" == none ]] && TAG=major
  LEVEL="${LEVEL:-major}"

  local -A level2num=( [none]=0 [major]=1 [minor]=2 )
  local req_level="${level2num["${LEVEL}"]:-${level2num[major]}}"
  local log_tag="${level2num["${TAG}"]:-${level2num[major]}}"

  # If reqired level is lower then current log tag, nothing to do here
  [[ ${req_level} -lt ${log_tag} ]] && return 0

  local prefix="${SHLIB_LOG_TOOLNAME:+"${SHLIB_LOG_TOOLNAME}:"}${TYPE}"
  shlib_print_stdout "${MSGS[@]}" | sed -e 's/^/['"${prefix}"'] /' | shlib_print_stderr
}

################
##### TEXT #####
################

shlib_text_ltrim() {
  shlib_print_stdout "${@}" | sed 's/^\s\+//'
}

shlib_text_rtrim() {
  shlib_print_stdout "${@}" | sed 's/\s\+$//'
}

shlib_text_trim() {
  shlib_print_stdout "${@}" | sed -e 's/^\s\+//' -e 's/\s\+$//'
}

# remove blank and space only lines
shlib_text_rmblank() {
  shlib_print_stdout "${@}" | grep -vx '\s*'
}

# apply trim and rmblank
shlib_text_clean() {
  shlib_text_trim "${@}" | shlib_text_rmblank
}

# Decoreate text:
# * apply clean
# * remove starting '.'
# Prefix line with '.' to preserve empty line or offset
#
# USAGE
#   shlib_text_decore MSG...
#   shlib_text_decore <<< MSG
shlib_text_decore() {
  shlib_text_clean "${@}" | sed 's/^\.//'
}

####################
##### TRAPPING #####
####################

# Detect one of help options: -h, -?, --help
#
# USAGE:
#   shlib_trap_help_opt ARG...
# RC:
#   * 0 - help option detected
#   * 1 - no help option
#   * 2 - help option detected, but there are extra args,
#         invalid args are printed to stdout
shlib_trap_help_opt() {
  local is_help=false

  [[ "${1}" =~ ^(-h|-\?|--help)$ ]] \
    && is_help=true && shift

  local -a inval
  while :; do
    [[ -n "${1+x}" ]] || break
    inval+=("${1}")
    shift
  done

  ! ${is_help} && return 1

  ${is_help} && [[ ${#inval[@]} -gt 0 ]] && {
    shlib_print_stdout "${inval[@]}"
    return 2
  }

  return 0
}

# Exit with RC if it's > 0. If no MSG, no err message will be logged.
# * RC is required to be numeric!
# * not to be used in scripts sourced to ~/.bashrc!
#
# Options:
#   --decore  - apply shlib_text_decore over input messages
# USAGE:
#   shlib_trap_fatal [--decore] [--] RC [MSG...]
shlib_trap_fatal() {
  local rc
  local -a msgs
  local decore=false

  local endopts=false
  local arg; while :; do
    [[ -n "${1+x}" ]] || break
    ${endopts} && arg='*' || arg="${1}"
    case "${arg}" in
      --        ) endopts=true ;;
      --decore  ) decore=true ;;
      *         ) [[ -z "${rc+x}" ]] && rc="${1}" || msgs+=("${1}") ;;
    esac
    shift
  done

  [[ -n "${rc+x}" ]] || return 0
  [[ $rc -gt 0 ]] || return ${rc}

  [[ ${#msgs[@]} -gt 0 ]] && {
    local filter=(shlib_print_stdout)
    ${decore} && filter=(shlib_text_decore)
    "${filter[@]}" "${msgs[@]}" | _shlib_log_type fatal
  }

  exit ${rc}
}

################
##### TAGS #####
################

# USAGE:
#   shlib_tag_node_set [--prefix PREFIX] [--suffix SUFFIX] \
#     [--] TAG CONTENT TEXT...
#   shlib_tag_node_set [--prefix PREFIX] [--suffix SUFFIX] \
#     [--] TAG CONTENT <<< TEXT
shlib_tag_node_set() {
  local tag
  local content
  local text
  local prefix
  local suffix

  local endopts=false
  local arg; while :; do
    [[ -n "${1+x}" ]] || break
    ${endopts} && arg='*' || arg="${1}"

    case "${arg}" in
      --        ) endopts=true ;;
      --prefix  ) shift; prefix="${1}" ;;
      --suffix  ) shift; suffix="${1}" ;;
      *         )
        if [[ -z "${tag+x}" ]]; then
          tag="${1}"
        elif [[ -z "${content+x}" ]]; then
          content="${1}"
        else
          text+="${text:+$'\n'}${1}"
        fi
        ;;
    esac

    shift
  done

  [[ -n "${text+x}" ]] || text="$(cat)"

  local open="$(_shlib_tag_mk_openline "${tag}" "${prefix}" "${suffix}")"
  local close="$(_shlib_tag_mk_closeline "${tag}" "${prefix}" "${suffix}")"

  local add_text
  add_text="$(printf '%s\n%s\n%s\n' \
    "${open}" "$(sed 's/^/  /' <<< "${content}")" "${close}")"

  local range
  range="$(_shlib_tag_get_lines_range "${open}" "${close}" "${text}")" || {
    printf '%s\n' "${text:+${text}$'\n'}${add_text}"
    return
  }

  head -n "$(( ${range%%,*} - 1 ))" <<< "${text}"
  printf '%s\n' "${add_text}"
  tail -n +"$(( ${range##*,} + 1 ))" <<< "${text}"
}

# USAGE:
#   shlib_tag_node_get [--prefix PREFIX] [--suffix SUFFIX] \
#     [--strip] [--] TAG TEXT...
#   shlib_tag_node_get [--prefix PREFIX] [--suffix SUFFIX] \
#     [--strip] [--] TAG <<< TEXT
# RC:
#   0 - all is fine content is returned
#   1 - tag not found
shlib_tag_node_get() {
  local tag
  local text
  local prefix
  local suffix
  local strip=false

  local endopts=false
  local arg; while :; do
    [[ -n "${1+x}" ]] || break
    ${endopts} && arg='*' || arg="${1}"

    case "${arg}" in
      --        ) endopts=true ;;
      --prefix  ) shift; prefix="${1}" ;;
      --suffix  ) shift; suffix="${1}" ;;
      --strip   ) strip=true ;;
      *         )
        [[ -n "${tag+x}" ]] \
          && text+="${text+$'\n'}${1}" \
          || tag="${1}"
        ;;
    esac

    shift
  done

  [[ -n "${text+x}" ]] || text="$(cat)"

  local open="$(_shlib_tag_mk_openline "${tag}" "${prefix}" "${suffix}")"
  local close="$(_shlib_tag_mk_closeline "${tag}" "${prefix}" "${suffix}")"

  local range
  range="$(_shlib_tag_get_lines_range "${open}" "${close}" "${text}")" || {
    return 1
  }

  local -a filter=(cat)
  ${strip} && filter=(sed -e '1d;$d;s/^  //')

  sed -e "${range}!d" <<< "${text}" | "${filter[@]}"
}

# USAGE:
#   shlib_tag_node_rm [--prefix PREFIX] \
#     [--suffix SUFFIX] [--] TAG TEXT...
#   shlib_tag_node_rm [--prefix PREFIX] \
#     [--suffix SUFFIX] [--] TAG <<< TEXT
# RC:
#   0 - all is fine content is returned
#   1 - tag not found
shlib_tag_node_rm() {
  local tag
  local text
  local prefix
  local suffix

  local endopts=false
  local arg; while :; do
    [[ -n "${1+x}" ]] || break
    ${endopts} && arg='*' || arg="${1}"

    case "${arg}" in
      --        ) endopts=true ;;
      --prefix  ) shift; prefix="${1}" ;;
      --suffix  ) shift; suffix="${1}" ;;
      *         )
        [[ -n "${tag+x}" ]] \
          && text+="${text+$'\n'}${1}" \
          || tag="${1}"
        ;;
    esac

    shift
  done

  [[ -n "${text+x}" ]] || text="$(cat)"

  local open="$(_shlib_tag_mk_openline "${tag}" "${prefix}" "${suffix}")"
  local close="$(_shlib_tag_mk_closeline "${tag}" "${prefix}" "${suffix}")"

  local range
  range="$(_shlib_tag_get_lines_range "${open}" "${close}" "${text}")" || {
    shlib_print_stdout "${text}"
    return 1
  }

  sed -e "${range}d" <<< "${text}"
}

# RC > 0 or comma separated open and close line numbers
_shlib_tag_get_lines_range() {
  local open="${1}"
  local close="${2}"
  local text="${3}"

  local close_rex
  close_rex="$(shlib_sed_quote_pattern "${close}")"

  local lines_numbered
  lines_numbered="$(
    grep -m 1 -n -A 9999999 -Fx "${open}" <<< "${text}" \
    | grep -m 1 -B 9999999 -e "^[0-9]\+-${close_rex}$"
  )" || return $?

  sed -e 's/^\([0-9]\+\).*/\1/' -n -e '1p;$p' <<< "${lines_numbered}" \
  | xargs | tr ' ' ','
}

_shlib_tag_mk_openline() {
  local tag="${1}"
  local prefix="${2}"
  local suffix="${3}"
  printf -- '%s' "${prefix}${tag}${suffix}"
}

_shlib_tag_mk_closeline() {
  local tag="${1}"
  local prefix="${2}"
  local suffix="${3}"
  printf -- '%s' "${prefix}/${tag}${suffix}"
}

#######################
##### RETURN CODE #####
#######################

shlib_rc_add() {
  echo $(( ${1} | ${2} ))
}

shlib_rc_has() {
  [[ $(( ${1} & ${2} )) -eq ${2} ]]
}

######################
##### VALIDATION #####
######################

shlib_check_bool() {
  [[ "${1}" =~ ^(true|false)$ ]]
}

shlib_check_unix_login() {
  # https://unix.stackexchange.com/questions/157426/what-is-the-regex-to-validate-linux-users
  local rex='[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)'
  grep -qEx -- "${rex}" <<< "${1}"
}

shlib_check_ip4() {
  local seg_rex='(0|[1-9][0-9]*)'

  grep -qxE "(${seg_rex}\.){3}${seg_rex}" <<< "${1}" || return 1

  local segments
  mapfile -t segments <<< "$(tr '.' '\n' <<< "${1}")"
  local seg; for seg in "${segments[@]}"; do
    [[ "${seg}" -gt 255 ]] && return 1
  done

  return 0
}

shlib_check_loopback_ip4() {
  shlib_check_ip4 "${1}" && grep -q '^127' <<< "${1}"
}

#####################
##### PROFILING #####
#####################

shlib_profiler_init() {
  ${SHLIB_PROFILER_ENABLED-false} || return
  [[ -n "${SHLIB_PROFILER_TIMESTAMP}" ]] && return

  SHLIB_PROFILER_TIMESTAMP=$(( $(date +%s%N) / 1000000 ))
  export SHLIB_PROFILER_TIMESTAMP
}

shlib_profiler_run() {
  ${SHLIB_PROFILER_ENABLED-false} || return
  [[ -n "${SHLIB_PROFILER_TIMESTAMP}" ]] || return

  local message="${1}"

  local time=$(( ($(date +%s%N) / 1000000) - ${SHLIB_PROFILER_TIMESTAMP} ))

  {
    printf '%6s.%03d' $(( time / 1000 )) $(( time % 1000 ))
    [[ -n "${message}" ]] \
      && printf ' %s\n' "${message}" \
      || printf '\n'
  } | _shlib_log_type profile
}

################
##### MISC #####
################

# Generate a random value, lower case latters only by default
# https://unix.stackexchange.com/a/230676
#
# OPTIONS
# =======
# --len       Value length, defaults to 10
# --num       Include numbers
# --special   Include special characters
# --uc        Include upper case
#
# USAGE:
#   shlib_gen_rand [--len LEN] [--num] [--special] [--uc]
shlib_gen_rand() {
  local len=10
  local num=false
  local special=false
  local uc=false
  local filter='a-z'

  while :; do
    [[ -n "${1+x}" ]] || break
    case "${1}" in
      --len     ) shift; len="${1}" ;;
      --num     ) num=true ;;
      --special ) special=true ;;
      --uc      ) uc=true ;;
    esac
    shift
  done

  ${num} && filter+='0-9'; ${uc} && filter+='A-Z'
  ${special} && filter+='!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~'
  LC_ALL=C tr -dc "${filter}" </dev/urandom | fold -w "${len}" | head -n 1
}

# Get unique lines preserving lines order. By default top unique
# lines are prioritized
#
# OPTIONS
# =======
# --              End of options
# -r, --reverse   Prioritize bottom unique values
#
# USAGE:
#   shlib_uniq_ordered [-r] -- FILE...
#   shlib_uniq_ordered [-r] <<< FILE_TEXT
shlib_uniq_ordered() {
  local -a revfilter=(cat)
  local -a files

  local endopts=false
  local arg; while :; do
    [[ -n "${1+x}" ]] || break
    ${endopts} && arg='*' || arg="${1}"

    case "${arg}" in
      --            ) endopts=true ;;
      -r|--reverse  ) revfilter=(tac) ;;
      *             ) files+=("${1}") ;;
    esac

    shift
  done

  # https://unix.stackexchange.com/a/194790
  cat "${files[@]}" | "${revfilter[@]}" \
  | cat -n | sort -k2 -k1n | uniq -f1 | sort -nk1,1 | cut -f2- \
  | "${revfilter[@]}"
}

# Compile template FILE replacing '{{ KEY }}' with VALUE.
# In case of duplicated --KEY option last wins. Nothing
# happens if FILE path is invalid.
# Limitations:
# * multiline KEY and VALUE are not allowed
#
# OPTIONS
# =======
# --  End of options
# -o  Only output affected lines
# -f  Substitute KEY only when it's first thing in the line
# -s  Substitute only single occurrence
#
# USAGE:
#   shlib_template_compile [-o] [-f] [-s] [--KEY VALUE...] [--] FILE...
#   shlib_template_compile [-o] [-f] [-s] [--KEY VALUE...] <<< FILE_TEXT
# Demo:
#   # outputs: "account=varlog, password=changeme"
#   shlib_template_compile --user varlog --pass changeme \
#     <<< "login={{ user }}, password={{ pass }}"
shlib_template_compile() {
  local -a files
  local -A kv
  local first=false
  local single=false
  local only=false

  local endopts=false
  local arg; while :; do
    [[ -n "${1+x}" ]] || break
    ${endopts} && arg='*' || arg="${1}"

    case "${arg}" in
      --  ) endopts=true ;;
      -o  ) only=true ;;
      -f  ) first=true ;;
      -s  ) single=true ;;
      --* ) shift; kv[${arg:2}]="${1}" ;;
      *   ) files+=("${1}") ;;
    esac

    shift
  done

  local key
  local value
  for key in "${!kv[@]}"; do
    value="$(shlib_sed_quote_replace "${kv["${key}"]}")"
    kv["${key}"]="${value}"
  done

  local template
  template="$(cat -- "${files[@]}" 2>/dev/null)"

  local -a filter
  local expression
  if ${only}; then
    for key in "${!kv[@]}"; do
      # https://www.cyberciti.biz/faq/unix-linux-sed-print-only-matching-lines-command/
      filter=(sed)
      key="$(shlib_sed_quote_pattern "${key}")"
      expression="{{\s*${key}\s*}}/${kv["${key}"]}"
      ${first} && expression="^${expression}"
      expression="s/${expression}/"
      ! ${single} && expression+='g'
      ${only} && filter+=(-n) && expression+='p'
      filter+=("${expression}")

      template="$("${filter[@]}" <<< "${template}")"
    done
  else
    # lighter than with ONLY option

    # initially passthrough filter
    filter=(sed -e 's/^/&/')

    for key in "${!kv[@]}"; do
      key="$(shlib_sed_quote_pattern "${key}")"
      expression="{{\s*${key}\s*}}/${kv["${key}"]}"
      ${first} && expression="^${expression}"
      filter+=(-e "s/${expression}/g")
    done

    template="$("${filter[@]}" <<< "${template}")"
  fi

  [[ -n "${template}" ]] && cat <<< "${template}"
}

# https://gist.github.com/varlogerr/2c058af053921f1e9a0ddc39ab854577#file-sed-quote
shlib_sed_quote_pattern() {
  sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"
}
shlib_sed_quote_replace() {
  sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"
}

##########################
##### OVERRIDES DEMO #####
##########################

# ## In most cases it's the first candidate for override
#
# eval "$(typeset -f shlib_file2dest | sed '1s/ \?(/_overriden_ (/')"
# shlib_file2dest() {
#   # https://unix.stackexchange.com/a/43536
#   shlib_file2dest_overriden_ "${@}" \
#   2> >(
#     tee \
#       >(shlib_template_compile -o -f --success 'Success: ' | shlib_log_info) \
#       >(shlib_template_compile -o -f --skipped 'Skipped: ' | shlib_log_warn) \
#       >(shlib_template_compile -o -f --failed 'Failed: ' | shlib_log_err) \
#       >/dev/null
#   ) | cat
#
#   # https://unix.stackexchange.com/a/73180
#   return "${PIPESTATUS[0]}"
# }

# ## A lighter version of tags, less secure, but fine for personal data
# ## sets. Disregards suffix and prefix, suffix is hardcoded to '#'
#
#_shlib_tag_mk_openline() { printf -- '%s' "#${1}"; }
#_shlib_tag_mk_closeline() { printf -- '%s' "#${1}"; }
#_shlib_tag_get_lines_range() {
#  local open="${1}"
#  local close="${2}"
#
#  local lines_numbered
#  lines_numbered="$(grep -m 2 -n -Fx "${open}" <<< "${text}")" || return $?
#
#  sed -e 's/^\([0-9]\+\).*/\1/' -n -e '1p;$p' <<< "${lines_numbered}" \
#  | xargs | tr ' ' ','
#}
