#!/usr/bin/env bash
# Build and run the authentication test against a throwaway redis-server.
set -euo pipefail
cd "$(dirname "$0")/.."
PORT=6394
lake build auth-test
W="$(mktemp -d)"
redis-server --port $PORT --save '' --appendonly no --dir "$W" --requirepass defaultpw \
  --daemonize yes --logfile "$W/redis.log"
trap 'redis-cli -p $PORT --no-auth-warning -a defaultpw shutdown nosave >/dev/null 2>&1 || true; rm -rf "$W"' EXIT
for i in $(seq 1 50); do redis-cli -p $PORT --no-auth-warning -a defaultpw ping >/dev/null 2>&1 && break; sleep 0.1; done
redis-cli -p $PORT --no-auth-warning -a defaultpw ACL SETUSER alice on '>alicepw' '~*' '&*' '+@all' >/dev/null
redis-cli -p $PORT --no-auth-warning -a defaultpw ACL SETUSER reader on '>readerpw' '~*' '+get' '+acl|whoami' >/dev/null
timeout 60 ./.lake/build/bin/auth-test
