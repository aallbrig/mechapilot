#!/bin/sh
# A fake `aws` CLI for the aws-eval tests: never touches AWS.
# Logs "<service> <operation>" to $FAKE_AWS_LOG (endpoint env to $FAKE_AWS_LOG.env) and answers from $FAKE_AWS_DIR:
#   <service>/<operation>.<key>.json|.err  (key = slug of --bucket, --id, ... value)
#   <service>/<operation>.json|.err
# A .json file is printed to stdout; a .err file to stderr with exit 254.
# Anything without a canned answer fails, so an unexpected call is visible.
set -eu

while [ "$#" -gt 0 ]; do
  case "$1" in
  --output | --region | --profile) shift 2 ;;
  --*) shift ;;
  *) break ;;
  esac
done
service="${1:?no service}"
operation="${2:?no operation}"
shift 2
printf '%s %s\n' "${service}" "${operation}" >>"${FAKE_AWS_LOG:?}"
# The endpoint-related environment the call saw, for the aws-ro tests.
env | grep -E '^AWS_(ENDPOINT_URL|IGNORE_CONFIGURED_ENDPOINT_URLS)' >>"${FAKE_AWS_LOG}.env" || true

key=""
while [ "$#" -gt 0 ]; do
  case "$1" in
  --bucket | --id | --certificate-arn | --role-name | --hosted-zone-id | --user-name | --group-name)
    key="$(printf '%s' "${2:-}" | tr -c 'A-Za-z0-9._-' '_')"
    shift 2
    ;;
  *) shift ;;
  esac
done

base="${FAKE_AWS_DIR:?}/${service}/${operation}"
for candidate in "${base}.${key}" "${base}"; do
  if [ -f "${candidate}.json" ]; then
    cat "${candidate}.json"
    exit 0
  fi
  if [ -f "${candidate}.err" ]; then
    cat "${candidate}.err" >&2
    exit 254
  fi
done
printf 'fake-aws: no canned answer for %s %s (%s)\n' "${service}" "${operation}" "${key}" >&2
exit 255
