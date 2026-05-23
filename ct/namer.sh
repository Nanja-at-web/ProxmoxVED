#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Nanja-at-web
# Co-Author: OpenAI Codex
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/ThePornDatabase/namer

APP="Namer"
APP_PIP_SPEC="${NAMER_PIP_SPEC:-namer}"
NAMER_UPDATE_CHANNEL="${NAMER_UPDATE_CHANNEL:-package}"
var_tags="${var_tags:-media;metadata;python}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-no}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

# Install script lives in our fork, not in upstream community-scripts.
COMMUNITY_SCRIPTS_URL="https://raw.githubusercontent.com/Nanja-at-web/ProxmoxVED/main"

function get_installed_namer_version() {
  /opt/namer/.venv/bin/python - <<'PY'
from importlib.metadata import version

print(version("namer"))
PY
}

function get_latest_namer_release_version() {
  /opt/namer/.venv/bin/python - <<'PY'
import json
from urllib.request import urlopen

with urlopen("https://pypi.org/pypi/namer/json", timeout=10) as response:
    payload = json.load(response)

print(payload["info"]["version"])
PY
}

function version_is_newer() {
  local installed="$1"
  local latest="$2"
  local highest

  highest="$(printf '%s\n%s\n' "${installed}" "${latest}" | sort -V | tail -n1)"
  [[ "${installed}" != "${latest}" && "${highest}" == "${latest}" ]]
}

function stop_namer_service() {
  msg_info "Stopping Service"
  systemctl stop namer-watchdog
  msg_ok "Stopped Service"
}

function backup_namer_config() {
  msg_info "Backing up Configuration"
  cp /etc/namer/namer.cfg /opt/namer.cfg.bak 2>/dev/null || true
  msg_ok "Backed up Configuration"
}

function restore_namer_config() {
  msg_info "Restoring Configuration"
  cp /opt/namer.cfg.bak /etc/namer/namer.cfg 2>/dev/null || true
  rm -f /opt/namer.cfg.bak
  msg_ok "Restored Configuration"
}

function start_namer_service() {
  msg_info "Starting Service"
  systemctl start namer-watchdog
  msg_ok "Started Service"
}

function update_namer_package_channel() {
  local installed_version=""
  local latest_version=""

  msg_info "Checking Installed Version"
  if installed_version="$(get_installed_namer_version 2>/dev/null)"; then
    msg_ok "Installed Version ${installed_version}"
  else
    msg_warn "Could not determine installed ${APP} version; continuing with update check"
  fi

  msg_info "Checking Latest Release"
  if latest_version="$(get_latest_namer_release_version 2>/dev/null)"; then
    msg_ok "Latest Release ${latest_version}"
  else
    msg_warn "Could not determine the latest released ${APP} version; continuing with update attempt"
  fi

  if [[ -n "${installed_version}" && -n "${latest_version}" ]]; then
    if version_is_newer "${installed_version}" "${latest_version}"; then
      msg_info "Update Available ${installed_version} -> ${latest_version}"
    else
      msg_ok "${APP} is already up to date (${installed_version})"
      exit
    fi
  fi

  stop_namer_service
  backup_namer_config

  msg_info "Updating Application Package"
  if command -v uv >/dev/null 2>&1; then
    UPDATE_CMD=(uv pip install --python /opt/namer/.venv/bin/python --upgrade \
      "${APP_PIP_SPEC}")
  else
    UPDATE_CMD=(/opt/namer/.venv/bin/python -m pip install --upgrade \
      "${APP_PIP_SPEC}")
  fi

  if ! "${UPDATE_CMD[@]}"; then
    restore_namer_config
    start_namer_service
    msg_error "Failed to update ${APP} from ${APP_PIP_SPEC}"
    exit 1
  fi
  if installed_version="$(get_installed_namer_version 2>/dev/null)"; then
    msg_ok "Updated Application Package to ${installed_version}"
  else
    msg_ok "Updated Application Package"
  fi

  restore_namer_config
  start_namer_service
  msg_ok "Updated successfully!"
  exit
}

function update_namer_github_channel() {
  msg_error "GitHub channel is reserved for future ProxmoxVED-style release integration"
  exit 1
}

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/namer ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if [[ ! -x /opt/namer/.venv/bin/python ]]; then
    msg_error "No ${APP} virtual environment found at /opt/namer/.venv"
    exit 1
  fi

  case "${NAMER_UPDATE_CHANNEL}" in
    package)
      update_namer_package_channel
      ;;
    github)
      update_namer_github_channel
      ;;
    *)
      msg_error "Unsupported NAMER_UPDATE_CHANNEL: ${NAMER_UPDATE_CHANNEL}"
      exit 1
      ;;
  esac
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:6980${CL}"
