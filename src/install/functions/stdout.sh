#!/usr/bin/env bash

# Logging helpers — Logging levels described by RFC 5424.
# https://github.com/Seldaek/monolog/blob/main/doc/01-usage.md#log-levels

BASH_OVERLAY_LOG_LEVEL_EMERGENCY=600
BASH_OVERLAY_LOG_LEVEL_ALERT=550
BASH_OVERLAY_LOG_LEVEL_CRITICAL=500
BASH_OVERLAY_LOG_LEVEL_ERROR=400
BASH_OVERLAY_LOG_LEVEL_WARNING=300
BASH_OVERLAY_LOG_LEVEL_NOTICE=250
BASH_OVERLAY_LOG_LEVEL_INFO=200
BASH_OVERLAY_LOG_LEVEL_DEBUG=100
BASH_OVERLAY_LOG_LEVEL=${BASH_OVERLAY_LOG_LEVEL:-${BASH_OVERLAY_LOG_LEVEL_DEBUG}}

stdout.log() {
  local ERROR_LEVEL="${1}"
  local MESSAGE="${2}"
  local COLOR

  case ${ERROR_LEVEL} in
    'emergency'|'alert'|'critical'|'error') COLOR=${TEXT_RED} ;;
    'warning')  COLOR=${TEXT_MAGENTA} ;;
    'notice')   COLOR=${TEXT_YELLOW}  ;;
    'success')  COLOR=${TEXT_GREEN}   ;;
    'debug')    COLOR=${TEXT_BLUE}    ;;
    'info')     COLOR=${TEXT_WHITE}   ;;
    *)          COLOR=${TEXT_CLEAR}   ;;
  esac

  echo -e "${COLOR}${MESSAGE}${TEXT_CLEAR}"
}

stdout.emergency() { [[ ${BASH_OVERLAY_LOG_LEVEL} -le ${BASH_OVERLAY_LOG_LEVEL_EMERGENCY} ]] && stdout.log 'emergency' "${1}"; }
stdout.alert()     { [[ ${BASH_OVERLAY_LOG_LEVEL} -le ${BASH_OVERLAY_LOG_LEVEL_ALERT}     ]] && stdout.log 'alert'     "${1}"; }
stdout.critical()  { [[ ${BASH_OVERLAY_LOG_LEVEL} -le ${BASH_OVERLAY_LOG_LEVEL_CRITICAL}  ]] && stdout.log 'critical'  "${1}"; }
stdout.error()     { [[ ${BASH_OVERLAY_LOG_LEVEL} -le ${BASH_OVERLAY_LOG_LEVEL_ERROR}     ]] && stdout.log 'error'     "${1}"; }
stdout.warning()   { [[ ${BASH_OVERLAY_LOG_LEVEL} -le ${BASH_OVERLAY_LOG_LEVEL_WARNING}   ]] && stdout.log 'warning'   "${1}"; }
stdout.notice()    { [[ ${BASH_OVERLAY_LOG_LEVEL} -le ${BASH_OVERLAY_LOG_LEVEL_NOTICE}    ]] && stdout.log 'notice'    "${1}"; }
stdout.info()      { [[ ${BASH_OVERLAY_LOG_LEVEL} -le ${BASH_OVERLAY_LOG_LEVEL_INFO}      ]] && stdout.log 'info'      "${1}"; }
stdout.debug()     { [[ ${BASH_OVERLAY_LOG_LEVEL} -le ${BASH_OVERLAY_LOG_LEVEL_DEBUG}     ]] && stdout.log 'debug'     "${1}"; }
stdout.success()   { stdout.log 'success' "${1}"; }

# Structured output helpers — matching the original script's style
log()    { echo -e "  ${TEXT_GREEN}✔${TEXT_CLEAR}  $1"; }
skip()   { echo -e "  ${TEXT_DIM}–  $1 (already done)${TEXT_CLEAR}"; }
info()   { echo -e "  ${TEXT_BLUE}ℹ${TEXT_CLEAR}  $1"; }
warn()   { echo -e "  ${TEXT_YELLOW}⚠${TEXT_CLEAR}  $1"; }
error()  { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  ERROR: $1"; exit 1; }
header() { echo -e "\n${TEXT_BOLD}${TEXT_BLUE}━━━ $1 ━━━${TEXT_CLEAR}"; }
ask()    { echo -en "  ${TEXT_YELLOW}?${TEXT_CLEAR}  $1 "; }
step()   { echo -e "  ${TEXT_BOLD}→${TEXT_CLEAR}  $1"; }
