#!/bin/bash

_red() {
  printf '\033[1;31;31m%b\033[0m' "$1"
}

_green() {
  printf '\033[1;31;32m%b\033[0m' "$1"
}

_yellow() {
  printf '\033[1;31;33m%b\033[0m' "$1"
}

_printargs() {
  printf -- "%s" "$@"
  printf "\n"
}

_info() {
  _printargs "$1"
}

_warn() {
  _info "$(_yellow "$1")"
}

_succ() {
  _info "$(_green "$1")"
}

_error() {
  _info "$(_red "$1")"
  exit 1
}
