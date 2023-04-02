#!/usr/bin/env bash

_iife_mkconf() {
  unset _iife_mkconf

  declare TOOLPATH="$(realpath -- "${BASH_SOURCE[0]}")"
  declare BINDIR="$(dirname -- "${TOOLPATH}")"
  declare APPDIR="$(realpath -- "${BINDIR}/..")"
  declare LIBDIR="${APPDIR}/lib"
  declare INCDIR="${APPDIR}/inc"
  declare MODDIR="${APPDIR}/module"
  declare TOOLNAME="$(basename -- "${0}")"
  declare MODULE_LIST

  MODULE_LIST="$(
    find "${MODDIR}" -type f -name 'run.sh' \
      -exec dirname -- {} \; \
    | rev | cut -d'/' -f1 | rev | sort -n
  )"

  # if the tool is sourced to bashrc, init environment and exit.
  # pass BASH_SOURCE[0], as it will be first file that will be sourced to .bashrc
  . "${INCDIR}/source-bash.sh" "$(realpath -s -- "${BASH_SOURCE[0]}")" "${@}" && return "${?}"

  # run the app
  . "${INCDIR}/bootstrap.sh"
}; _iife_mkconf "${@}"
