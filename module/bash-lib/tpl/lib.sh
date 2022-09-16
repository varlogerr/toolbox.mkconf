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
#####
##### {/CONF}

# FUNCTIONS:
# * shlib_file2dest [-f] [--tag TAG] [--tag-prefix TAG_PREFIX] [--] SOURCE [DEST...]
# * shlib_print_decore MSG...               (stdin MSG is supported)
# * shlib_log_* [-t LEVEL_TAG] [--] MSG...  (stdin MSG is supported)
# * shlib_trap_help_opt HELP_FUNCTION ARG...
# * shlib_trap_fatal RC [MSG...]
# * shlib_tag_node_get [--prefix PREFIX] [--suffix SUFFIX] [--strip] [--] TAG TEXT...
#   (stdin TEXT is supported)
# * shlib_tag_node_rm [--prefix PREFIX] [--suffix SUFFIX] [--] TAG TEXT...
#   (stdin TEXT is supported)
# * shlib_tag_node_set [--prefix PREFIX] [--suffix SUFFIX] [--] TAG CONTENT TEXT...
#   (stdin TEXT is supported)
# * shlib_rc_add INIT_RC ADD_RC
# * shlib_rc_has INIT_RC CHECK_RC
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
#   result="$(shlib_file2dest ./lib.sh lib{0..9}.sh /dev/null/subzero 2>&1)" || rc=$?
#   shlib_rc_has ${rc} 4 && {
#     shlib_log_err "Failure loading SOURCE"
#   } || {
#     shlib_template_compile -o -f --success 'Success: ' <<< "${result}" | shlib_log_info
#     shlib_template_compile -o -f --skipped 'Skipped: ' <<< "${result}" | shlib_log_warn
#     shlib_template_compile -o -f --failed 'Failed: ' <<< "${result}" | shlib_log_err
#   }
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
      _shlib_print_stderr "{{ skipped }}${f}"
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
      if [[ -f ${real} ]]; then _shlib_print_stderr "{{ success }}${f}"; fi
    } || {
      rc=$(shlib_rc_add ${rc} 2)
      _shlib_print_stderr "{{ failed }}${f}"
      continue
    }
  done

  return ${rc}
}

# Print message
# * removes blank lines
# * removes starting and trailing space-offset
# * removes starting '.'
# Prefix line with '.' to preserve empty line or offset
#
# USAGE
#   shlib_print_decore MSG...
#   shlib_print_decore <<< MSG
shlib_print_decore() {
  _shlib_print_stdout "${@}" | grep -Ev '^\s*$' \
  | sed -E -e 's/^\s+//' -e 's/\s+$//' -e 's/^\.//'
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
#   # combined with `shlib_print_decore`
#   shlib_print_decore MSG... | shlib_log_* [-t LEVEL_TAG]
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
    _shlib_print_stdout "${inval[@]}"
    return 2
  }

  return 0
}

# Exit with RC if it's > 0. If no MSG, no err message will be logged.
# * RC is required to be numeric!
# * not to be used in scripts sourced to ~/.bashrc!
#
# Options:
#   --decore  - apply print_decore over input messages
# USAGE:
#   trap_fatal [--decore] [--] RC [MSG...]
trap_fatal() {
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
    local filter=(_print_stdout)
    ${decore} && filter=(print_decore)
    "${filter[@]}" "${msgs[@]}" | _log_type fatal
  }

  exit ${rc}
}

################
##### TAGS #####
################

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

  local open="${prefix}${tag}${suffix}"
  local close="${prefix}/${tag}${suffix}"
  local open_rex="^$(shlib_sed_quote_pattern "${open}")$"
  local close_rex="^$(shlib_sed_quote_pattern "${close}")$"

  # https://www.cyberciti.biz/faq/unix-linux-sed-print-only-matching-lines-command/
  local content
  content="$(sed -n -e "/${open_rex}/,/${close_rex}/p" <<< "${text}")"
  [[ -n "${content}" ]] || return 1

  local strip_top=(cat)
  local strip_bottom=(cat)
  local strip_offset=(cat)
  ${strip} && {
    strip_top=(head -n -1)
    strip_bottom=(tail -n +2)
    strip_offset=(sed 's/^  //')
  }

  "${strip_top[@]}" <<< "${content}" \
  | "${strip_bottom[@]}" \
  | "${strip_offset[@]}"
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

  local open="${prefix}${tag}${suffix}"
  local close="${prefix}/${tag}${suffix}"
  local open_rex="^$(shlib_sed_quote_pattern "${open}")$"
  local close_rex="^$(shlib_sed_quote_pattern "${close}")$"

  local tmp
  local -a parts
  tmp="$(grep -m 1 -B 9999999 -- "${open_rex}" <<< "${text}")" && {
    parts+=("$(head -n -1 <<< "${tmp}")")
  } || {
    _shlib_print_stdout "${text}"
    return 1
  }
  tmp="$(
    grep -m 1 -A 9999999 -- "${open_rex}" <<< "${text}" \
    | grep -m 1 -A 9999999 -- "${close_rex}"
  )" && {
    parts+=("$(tail -n +2 <<< "${tmp}")")
  } || {
    _shlib_print_stdout "${text}"
    return 1
  }

  _shlib_print_stdout "${parts[@]}"
}

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

  local open="${prefix}${tag}${suffix}"
  local close="${prefix}/${tag}${suffix}"

  if shlib_tag_node_get --prefix "${prefix}" \
    --suffix "${suffix}" -- "${tag}" "${text}" >/dev/null \
  ; then
    local open_rex="^$(shlib_sed_quote_pattern "${open}")$"
    local close_rex="^[0-9]\+-$(shlib_sed_quote_pattern "${close}")$"
    local tag_ln
    tag_ln="$(
      grep -m 1 -n -A 999999 -- "${open_rex}" <<< "${text}" \
      | grep -m 1 -B 999999 -- "${close_rex}" \
      | sed -n '1p;$p' | grep -o '^[0-9]\+'
    )"
    head -n "$(head -n 1 <<< "${tag_ln}")" <<< "${text}"
    sed 's/^/  /' <<< "${content}"
    tail -n "+$(tail -n 1 <<< "${tag_ln}")" <<< "${text}"
  else
    local -a parts
    [[ -n "${text}" ]] && parts+=("${text}")
    parts+=(
      "${open}"
      "$(sed 's/^/  /' <<< "${content}")"
      "${close}"
    )

    _shlib_print_stdout "${parts[@]}"
  fi
}

#######################
##### RETURN CODE #####
#######################

shlib_rc_add() {
  local init="${1}"
  local add="${2}"

  echo $(( init | ${add} ))
}

shlib_rc_has() {
  local code="${1}"
  local has="${2}"

  test $(( code & ${has} )) -eq ${has}
}

################
##### MISC #####
################

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
  local -a revfilter=(cat --)
  local -a files

  local endopts=false
  local arg; while :; do
    [[ -n "${1+x}" ]] || break
    ${endopts} && arg='*' || arg="${1}"

    case "${arg}" in
      --            ) endopts=true ;;
      -r|--reverse  ) revfilter=(tac --) ;;
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
  local key="${1-$(cat)}"
  sed -e 's/[]\/$*.^[]/\\&/g' <<< "${key}"
}
shlib_sed_quote_replace() {
  local replace="${1-$(cat)}"
  sed -e 's/[\/&]/\\&/g' <<< "${replace}"
}

###################
##### PRIVATE #####
###################

_shlib_print_stderr() {
  _shlib_print_stdout "${@}" >/dev/stderr
}

_shlib_print_stdout() {
  local -a msgs=("${@}")

  [[ ${#msgs[@]} -gt 0 ]] \
    && printf -- '%s\n' "${msgs[@]}" \
    || cat
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
  _shlib_print_stdout "${MSGS[@]}" | sed -e 's/^/['"${prefix}"'] /' | _shlib_print_stderr
}
