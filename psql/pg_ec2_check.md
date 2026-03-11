## pg_ec2_check.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

# PostgreSQL EC2 Health & Logs Checker
# - Detects install method (apt/yum/dnf, likely package names)
# - Checks binaries, service, port/listeners, data dir, config, disk
# - Shows journal / file logs and recent errors
# - Optional: basic local connection check (no password prompt)

RED=$'\033[0;31m'
YEL=$'\033[0;33m'
GRN=$'\033[0;32m'
BLU=$'\033[0;34m'
RST=$'\033[0m'

say()  { printf "%s\n" "$*"; }
hdr()  { printf "\n${BLU}==> %s${RST}\n" "$*"; }
ok()   { printf "${GRN}[OK]${RST} %s\n" "$*"; }
warn() { printf "${YEL}[WARN]${RST} %s\n" "$*"; }
bad()  { printf "${RED}[FAIL]${RST} %s\n" "$*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

OS_ID="unknown"
OS_LIKE="unknown"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_LIKE="${ID_LIKE:-unknown}"
fi

# Helpers to run commands safely
run() {
  local desc="$1"; shift
  hdr "$desc"
  if "$@"; then :; else warn "Command failed: $*"; fi
}

# Try to find postgres-related systemd services
find_pg_services() {
  if ! need_cmd systemctl; then return 0; fi
  # common: postgresql, postgresql@14-main, postgresql-14, etc.
  systemctl list-unit-files --type=service 2>/dev/null \
    | awk '{print $1}' \
    | grep -E '^(postgresql|postgresql@|postgresql-[0-9]+|postgresql-[0-9]+\.service|postgresql\.service)' \
    | sort -u || true
}

# Determine likely log locations
guess_log_paths() {
  local paths=(
    "/var/log/postgresql/postgresql-*.log"
    "/var/log/postgresql/*.log"
    "/var/log/postgresql/postgresql.log"
    "/var/log/pgsql/postgresql*.log"
    "/var/log/pgsql/postgresql/*"
    "/var/log/postgres/postgresql*.log"
    "/var/lib/pgsql/data/log/*"
    "/var/lib/pgsql/*/data/log/*"
    "/var/lib/postgresql/*/main/log/*"
    "/var/lib/postgresql/*/data/log/*"
    "/var/log/messages"
    "/var/log/syslog"
  )
  printf "%s\n" "${paths[@]}"
}

# Find config and data dir using postgres/pg_config when possible
PG_BIN=""
PG_VERSION=""
PG_CONFIG=""
DATA_DIR=""
CONF_FILE=""

detect_pg() {
  if need_cmd psql; then
    PG_BIN="$(command -v psql)"
  elif need_cmd postgres; then
    PG_BIN="$(command -v postgres)"
  fi

  if need_cmd pg_config; then
    PG_CONFIG="$(command -v pg_config)"
    PG_VERSION="$(pg_config --version 2>/dev/null | awk '{print $2}' || true)"
  elif need_cmd psql; then
    PG_VERSION="$(psql --version 2>/dev/null | awk '{print $3}' || true)"
  fi

  # Attempt to find data dir / config via running server (best) or common defaults
  if need_cmd psql; then
    # Try local socket auth; won't prompt for password if peer/trust is configured.
    # If it fails, we still continue.
    DATA_DIR="$(psql -Atqc "show data_directory" 2>/dev/null || true)"
    CONF_FILE="$(psql -Atqc "show config_file" 2>/dev/null || true)"
  fi

  if [[ -z "${DATA_DIR}" ]]; then
    # common defaults
    for d in \
      /var/lib/pgsql/data \
      /var/lib/pgsql/*/data \
      /var/lib/postgresql/*/main \
      /var/lib/postgresql/*/data
    do
      if [[ -d $d ]]; then DATA_DIR="$d"; break; fi
    done
  fi

  if [[ -z "${CONF_FILE}" && -n "${DATA_DIR}" ]]; then
    if [[ -f "${DATA_DIR}/postgresql.conf" ]]; then
      CONF_FILE="${DATA_DIR}/postgresql.conf"
    fi
  fi
}

report_install() {
  hdr "OS Detection"
  say "ID=${OS_ID}  ID_LIKE=${OS_LIKE}"

  hdr "Binary / Version"
  if [[ -n "${PG_BIN}" ]]; then ok "Found PostgreSQL client/server binary: ${PG_BIN}"; else warn "No psql/postgres binary found in PATH"; fi
  if [[ -n "${PG_VERSION}" ]]; then ok "Detected version: ${PG_VERSION}"; else warn "Could not detect PostgreSQL version"; fi

  hdr "Package Check"
  if need_cmd rpm; then
    rpm -qa | grep -Ei '^(postgresql|postgresql[0-9]+|postgresql-server|postgresql-contrib|postgresql-libs)' || warn "No postgres RPM packages found"
  elif need_cmd dpkg; then
    dpkg -l | grep -Ei 'postgresql|postgresql-[0-9]+' || warn "No postgres DEB packages found"
  else
    warn "No rpm/dpkg detected; skipping package inventory"
  fi

  hdr "Service Units"
  if need_cmd systemctl; then
    local svcs
    svcs="$(find_pg_services || true)"
    if [[ -n "$svcs" ]]; then
      say "$svcs"
    else
      warn "No obvious postgresql systemd service units found"
    fi
  else
    warn "systemctl not found (non-systemd or minimal image?)"
  fi
}

check_service_status() {
  hdr "Service Status"
  if need_cmd systemctl; then
    local svcs
    svcs="$(find_pg_services || true)"
    if [[ -z "$svcs" ]]; then
      warn "No postgres service units found to check"
      return 0
    fi
    while read -r svc; do
      [[ -z "$svc" ]] && continue
      say "--- $svc ---"
      if systemctl is-active --quiet "$svc"; then
        ok "$svc is active"
      else
        bad "$svc is NOT active"
      fi
      systemctl --no-pager -l status "$svc" || true
    done <<< "$svcs"
  else
    warn "systemctl not available; trying process check"
    if pgrep -x postgres >/dev/null 2>&1; then ok "postgres process running"; else bad "postgres process not found"; fi
  fi
}

check_ports() {
  hdr "Listening Ports (5432)"
  if need_cmd ss; then
    ss -lntp 2>/dev/null | grep -E ':(5432)\b' || warn "No listener found on TCP/5432 (may be socket-only or different port)"
  elif need_cmd netstat; then
    netstat -lntp 2>/dev/null | grep -E ':(5432)\b' || warn "No listener found on TCP/5432"
  else
    warn "Neither ss nor netstat found"
  fi
}

check_dirs() {
  hdr "Data Directory / Config"
  if [[ -n "${DATA_DIR}" ]]; then
    ok "Data directory: ${DATA_DIR}"
    ls -ld "${DATA_DIR}" || true
  else
    warn "Data directory not detected"
  fi

  if [[ -n "${CONF_FILE}" ]]; then
    ok "Config file: ${CONF_FILE}"
    ls -l "${CONF_FILE}" || true
    hdr "Key settings (listen_addresses, port, logging_collector, log_directory)"
    grep -E '^\s*(listen_addresses|port|logging_collector|log_directory|log_filename|log_destination)\s*=' "${CONF_FILE}" || warn "Could not find those keys in config (may be in includes)"
  else
    warn "Config file not detected"
  fi

  hdr "Disk Space (data dir if known)"
  if [[ -n "${DATA_DIR}" ]]; then
    df -h "${DATA_DIR}" || true
    du -sh "${DATA_DIR}" 2>/dev/null || true
  else
    df -h / || true
  fi
}

check_local_connect() {
  hdr "Local Connection Test (best-effort)"
  if need_cmd psql; then
    # Try a simple query without forcing password prompt.
    if psql -Atqc "select version();" >/dev/null 2>&1; then
      ok "psql local query succeeded"
      psql -Atqc "select now() as server_time, inet_server_addr() as server_addr, inet_server_port() as server_port;" || true
    else
      warn "psql local query failed (auth might require password, or server down, or socket not accessible)"
      say "Tip: try 'sudo -u postgres psql -c \"select 1\"' if peer auth is enabled for postgres user."
    fi
  else
    warn "psql not found; cannot test connection"
  fi
}

show_logs() {
  hdr "Logs (systemd journal) - last 200 lines"
  if need_cmd journalctl; then
    local svcs
    svcs="$(find_pg_services || true)"
    if [[ -n "$svcs" ]]; then
      while read -r svc; do
        [[ -z "$svc" ]] && continue
        say "--- journalctl -u $svc ---"
        journalctl --no-pager -u "$svc" -n 200 2>/dev/null || true
      done <<< "$svcs"
    else
      # Sometimes postgres logs under generic "postgres" or nothing; try a broader grep
      warn "No postgres service units detected; showing last 200 journal lines matching 'postgres'"
      journalctl --no-pager -n 200 2>/dev/null | grep -i postgres || true
    fi
  else
    warn "journalctl not found; skipping journal logs"
  fi

  hdr "Logs (common file locations) - tail + recent errors"
  local found_any=0
  while read -r pattern; do
    # Expand globs
    for f in $pattern; do
      [[ -e "$f" ]] || continue
      found_any=1
      say "--- $f (tail -n 200) ---"
      tail -n 200 "$f" 2>/dev/null || true
      say "--- $f (recent errors/warnings, last 200 matches) ---"
      grep -Eai 'error|fatal|panic|warning' "$f" 2>/dev/null | tail -n 200 || true
    done
  done < <(guess_log_paths)

  if [[ "$found_any" -eq 0 ]]; then
    warn "No PostgreSQL log files found in common locations."
    say "If logging_collector is off, logs may only be in the journal. If on, check log_directory in postgresql.conf."
  fi
}

main() {
  hdr "PostgreSQL EC2 Check"
  detect_pg
  report_install
  check_service_status
  check_ports
  check_dirs
  check_local_connect
  show_logs

  hdr "Quick Summary Hints"
  say "- If service is inactive: check 'systemctl status postgresql*' output above and journal errors."
  say "- If no TCP/5432 listener: check listen_addresses/port and security group/NACL settings."
  say "- If auth fails locally: try 'sudo -u postgres psql' or check pg_hba.conf for local rules."
}

main "$@"
```

### Run it
```bash
chmod +x pg_ec2_check.sh
./pg_ec2_check.sh | tee pg_ec2_check_$(date +%F_%H%M%S).txt
```

## EC2 checks
1) Quick “what am I on?” (optional)
```bash
cat /etc/os-release
```

## 2) Create and run the checker
```bash
cat > pg_ec2_check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; BLU=$'\033[0;34m'; RST=$'\033[0m'
say(){ printf "%s\n" "$*"; }
hdr(){ printf "\n${BLU}==> %s${RST}\n" "$*"; }
ok(){ printf "${GRN}[OK]${RST} %s\n" "$*"; }
warn(){ printf "${YEL}[WARN]${RST} %s\n" "$*"; }
bad(){ printf "${RED}[FAIL]${RST} %s\n" "$*"; }
need_cmd(){ command -v "$1" >/dev/null 2>&1; }

OS_ID="unknown"; OS_LIKE="unknown"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_LIKE="${ID_LIKE:-unknown}"
fi

find_pg_services() {
  need_cmd systemctl || return 0
  systemctl list-unit-files --type=service 2>/dev/null \
    | awk '{print $1}' \
    | grep -E '^(postgresql|postgresql@|postgresql-[0-9]+|postgresql-[0-9]+\.service|postgresql\.service)' \
    | sort -u || true
}

guess_log_paths() {
  local paths=(
    "/var/log/postgresql/postgresql-*.log"
    "/var/log/postgresql/*.log"
    "/var/log/postgresql/postgresql.log"
    "/var/log/pgsql/postgresql*.log"
    "/var/log/pgsql/postgresql/*"
    "/var/log/postgres/postgresql*.log"
    "/var/lib/pgsql/data/log/*"
    "/var/lib/pgsql/*/data/log/*"
    "/var/lib/postgresql/*/main/log/*"
    "/var/lib/postgresql/*/data/log/*"
    "/var/log/messages"
    "/var/log/syslog"
  )
  printf "%s\n" "${paths[@]}"
}

PG_BIN=""; PG_VERSION=""; DATA_DIR=""; CONF_FILE=""

detect_pg() {
  if need_cmd psql; then PG_BIN="$(command -v psql)"
  elif need_cmd postgres; then PG_BIN="$(command -v postgres)"; fi

  if need_cmd pg_config; then
    PG_VERSION="$(pg_config --version 2>/dev/null | awk '{print $2}' || true)"
  elif need_cmd psql; then
    PG_VERSION="$(psql --version 2>/dev/null | awk '{print $3}' || true)"
  fi

  if need_cmd psql; then
    DATA_DIR="$(psql -Atqc "show data_directory" 2>/dev/null || true)"
    CONF_FILE="$(psql -Atqc "show config_file" 2>/dev/null || true)"
  fi

  if [[ -z "${DATA_DIR}" ]]; then
    for d in /var/lib/pgsql/data /var/lib/pgsql/*/data /var/lib/postgresql/*/main /var/lib/postgresql/*/data; do
      [[ -d $d ]] && DATA_DIR="$d" && break
    done
  fi
  if [[ -z "${CONF_FILE}" && -n "${DATA_DIR}" && -f "${DATA_DIR}/postgresql.conf" ]]; then
    CONF_FILE="${DATA_DIR}/postgresql.conf"
  fi
}

report_install() {
  hdr "OS Detection"
  say "ID=${OS_ID}  ID_LIKE=${OS_LIKE}"

  hdr "Binary / Version"
  [[ -n "${PG_BIN}" ]] && ok "Found binary: ${PG_BIN}" || warn "No psql/postgres binary found in PATH"
  [[ -n "${PG_VERSION}" ]] && ok "Detected version: ${PG_VERSION}" || warn "Could not detect PostgreSQL version"

  hdr "Package Check"
  if need_cmd rpm; then
    rpm -qa | grep -Ei '^(postgresql|postgresql[0-9]+|postgresql-server|postgresql-contrib|postgresql-libs)' || warn "No postgres RPM packages found"
  elif need_cmd dpkg; then
    dpkg -l | grep -Ei 'postgresql|postgresql-[0-9]+' || warn "No postgres DEB packages found"
  else
    warn "No rpm/dpkg detected; skipping package inventory"
  fi

  hdr "Service Units"
  if need_cmd systemctl; then
    local svcs; svcs="$(find_pg_services || true)"
    [[ -n "$svcs" ]] && say "$svcs" || warn "No obvious postgresql systemd service units found"
  else
    warn "systemctl not found"
  fi
}

check_service_status() {
  hdr "Service Status"
  if need_cmd systemctl; then
    local svcs; svcs="$(find_pg_services || true)"
    [[ -z "$svcs" ]] && { warn "No postgres service units found to check"; return 0; }
    while read -r svc; do
      [[ -z "$svc" ]] && continue
      say "--- $svc ---"
      systemctl is-active --quiet "$svc" && ok "$svc is active" || bad "$svc is NOT active"
      systemctl --no-pager -l status "$svc" || true
    done <<< "$svcs"
  else
    pgrep -x postgres >/dev/null 2>&1 && ok "postgres process running" || bad "postgres process not found"
  fi
}

check_ports() {
  hdr "Listening Ports (5432)"
  if need_cmd ss; then
    ss -lntp 2>/dev/null | grep -E ':(5432)\b' || warn "No TCP/5432 listener (could be socket-only or different port)"
  elif need_cmd netstat; then
    netstat -lntp 2>/dev/null | grep -E ':(5432)\b' || warn "No TCP/5432 listener"
  else
    warn "Neither ss nor netstat found"
  fi
}

check_dirs() {
  hdr "Data Directory / Config"
  [[ -n "${DATA_DIR}" ]] && { ok "Data directory: ${DATA_DIR}"; ls -ld "${DATA_DIR}" || true; } || warn "Data directory not detected"

  if [[ -n "${CONF_FILE}" ]]; then
    ok "Config file: ${CONF_FILE}"
    ls -l "${CONF_FILE}" || true
    hdr "Key settings (listen_addresses, port, logging_collector, log_directory)"
    grep -E '^\s*(listen_addresses|port|logging_collector|log_directory|log_filename|log_destination)\s*=' "${CONF_FILE}" || warn "Keys not found (may be in include files)"
  else
    warn "Config file not detected"
  fi

  hdr "Disk Space"
  if [[ -n "${DATA_DIR}" ]]; then
    df -h "${DATA_DIR}" || true
    du -sh "${DATA_DIR}" 2>/dev/null || true
  else
    df -h / || true
  fi
}

check_local_connect() {
  hdr "Local Connection Test (best-effort)"
  if need_cmd psql; then
    if psql -Atqc "select version();" >/dev/null 2>&1; then
      ok "psql local query succeeded"
      psql -Atqc "select now() as server_time, inet_server_addr() as server_addr, inet_server_port() as server_port;" || true
    else
      warn "psql local query failed (auth/password/server/socket)"
      say "Try: sudo -u postgres psql -c \"select 1\""
    fi
  else
    warn "psql not found; cannot test connection"
  fi
}

show_logs() {
  hdr "Logs (systemd journal) - last 200 lines"
  if need_cmd journalctl; then
    local svcs; svcs="$(find_pg_services || true)"
    if [[ -n "$svcs" ]]; then
      while read -r svc; do
        [[ -z "$svc" ]] && continue
        say "--- journalctl -u $svc ---"
        journalctl --no-pager -u "$svc" -n 200 2>/dev/null || true
      done <<< "$svcs"
    else
      warn "No postgres units detected; grepping recent journal for 'postgres'"
      journalctl --no-pager -n 300 2>/dev/null | grep -i postgres || true
    fi
  else
    warn "journalctl not found; skipping journal logs"
  fi

  hdr "Logs (common file locations) - tail + recent errors"
  local found_any=0
  while read -r pattern; do
    for f in $pattern; do
      [[ -e "$f" ]] || continue
      found_any=1
      say "--- $f (tail -n 200) ---"
      tail -n 200 "$f" 2>/dev/null || true
      say "--- $f (errors/warnings, last 200 matches) ---"
      grep -Eai 'error|fatal|panic|warning' "$f" 2>/dev/null | tail -n 200 || true
    done
  done < <(guess_log_paths)

  [[ "$found_any" -eq 0 ]] && warn "No PostgreSQL log files found in common locations (may be journal-only)."
}

main() {
  hdr "PostgreSQL EC2 Check"
  detect_pg
  report_install
  check_service_status
  check_ports
  check_dirs
  check_local_connect
  show_logs

  hdr "Fast interpretation"
  say "- FAIL service + journal shows FATAL: usually config/auth/permissions/data-dir issues."
  say "- Service OK but no 5432 listener: listen_addresses/port config or bound to localhost only."
  say "- No packages/binaries: Postgres likely not installed (or installed via container/custom path)."
}

main "$@"
EOF

chmod +x pg_ec2_check.sh
./pg_ec2_check.sh | tee pg_check_$(date +%F_%H%M%S).log
```

## 3) check psql version
```bash
sudo -u postgres psql -c "select version();"
```




