#!/bin/sh
# A fake `gh` for the aws-eval tests: never touches GitHub.
# Appends its arguments to $FAKE_GH_LOG and any --body-file's content to
# $FAKE_GH_LOG.body. `gh issue list` prints $FAKE_GH_LIST (a JSON file) or [].
set -eu

printf '%s\n' "$*" >>"${FAKE_GH_LOG:?}"
prev=""
for arg in "$@"; do
  if [ "${prev}" = "--body-file" ]; then
    cat "${arg}" >>"${FAKE_GH_LOG}.body"
  fi
  prev="${arg}"
done
if [ "${1:-}" = "issue" ] && [ "${2:-}" = "list" ]; then
  if [ -n "${FAKE_GH_LIST:-}" ]; then
    cat "${FAKE_GH_LIST}"
  else
    printf '[]\n'
  fi
fi
