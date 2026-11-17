#!/bin/bash
# Railway wrapper for Sequin. It sets safe defaults for a public URL, creates the
# first admin from SEQUIN_ADMIN_EMAIL / SEQUIN_ADMIN_PASSWORD when the instance has
# no account yet, then runs the image's own start script (migrations, optional
# config file, server).
set -euo pipefail

SEQUIN_BIN=/home/app/prod/rel/sequin/bin/sequin

# Sequin listens on SERVER_PORT; fall back to Railway's PORT, then Sequin's default.
export SERVER_PORT="${SERVER_PORT:-${PORT:-7376}}"
unset PORT

# Defaults for an instance on a public URL (Sequin's configuration docs): no built-in
# default user (it has a well-known password), no open sign-up, origin check on.
export FEATURE_PROVISION_DEFAULT_USER="${FEATURE_PROVISION_DEFAULT_USER:-disabled}"
export FEATURE_ACCOUNT_SELF_SIGNUP="${FEATURE_ACCOUNT_SELF_SIGNUP:-disabled}"
if [ -n "${SERVER_HOST:-}" ]; then
  export SERVER_CHECK_ORIGIN="${SERVER_CHECK_ORIGIN:-true}"
fi
export PG_POOL_SIZE="${PG_POOL_SIZE:-20}"

# Railway's private network is IPv6: connect to a *.railway.internal Postgres over IPv6.
case "${PG_URL:-${PG_HOSTNAME:-}}" in
  *.railway.internal*) export PG_IPV6="${PG_IPV6:-true}" ;;
esac

# Sequin sizes its buffers from MemTotal in /proc/meminfo, which on Railway is the
# host's memory. Use the container's cgroup limit instead, when there is one.
if [ -z "${MAX_MEMORY_MB:-}" ] && [ -r /sys/fs/cgroup/memory.max ]; then
  limit="$(cat /sys/fs/cgroup/memory.max)"
  case "$limit" in
    ''|max|*[!0-9]*) ;;
    *) export MAX_MEMORY_MB="$((limit / 1048576))" ;;
  esac
fi

# VAULT_KEY must be base64 of exactly 32 bytes. Any other value (such as the
# template's generated random string) is turned into one with SHA-256. The result
# is the same on every start, so encrypted credentials stay readable.
if [ -n "${VAULT_KEY:-}" ]; then
  if [ "${#VAULT_KEY}" -ne 44 ] || [ "$(printf '%s' "$VAULT_KEY" | base64 -d 2>/dev/null | wc -c)" -ne 32 ]; then
    VAULT_KEY="$(printf '%s' "$VAULT_KEY" | openssl dgst -sha256 -binary | base64)"
    export VAULT_KEY
  fi
fi

# First admin: only when there is no account yet, so later changes made in the UI
# (password, email, account name) are never overwritten.
if [ -n "${SEQUIN_ADMIN_EMAIL:-}" ] && [ -n "${SEQUIN_ADMIN_PASSWORD:-}" ]; then
  echo "railway-start: running migrations before the first-admin check"
  "$SEQUIN_BIN" eval "Sequin.Release.migrate"
  "$SEQUIN_BIN" eval '
    Application.load(:sequin)
    {:ok, _} = Application.ensure_all_started(:sequin)
    case Sequin.Accounts.list_accounts() do
      [] ->
        email = System.fetch_env!("SEQUIN_ADMIN_EMAIL")
        password = System.fetch_env!("SEQUIN_ADMIN_PASSWORD")
        account = Sequin.Accounts.create_account!(%{name: System.get_env("SEQUIN_ACCOUNT_NAME", "Sequin")})
        case Sequin.Accounts.register_user(:identity, %{email: email, password: password, password_confirmation: password}, account) do
          {:ok, _} -> IO.puts("railway-start: created the first admin user")
          {:error, error} -> raise "railway-start: could not create the first admin: #{inspect(error)}"
        end
      _ ->
        IO.puts("railway-start: an account already exists, first-admin step skipped")
    end
  '
fi

exec /scripts/start_commands.sh
