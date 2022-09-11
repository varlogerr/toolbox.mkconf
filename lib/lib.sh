# {SHLIB_GEN}
  ##### {CONF}
  #####
  #
  # Tool name to be used in log prefix.
  # Leave blank to use only log type for prefix
  LOG_TOOLNAME="${LOG_TOOLNAME:-}"
  #
  # This three are used for logging (see logs functions description)
  # Available values:
  # * none    - don't log
  # * major   - log only major
  # * minor   - log everything
  # If not defined or values misspelled, defaults to 'major'
  LOG_INFO_LEVEL="${LOG_INFO_LEVEL-major}"
  LOG_WARN_LEVEL="${LOG_WARN_LEVEL-major}"
  LOG_ERR_LEVEL="${LOG_ERR_LEVEL-major}"
  #
  # Profiler
  PROFILER_ENABLED="${PROFILER_ENABLED-false}"
  #
  #####
  ##### {/CONF}
  
  # FUNCTIONS:
  # * file2dest [-f] [--tag TAG] [--tag-prefix TAG_PREFIX] [--] SOURCE [DEST...]
  # * print_stderr MSG...               (stdin MSG is supported)
  # * print_stdout MSG...               (stdin MSG is supported)
  # * log_* [-t LEVEL_TAG] [--] MSG...  (stdin MSG is supported)
  # * text_ltrim TEXT...    (stdin TEXT is supported)
  # * text_rtrim TEXT...    (stdin TEXT is supported)
  # * text_trim TEXT...     (stdin TEXT is supported)
  # * text_rmblank TEXT...  (stdin TEXT is supported)
  # * text_clean TEXT...    (stdin TEXT is supported)
  # * text_decore TEXT...   (stdin TEXT is supported)
  # * trap_help_opt ARG...
  # * trap_fatal [--decore] [--] RC [MSG...]
  # * tag_node_set [--prefix PREFIX] [--suffix SUFFIX] [--] TAG CONTENT TEXT...
  #   (stdin TEXT is supported)
  # * tag_node_get [--prefix PREFIX] [--suffix SUFFIX] [--strip] [--] TAG TEXT...
  #   (stdin TEXT is supported)
  # * tag_node_rm [--prefix PREFIX] [--suffix SUFFIX] [--] TAG TEXT...
  #   (stdin TEXT is supported)
  # * rc_add INIT_RC ADD_RC
  # * rc_has INIT_RC CHECK_RC
  # * check_bool VALUE
  # * check_unix_login VALUE
  # * check_ip4 VALUE
  # * check_loopback_ip4 VALUE
  # * gen_rand [--len LEN] [--num] [--special] [--uc]
  # * uniq_ordered [-r] -- FILE...      (stdin FILE_TEXT is supported)
  # * template_compile [-o] [-f] [-s] [--KEY VALUE...] [--] FILE...
  #   (stdin FILE_TEXT is supported)
  # * sed_quote_pattern PATTERN         (stdin PATTERN is supported)
  # * sed_quote_replace REPLACE         (stdin REPLACE is supported)
  
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
  #   file2dest [-f] [--tag TAG] [--tag-prefix TAG_PREFIX] [--] SOURCE [DEST...]
  # RC:
  #   * 0 - all is fine
  #   * 1 - some of destinations are skipped
  #   * 2 - some of destinations are not created
  #   * 4 - source can't be read, fatal, provides no output
  # DEMO:
  #   # copy to files and address all kinds of logs
  #   file2dest ./lib.sh ./libs/lib{0..9}.sh /dev/null/subzero ~/.bashrc \
  #   2> >(
  #     tee \
  #       >(template_compile -o -f --success 'Success: ' | log_info) \
  #       >(template_compile -o -f --skipped 'Skipped: ' | log_warn) \
  #       >(template_compile -o -f --failed 'Failed: ' | log_err) \
  #       >/dev/null
  #   ) | cat
  file2dest() {
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
        rc=$(rc_add ${rc} 1)
        print_stderr "{{ skipped }}${f}"
        continue
      }
  
      dir="$(dirname -- "${f}" 2>/dev/null)" \
      && mkdir -p -- "${dir}" 2>/dev/null
  
      [[ -n "${TAG}" ]] && {
        [[ -f "${f}" ]] && dest_content="$(cat "${f}" 2>/dev/null)"
        SOURCE_TXT="$(
          tag_node_set --prefix "${TAG_PREFIX} {" --suffix '}' \
            -- "${TAG}" "${SOURCE_TXT}" "${dest_content}"
        )"
      }
  
      (cat <<< "${SOURCE_TXT}" > "${f}") 2>/dev/null && {
        # don't bother logging for generated to stdout and other devnulls
        if [[ -f ${real} ]]; then print_stderr "{{ success }}${f}"; fi
      } || {
        rc=$(rc_add ${rc} 2)
        print_stderr "{{ failed }}${f}"
        continue
      }
    done
  
    return ${rc}
  }
  
  print_stderr() {
    print_stdout "${@}" >/dev/stderr
  }
  
  print_stdout() {
    [[ ${#} -gt 0 ]] && printf -- '%s\n' "${@}" || cat
  }
  
  # Log to stderr prefixed with ${LOG_TOOLNAME} and log type
  #
  # OPTIONS
  # =======
  # --          End of options
  # -t, --tag   Log level tag. Available: major, minor
  #             Defaults to major
  #
  # USAGE
  #   log_* [-t LEVEL_TAG] [--] MSG...
  #   log_* [-t LEVEL_TAG] <<< MSG
  #   # combined with `text_decore`
  #   text_decore MSG... | log_* [-t LEVEL_TAG]
  # LEVELS
  #   # Configure level you want to log
  #   LOG_INFO_LEVEL=major
  #
  #   # ... some code here ...
  #
  #   # This will not log
  #   log_info -t minor "HELLO MINOR"
  #
  #   # And this will, as major is default
  #   log_info "HELLO MAJOR"
  #
  #   # This will never log
  #   LOG_INFO_LEVEL=none log_info "HELLO MAJOR"
  log_info() {
    LEVEL="${LOG_INFO_LEVEL}" \
    _log_type info "${@}"
  }
  log_warn() {
    LEVEL="${LOG_WARN_LEVEL}" \
    _log_type warn "${@}"
  }
  log_err() {
    LEVEL="${LOG_ERR_LEVEL}" \
    _log_type err "${@}"
  }
  
  _log_type() {
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
  
    local prefix="${LOG_TOOLNAME:+"${LOG_TOOLNAME}:"}${TYPE}"
    print_stdout "${MSGS[@]}" | sed -e 's/^/['"${prefix}"'] /' | print_stderr
  }
  
  ################
  ##### TEXT #####
  ################
  
  text_ltrim() {
    print_stdout "${@}" | sed 's/^\s\+//'
  }
  
  text_rtrim() {
    print_stdout "${@}" | sed 's/\s\+$//'
  }
  
  text_trim() {
    print_stdout "${@}" | sed -e 's/^\s\+//' -e 's/\s\+$//'
  }
  
  # remove blank and space only lines
  text_rmblank() {
    print_stdout "${@}" | grep -vx '\s*'
  }
  
  # apply trim and rmblank
  text_clean() {
    text_trim "${@}" | text_rmblank
  }
  
  # Decoreate text:
  # * apply clean
  # * remove starting '.'
  # Prefix line with '.' to preserve empty line or offset
  #
  # USAGE
  #   text_decore MSG...
  #   text_decore <<< MSG
  text_decore() {
    text_clean "${@}" | sed 's/^\.//'
  }
  
  ####################
  ##### TRAPPING #####
  ####################
  
  # Detect one of help options: -h, -?, --help
  #
  # USAGE:
  #   trap_help_opt ARG...
  # RC:
  #   * 0 - help option detected
  #   * 1 - no help option
  #   * 2 - help option detected, but there are extra args,
  #         invalid args are printed to stdout
  trap_help_opt() {
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
      print_stdout "${inval[@]}"
      return 2
    }
  
    return 0
  }
  
  # Exit with RC if it's > 0. If no MSG, no err message will be logged.
  # * RC is required to be numeric!
  # * not to be used in scripts sourced to ~/.bashrc!
  #
  # Options:
  #   --decore  - apply text_decore over input messages
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
      local filter=(print_stdout)
      ${decore} && filter=(text_decore)
      "${filter[@]}" "${msgs[@]}" | _log_type fatal
    }
  
    exit ${rc}
  }
  
  ################
  ##### TAGS #####
  ################
  
  # USAGE:
  #   tag_node_set [--prefix PREFIX] [--suffix SUFFIX] \
  #     [--] TAG CONTENT TEXT...
  #   tag_node_set [--prefix PREFIX] [--suffix SUFFIX] \
  #     [--] TAG CONTENT <<< TEXT
  tag_node_set() {
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
  
    local open="$(_tag_mk_openline "${tag}" "${prefix}" "${suffix}")"
    local close="$(_tag_mk_closeline "${tag}" "${prefix}" "${suffix}")"
  
    local add_text
    add_text="$(printf '%s\n%s\n%s\n' \
      "${open}" "$(sed 's/^/  /' <<< "${content}")" "${close}")"
  
    local range
    range="$(_tag_get_lines_range "${open}" "${close}" "${text}")" || {
      printf '%s\n' "${text:+${text}$'\n'}${add_text}"
      return
    }
  
    head -n "$(( ${range%%,*} - 1 ))" <<< "${text}"
    printf '%s\n' "${add_text}"
    tail -n +"$(( ${range##*,} + 1 ))" <<< "${text}"
  }
  
  # USAGE:
  #   tag_node_get [--prefix PREFIX] [--suffix SUFFIX] \
  #     [--strip] [--] TAG TEXT...
  #   tag_node_get [--prefix PREFIX] [--suffix SUFFIX] \
  #     [--strip] [--] TAG <<< TEXT
  # RC:
  #   0 - all is fine content is returned
  #   1 - tag not found
  tag_node_get() {
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
  
    local open="$(_tag_mk_openline "${tag}" "${prefix}" "${suffix}")"
    local close="$(_tag_mk_closeline "${tag}" "${prefix}" "${suffix}")"
  
    local range
    range="$(_tag_get_lines_range "${open}" "${close}" "${text}")" || {
      return 1
    }
  
    local -a filter=(cat)
    ${strip} && filter=(sed -e '1d;$d;s/^  //')
  
    sed -e "${range}!d" <<< "${text}" | "${filter[@]}"
  }
  
  # USAGE:
  #   tag_node_rm [--prefix PREFIX] \
  #     [--suffix SUFFIX] [--] TAG TEXT...
  #   tag_node_rm [--prefix PREFIX] \
  #     [--suffix SUFFIX] [--] TAG <<< TEXT
  # RC:
  #   0 - all is fine content is returned
  #   1 - tag not found
  tag_node_rm() {
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
  
    local open="$(_tag_mk_openline "${tag}" "${prefix}" "${suffix}")"
    local close="$(_tag_mk_closeline "${tag}" "${prefix}" "${suffix}")"
  
    local range
    range="$(_tag_get_lines_range "${open}" "${close}" "${text}")" || {
      print_stdout "${text}"
      return 1
    }
  
    sed -e "${range}d" <<< "${text}"
  }
  
  # RC > 0 or comma separated open and close line numbers
  _tag_get_lines_range() {
    local open="${1}"
    local close="${2}"
    local text="${3}"
  
    local close_rex
    close_rex="$(sed_quote_pattern "${close}")"
  
    local lines_numbered
    lines_numbered="$(
      grep -m 1 -n -A 9999999 -Fx "${open}" <<< "${text}" \
      | grep -m 1 -B 9999999 -e "^[0-9]\+-${close_rex}$"
    )" || return $?
  
    sed -e 's/^\([0-9]\+\).*/\1/' -n -e '1p;$p' <<< "${lines_numbered}" \
    | xargs | tr ' ' ','
  }
  
  _tag_mk_openline() {
    local tag="${1}"
    local prefix="${2}"
    local suffix="${3}"
    printf -- '%s' "${prefix}${tag}${suffix}"
  }
  
  _tag_mk_closeline() {
    local tag="${1}"
    local prefix="${2}"
    local suffix="${3}"
    printf -- '%s' "${prefix}/${tag}${suffix}"
  }
  
  #######################
  ##### RETURN CODE #####
  #######################
  
  rc_add() {
    echo $(( ${1} | ${2} ))
  }
  
  rc_has() {
    [[ $(( ${1} & ${2} )) -eq ${2} ]]
  }
  
  ######################
  ##### VALIDATION #####
  ######################
  
  check_bool() {
    [[ "${1}" =~ ^(true|false)$ ]]
  }
  
  check_unix_login() {
    # https://unix.stackexchange.com/questions/157426/what-is-the-regex-to-validate-linux-users
    local rex='[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)'
    grep -qEx -- "${rex}" <<< "${1}"
  }
  
  check_ip4() {
    local seg_rex='(0|[1-9][0-9]*)'
  
    grep -qxE "(${seg_rex}\.){3}${seg_rex}" <<< "${1}" || return 1
  
    local segments
    mapfile -t segments <<< "$(tr '.' '\n' <<< "${1}")"
    local seg; for seg in "${segments[@]}"; do
      [[ "${seg}" -gt 255 ]] && return 1
    done
  
    return 0
  }
  
  check_loopback_ip4() {
    check_ip4 "${1}" && grep -q '^127' <<< "${1}"
  }
  
  #####################
  ##### PROFILING #####
  #####################
  
  profiler_init() {
    ${PROFILER_ENABLED-false} || return
    [[ -n "${PROFILER_TIMESTAMP}" ]] && return
  
    PROFILER_TIMESTAMP=$(( $(date +%s%N) / 1000000 ))
    export PROFILER_TIMESTAMP
  }
  
  profiler_run() {
    ${PROFILER_ENABLED-false} || return
    [[ -n "${PROFILER_TIMESTAMP}" ]] || return
  
    local message="${1}"
  
    local time=$(( ($(date +%s%N) / 1000000) - ${PROFILER_TIMESTAMP} ))
  
    {
      printf '%6s.%03d' $(( time / 1000 )) $(( time % 1000 ))
      [[ -n "${message}" ]] \
        && printf ' %s\n' "${message}" \
        || printf '\n'
    } | _log_type profile
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
  #   gen_rand [--len LEN] [--num] [--special] [--uc]
  gen_rand() {
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
  #   uniq_ordered [-r] -- FILE...
  #   uniq_ordered [-r] <<< FILE_TEXT
  uniq_ordered() {
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
  #   template_compile [-o] [-f] [-s] [--KEY VALUE...] [--] FILE...
  #   template_compile [-o] [-f] [-s] [--KEY VALUE...] <<< FILE_TEXT
  # Demo:
  #   # outputs: "account=varlog, password=changeme"
  #   template_compile --user varlog --pass changeme \
  #     <<< "login={{ user }}, password={{ pass }}"
  template_compile() {
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
      value="$(sed_quote_replace "${kv["${key}"]}")"
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
        key="$(sed_quote_pattern "${key}")"
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
        key="$(sed_quote_pattern "${key}")"
        expression="{{\s*${key}\s*}}/${kv["${key}"]}"
        ${first} && expression="^${expression}"
        filter+=(-e "s/${expression}/g")
      done
  
      template="$("${filter[@]}" <<< "${template}")"
    fi
  
    [[ -n "${template}" ]] && cat <<< "${template}"
  }
  
  # https://gist.github.com/varlogerr/2c058af053921f1e9a0ddc39ab854577#file-sed-quote
  sed_quote_pattern() {
    sed -e 's/[]\/$*.^[]/\\&/g' <<< "${1-$(cat)}"
  }
  sed_quote_replace() {
    sed -e 's/[\/&]/\\&/g' <<< "${1-$(cat)}"
  }
  
  ##########################
  ##### OVERRIDES DEMO #####
  ##########################
  
  # ## In most cases it's the first candidate for override
  #
  # eval "$(typeset -f file2dest | sed '1s/ \?(/_overriden_ (/')"
  # file2dest() {
  #   # https://unix.stackexchange.com/a/43536
  #   file2dest_overriden_ "${@}" \
  #   2> >(
  #     tee \
  #       >(template_compile -o -f --success 'Success: ' | log_info) \
  #       >(template_compile -o -f --skipped 'Skipped: ' | log_warn) \
  #       >(template_compile -o -f --failed 'Failed: ' | log_err) \
  #       >/dev/null
  #   ) | cat
  #
  #   # https://unix.stackexchange.com/a/73180
  #   return "${PIPESTATUS[0]}"
  # }
  
  # ## A lighter version of tags, less secure, but fine for personal data
  # ## sets. Disregards suffix and prefix, suffix is hardcoded to '#'
  #
  #_tag_mk_openline() { printf -- '%s' "#${1}"; }
  #_tag_mk_closeline() { printf -- '%s' "#${1}"; }
  #_tag_get_lines_range() {
  #  local open="${1}"
  #  local close="${2}"
  #
  #  local lines_numbered
  #  lines_numbered="$(grep -m 2 -n -Fx "${open}" <<< "${text}")" || return $?
  #
  #  sed -e 's/^\([0-9]\+\).*/\1/' -n -e '1p;$p' <<< "${lines_numbered}" \
  #  | xargs | tr ' ' ','
  #}
# {/SHLIB_GEN}


#######################
##### CUSTOM CODE #####
#######################


# {SHLIB_OVERRIDES}
eval "$(typeset -f file2dest | sed '1s/ \?(/_overriden_ (/')"
file2dest() {
  file2dest_overriden_ "${@}" \
  2> >(
    tee \
      >(template_compile -o -f --success 'Success: ' | log_info) \
      >(template_compile -o -f --skipped 'Skipped: ' | log_warn) \
      >(template_compile -o -f --failed 'Failed: ' | log_err) \
      >/dev/null
  ) | cat

  return "${PIPESTATUS[0]}"
}
# {/SHLIB_OVERRIDES}


mkconf_help() {
  text_decore "
    Generate configurations.
   .
    USAGE
    =====
   .  # List modules
   .  ${TOOLNAME} list
   .
   .  # View module help
   .  ${TOOLNAME} MODULE -h
   .
   .  # Run module
   .  ${TOOLNAME} MODULE [MODULE_ARGS]
   .
    MODULES
    =======
  " "$(sed 's/^/* /' <<< "${MODULE_LIST}")"
}

trap_path_force_args() {
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

get_path_force_help_usage() {
  text_decore "
    USAGE
    =====
   .  ${TOOLNAME} ${MODULE} [-f] [--] [DEST...]
  "
}

get_path_force_help_opts() {
  text_decore "
    OPTIONS
    =======
    --            End of options
    -f, --force   Override existing files. Requires DEST
  "
}

get_path_force_help_demo() {
  text_decore "
    DEMO
    ====
   .  # generate to stdout
   .  ${TOOLNAME} ${MODULE}
   .
   .  # generate to multiple destinations
   .  ${TOOLNAME} ${MODULE} file1 file2
  "
}

mkconf_file2dest() {
  local force="${1:-false}"
  local tag_prefix="${2}"
  local source="${3}"
  local -a dests=("${@:4}")
  local -a f2d_opts

  ${force} && f2d_opts+=(--force)
  [[ -n "${tag_prefix}" ]] && f2d_opts+=(
    --tag 'SHLIB_GEN' --tag-prefix "${tag_prefix}"
  )

  file2dest "${f2d_opts[@]}" -- "${source}" "${dests[@]}" || {
    local rc=$?; rc_has $rc 4 \
      && log_err "Can't read source file: ${source}"

    return ${rc}
  }
}

mkconf_trap_help_opt() {
  local help_func="${1}"
  local inval

  inval="$(trap_help_opt "${@:2}")" \
    && { ${help_func}; exit 0; }

  local rc=$?
  [[ $rc -gt 1 ]] && {
    trap_fatal -- ${rc} \
      "Invalid or incompatible arguments:" \
      "$(sed 's/^/* /' <<< "${inval}")"
  }
}
