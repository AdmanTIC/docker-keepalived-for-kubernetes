#!/bin/bash
set -e

CHK_URL=$1
ALLOWED_HTTP_CODES=$2

if [ -n "${ALLOWED_HTTP_CODES}" ] ; then
  HTTP_CODE=$(/usr/bin/curl -kso /dev/null -w "%{http_code}" $CHK_URL)
  [[ "$ALLOWED_HTTP_CODES" =~ "$HTTP_CODE" ]]
  exit $?
else
  /usr/bin/curl -fsk $CHK_URL
  exit $?
fi
