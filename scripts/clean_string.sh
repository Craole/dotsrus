#!/bin/sh

printf '%s' "$1" |
  tr '[:upper:]' '[:lower:]' |
  sed '
      s/[^[:alnum:]]/_/g
      s/_\{2,\}/_/g
      s/^_//
      s/_$//
  '
