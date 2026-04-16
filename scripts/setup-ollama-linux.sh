#!/usr/bin/env bash
# AUTO-GENERATED — Do not edit. Edit scripts/i18n/ then run: pnpm run build:setup-scripts
#
# Hablará - Ollama Setup Script for Linux
#
# Usage: curl -fsSL https://raw.githubusercontent.com/fidpa/hablara-releases/main/scripts/setup-ollama-linux.sh | bash
#        ./setup-ollama-linux.sh --model 3b
#        ./setup-ollama-linux.sh --diagnose
#
# Exit codes: 0=Success, 1=Error, 2=Disk space, 3=Network, 4=Platform

set -euo pipefail
IFS=$'\n\t'
export LC_NUMERIC=C

# ============================================================================
# Configuration
# ============================================================================

readonly SCRIPT_VERSION="1.7.2"
readonly OLLAMA_API_URL="http://localhost:11434"
readonly OLLAMA_INSTALL_URL="https://ollama.com/install.sh"
readonly MIN_OLLAMA_VERSION="0.3.0"

MODEL_NAME=""
CUSTOM_MODEL_NAME=""
MODEL_SIZE=""
REQUIRED_DISK_SPACE_GB=0
RAM_WARNING=""
FORCE_UPDATE=false
STATUS_CHECK_MODE=false
CLEANUP_MODE=false
DIAGNOSE_MODE=false
LANG_CODE="de"
LANG_CODE_FROM_FLAG=false
MSG_ERROR_PREFIX="Fehler"  # Pre-init for errors before setup_messages()

# Model config lookup (Bash 3.2 compatible - no associative arrays)
# Returns: model_name|download_size|disk_gb|ram_warning_gb
get_model_config() {
  case "${1:-}" in
    1.5b)     echo "qwen2.5:1.5b|~1GB|3|" ;;
    3b)       echo "qwen2.5:3b|~2GB|5|" ;;
    7b)       echo "qwen2.5:7b|~4.7GB|10|" ;;
    qwen3-8b) echo "qwen3:8b|~5.2GB|8|" ;;
    *)        return 1 ;;
  esac
}
readonly DEFAULT_MODEL="3b"

if [[ -t 1 ]]; then
  readonly COLOR_RESET='\033[0m'
  readonly COLOR_GREEN='\033[0;32m'
  readonly COLOR_YELLOW='\033[0;33m'
  readonly COLOR_RED='\033[0;31m'
  readonly COLOR_BLUE='\033[0;34m'
  readonly COLOR_CYAN='\033[0;36m'
else
  readonly COLOR_RESET='' COLOR_GREEN='' COLOR_YELLOW=''
  readonly COLOR_RED='' COLOR_BLUE='' COLOR_CYAN=''
fi

# ============================================================================
# Helper Functions
# ============================================================================

log_step() { echo -e "\n${COLOR_BLUE}==>${COLOR_RESET} ${COLOR_GREEN}${1}${COLOR_RESET}"; }
log_info() { echo -e "    ${COLOR_YELLOW}•${COLOR_RESET} ${1}"; }
log_success() { echo -e "    ${COLOR_GREEN}✓${COLOR_RESET} ${1}"; }
log_warning() { echo -e "    ${COLOR_YELLOW}⚠${COLOR_RESET} ${1}" >&2; }
log_error() { echo -e "${COLOR_RED}✗ ${MSG_ERROR_PREFIX}: ${1}${COLOR_RESET}" >&2; }

# Spinner for long-running operations (TTY-only, CI-safe)
SPINNER_PID=""

spinner_start() {
  [[ -t 1 ]] || return 0
  local msg="${1:-}"
  (
    local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'  # 10 characters (keep i%10 in sync)
    local i=0
    while [[ $i -lt 400 ]]; do  # max ~60s (400 * 0.15s)
      printf '\r    %s %s' "${chars:$((i % 10)):1}" "$msg"
      i=$((i + 1))
      sleep 0.15
    done
  ) &
  SPINNER_PID=$!
}

spinner_stop() {
  if [[ -n "${SPINNER_PID:-}" ]]; then
    kill "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
    [[ -t 1 ]] && printf '\r\033[K'
  fi
}

command_exists() { command -v "$1" &> /dev/null; }

# Script self-reference (handles curl | bash where $0 is "bash")
script_name() {
  local self="${BASH_SOURCE[0]:-}"
  if [[ -n "$self" && -f "$self" ]]; then
    echo "$self"
  else
    echo "./setup-ollama-linux.sh"
  fi
}

# Detect system language from environment (Bash 3.2 compatible, no ${var,,})
detect_system_language() {
  local sys_lang="${LANG:-${LC_ALL:-${LC_MESSAGES:-}}}"
  case "$sys_lang" in
    en*|EN*|En*) echo "en" ;;
    es*|ES*|Es*) echo "es" ;;
    fr*|FR*|Fr*) echo "fr" ;;
    it*|IT*|It*) echo "it" ;;
    nl*|NL*|Nl*) echo "nl" ;;
    pt*|PT*|Pt*) echo "pt" ;;
    pl*|PL*|Pl*) echo "pl" ;;
    sv*|SV*|Sv*) echo "sv" ;;
    da*|DA*|Da*) echo "da" ;;
    *)           echo "de" ;;
  esac
}

# Parse --lang flag from script arguments (sets LANG_CODE + LANG_CODE_FROM_FLAG)
parse_lang_flag() {
  local args=("$@")
  local i=0
  while [[ $i -lt ${#args[@]} ]]; do
    if [[ "${args[$i]}" == "--lang" ]]; then
      if [[ $((i + 1)) -lt ${#args[@]} ]]; then
        local val="${args[$((i+1))]}"
        case "$val" in
          de|DE) LANG_CODE="de"; LANG_CODE_FROM_FLAG=true ;;
          en|EN) LANG_CODE="en"; LANG_CODE_FROM_FLAG=true ;;
          es|ES) LANG_CODE="es"; LANG_CODE_FROM_FLAG=true ;;
          fr|FR) LANG_CODE="fr"; LANG_CODE_FROM_FLAG=true ;;
          it|IT) LANG_CODE="it"; LANG_CODE_FROM_FLAG=true ;;
          nl|NL) LANG_CODE="nl"; LANG_CODE_FROM_FLAG=true ;;
          pt|PT) LANG_CODE="pt"; LANG_CODE_FROM_FLAG=true ;;
          pl|PL) LANG_CODE="pl"; LANG_CODE_FROM_FLAG=true ;;
          sv|SV) LANG_CODE="sv"; LANG_CODE_FROM_FLAG=true ;;
          da|DA) LANG_CODE="da"; LANG_CODE_FROM_FLAG=true ;;
        esac
      fi
      return 0
    fi
    i=$((i + 1))
  done
}

# Prompt user to select language (skips if --lang was given or no TTY)
select_language() {
  [[ "${LANG_CODE_FROM_FLAG}" == "true" ]] && return 0
  if [[ ! -r /dev/tty ]]; then
    LANG_CODE=$(detect_system_language)
    return 0
  fi
  echo "" >&2
  echo "  1) Deutsch" >&2
  echo "  2) English" >&2
  echo "  3) Español" >&2
  echo "  4) Français" >&2
  echo "  5) Italiano" >&2
  echo "  6) Nederlands" >&2
  echo "  7) Português" >&2
  echo "  8) Polski" >&2
  echo "  9) Svenska" >&2
  echo " 10) Dansk" >&2
  echo "" >&2
  echo -n "Sprache / Language / Idioma / Langue / Lingua / Taal / Idioma / Język / Sprog [1-10, Enter=1]: " >&2
  local choice
  read -t 30 -r choice </dev/tty || choice=""
  case "$choice" in
    2)  LANG_CODE="en" ;;
    3)  LANG_CODE="es" ;;
    4)  LANG_CODE="fr" ;;
    5)  LANG_CODE="it" ;;
    6)  LANG_CODE="nl" ;;
    7)  LANG_CODE="pt" ;;
    8)  LANG_CODE="pl" ;;
    9)  LANG_CODE="sv" ;;
    10) LANG_CODE="da" ;;
    *)  LANG_CODE="de" ;;
  esac
}

# printf wrapper for parameterized messages
# Usage: msg "Format string with %s placeholders" arg1 arg2
msg() { local fmt="$1"; shift; printf -- "$fmt" "$@"; }

# Sets all MSG_* variables based on LANG_CODE
setup_messages() {
  case "$LANG_CODE" in
    en)
      MSG_ERROR_PREFIX="Error"
      # Model Menu
      MSG_CHOOSE_MODEL="Choose a model:"
      MSG_CHOICE_PROMPT="Choice [1-4, Enter=1]"
      MSG_MODEL_3B="Optimal overall performance [Default]"
      MSG_MODEL_1_5B="Fast, limited accuracy [Entry-level]"
      MSG_MODEL_7B="Requires high-performance hardware"
      MSG_MODEL_QWEN3="Best argumentation analysis [Premium]"
      # Main Menu
      MSG_CHOOSE_ACTION="Choose an action:"
      MSG_ACTION_SETUP="Set up or update Ollama"
      MSG_ACTION_STATUS="Check status"
      MSG_ACTION_DIAGNOSE="Diagnostics (support report)"
      MSG_ACTION_CLEANUP="Clean up models"
      MSG_ACTION_PROMPT="Choice [1-4, Enter=1]"
      # Select Model / Args
      MSG_OPT_NEEDS_ARG="Option %s requires an argument"
      MSG_UNKNOWN_OPTION="Unknown option: %s"
      MSG_INVALID_MODEL="Invalid model variant: %s"
      MSG_VALID_VARIANTS="Valid variants: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b"
      MSG_RAM_WARN_MODEL="This model recommends at least %sGB RAM"
      MSG_RAM_WARN_SYS="Your system has %sGB RAM"
      MSG_CONTINUE_ANYWAY="Continue anyway?"
      MSG_CONFIRM_PROMPT="[y/N]"
      MSG_CONFIRM_YES='^[yY]$'
      MSG_ABORTED="Aborted."
      MSG_SELECTED_MODEL="Selected model: %s"
      MSG_PROCEED_NONINTERACTIVE="Proceeding..."
      # Preflight
      MSG_PREFLIGHT="Running pre-checks..."
      MSG_PLATFORM_ERROR_MAC="This script is for macOS only"
      MSG_PLATFORM_LINUX_HINT="For Linux: scripts/setup-ollama-linux.sh"
      MSG_PLATFORM_ERROR_LINUX="This script is for Linux only"
      MSG_PLATFORM_MAC_HINT="For macOS: scripts/setup-ollama-mac.sh"
      MSG_TOOL_MISSING="%s missing (please install)"
      MSG_DISK_INSUFFICIENT="Not enough space: %sGB available, %sGB required"
      MSG_DISK_OK="Disk space: %sGB available"
      MSG_NETWORK_ERROR="No network connection to ollama.com"
      MSG_NETWORK_HINT="Check: curl -I https://ollama.com"
      MSG_NETWORK_OK="Network connection OK"
      MSG_GPU_APPLE="Apple Silicon detected (Metal acceleration)"
      MSG_GPU_NVIDIA="NVIDIA GPU detected (CUDA acceleration)"
      MSG_GPU_NONE="No GPU detected - processing without GPU acceleration"
      # Install Ollama
      MSG_INSTALLING_OLLAMA="Installing Ollama..."
      MSG_OLLAMA_ALREADY="Ollama already installed"
      MSG_OLLAMA_VERSION="Version: %s"
      MSG_CHECKING_SERVER="Checking Ollama server..."
      MSG_SERVER_START_FAILED="Could not start Ollama server"
      MSG_SERVER_START_HINT="Start manually: ollama serve"
      MSG_SERVER_RUNNING="Ollama server running"
      MSG_USING_BREW="Using Homebrew (timeout: 10 minutes)..."
      MSG_BREW_TIMEOUT="brew install timeout after 10 minutes"
      MSG_BREW_ALT="Alternative: https://ollama.com/download"
      MSG_BREW_FAILED="Homebrew installation failed"
      MSG_OLLAMA_PATH_ERROR="Ollama installed but CLI not in PATH"
      MSG_PATH_HINT="Restart terminal or check PATH"
      MSG_SERVER_START_WARN="Server start failed - start manually: ollama serve"
      MSG_DOWNLOADING_INSTALLER="Downloading Ollama installer..."
      MSG_INSTALLER_DOWNLOAD_FAILED="Installer download failed"
      MSG_MANUAL_INSTALL="Manual installation: https://ollama.com/download"
      MSG_RUNNING_INSTALLER="Running installer (timeout: 5 minutes)..."
      MSG_INSTALLER_TIMEOUT="Installer timeout after 5 minutes"
      MSG_INSTALL_FAILED="Ollama installation failed"
      MSG_OLLAMA_INSTALLED="Ollama installed"
      MSG_APT_HINT="Install: sudo apt-get install -y curl"
      MSG_OLLAMA_FOUND="Ollama found: %s"
      MSG_OLLAMA_BREW_FOUND="Ollama via Homebrew found: %s"
      MSG_PORT_BUSY="Port 11434 is busy, waiting for Ollama API..."
      MSG_PORT_BUSY_WARN="Port 11434 busy but Ollama API not responding"
      MSG_PORT_CHECK_HINT="Check: lsof -i :11434"
      MSG_VERSION_WARN="Ollama version %s is older than recommended (%s)"
      MSG_UPDATE_HINT_BREW="Update: brew upgrade ollama"
      MSG_UPDATE_HINT_APT="Update: sudo apt-get install ollama"
      # Model Download
      MSG_DOWNLOADING_BASE="Downloading base model..."
      MSG_MODEL_EXISTS="Model already present: %s"
      MSG_DOWNLOADING_MODEL="Downloading %s (%s, takes several minutes depending on connection)..."
      MSG_DOWNLOAD_RESUME_TIP="Tip: If interrupted (Ctrl+C), restarting continues the download"
      MSG_DOWNLOAD_HARD_TIMEOUT="Hard timeout after %s minutes — aborting"
      MSG_DOWNLOAD_STALL="No download progress for %s minutes — aborting"
      MSG_DOWNLOAD_RUNNING="  Download running... (%ss)"
      MSG_DOWNLOAD_TIMEOUT_WARN="Download timeout after %s minutes (attempt %s/3)"
      MSG_DOWNLOAD_FAILED_WARN="Download failed (attempt %s/3)"
      MSG_DOWNLOAD_RETRY="Next attempt in 5s..."
      MSG_DOWNLOAD_FAILED="Model download failed after 3 attempts"
      MSG_DOWNLOAD_MANUAL="Try manually: ollama pull %s"
      MSG_DOWNLOAD_DONE="Model downloaded: %s"
      # Custom Model
      MSG_CREATING_CUSTOM="Creating Hablará model..."
      MSG_UPDATING_CUSTOM="Updating existing Hablará model..."
      MSG_CUSTOM_EXISTS="    • Hablará model %s already present."
      MSG_CUSTOM_SKIP="Skip (no changes)"
      MSG_CUSTOM_UPDATE_OPT="Update Hablará model"
      MSG_CUSTOM_UPDATE_PROMPT="Choice [1-2, Enter=1]"
      MSG_CUSTOM_KEPT="Hablará model kept"
      MSG_CUSTOM_PRESENT="Hablará model already present"
      MSG_USING_HABLARA_CONFIG="Using Hablará configuration"
      MSG_USING_DEFAULT_CONFIG="Using default configuration"
      MSG_CUSTOM_CREATING="Creating Hablará model %s..."
      MSG_CUSTOM_CREATE_TIMEOUT="ollama create timeout after 120s — using base model"
      MSG_CUSTOM_CREATE_FAILED="Hablará model could not be %s - using base model"
      MSG_CUSTOM_DONE="Hablará model %s: %s"
      MSG_VERB_CREATED="created"
      MSG_VERB_UPDATED="updated"
      # Verify
      MSG_VERIFYING="Verifying installation..."
      MSG_OLLAMA_NOT_FOUND="Ollama not found"
      MSG_SERVER_UNREACHABLE="Ollama server not reachable"
      MSG_BASE_NOT_FOUND="Base model not found: %s"
      MSG_BASE_OK="Base model available: %s"
      MSG_CUSTOM_OK="Hablará model available: %s"
      MSG_CUSTOM_UNAVAILABLE="Hablará model unavailable (using base model)"
      MSG_INFERENCE_FAILED="Model test failed, test in the app"
      MSG_SETUP_DONE="Setup complete!"
      # Main Summary
      MSG_SETUP_COMPLETE="Hablará Ollama Setup complete!"
      MSG_INSTALLED="Installed:"
      MSG_BASE_MODEL_LABEL="  Base model:    "
      MSG_HABLARA_MODEL_LABEL="  Hablará model: "
      MSG_OLLAMA_CONFIG="Ollama configuration:"
      MSG_MODEL_LABEL="  Model:    "
      MSG_BASE_URL_LABEL="  Base URL: "
      MSG_DOCS="Documentation: https://github.com/fidpa/hablara"
      # Status
      MSG_STATUS_TITLE_MAC="Hablará Ollama Status (macOS)"
      MSG_STATUS_TITLE_LINUX="Hablará Ollama Status (Linux)"
      MSG_STATUS_INSTALLED="Ollama installed (v%s)"
      MSG_STATUS_UPDATE_REC_BREW="  ↳ Update recommended (minimum v%s): brew upgrade ollama"
      MSG_STATUS_UPDATE_REC_APT="  ↳ Update recommended (minimum v%s): sudo apt-get install ollama"
      MSG_STATUS_NOT_FOUND="Ollama not found"
      MSG_STATUS_SERVER_OK="Server running"
      MSG_STATUS_SERVER_FAIL="Server not reachable"
      MSG_STATUS_GPU_APPLE="GPU: Apple Silicon (Metal acceleration)"
      MSG_STATUS_GPU_NVIDIA="GPU: NVIDIA (CUDA acceleration)"
      MSG_STATUS_NO_GPU="No GPU — processing without GPU acceleration"
      MSG_STATUS_BASE_MODEL="Base model: %s"
      MSG_STATUS_BASE_MODELS="Base models:"
      MSG_STATUS_NO_BASE="No base model found"
      MSG_STATUS_HABLARA_MODEL="Hablará model: %s"
      MSG_STATUS_HABLARA_MODELS="Hablará models:"
      MSG_STATUS_NO_HABLARA="No Hablará model found"
      MSG_STATUS_BASE_MISSING="  ↳ Base model missing — Hablará model requires it as a foundation"
      MSG_STATUS_INFERENCE_SKIP="Model test skipped (server not reachable)"
      MSG_STATUS_MODEL_OK="Model responding"
      MSG_STATUS_MODEL_FAIL="Model not responding"
      MSG_STATUS_STORAGE="Storage usage (Hablará): ~%s GB"
      MSG_STATUS_STORAGE_UNKNOWN="Storage usage: not determinable"
      MSG_STATUS_ALL_OK="Everything is fine."
      MSG_STATUS_PROBLEMS="%s problem(s) found."
      MSG_STATUS_REPAIR="    Repair:"
      # Diagnose
      MSG_DIAGNOSE_TITLE="=== Hablará Ollama Diagnostics Report ==="
      MSG_DIAGNOSE_OS="OS:"
      MSG_DIAGNOSE_RAM="RAM:"
      MSG_DIAGNOSE_RAM_AVAIL="available"
      MSG_DIAGNOSE_STORAGE_FREE="free"
      MSG_DIAGNOSE_SHELL="Shell:"
      MSG_DIAGNOSE_VERSION="Version:"
      MSG_DIAGNOSE_SERVER="Server:"
      MSG_DIAGNOSE_API="API URL:"
      MSG_DIAGNOSE_GPU="GPU:"
      MSG_DIAGNOSE_STORAGE_LABEL="Storage (Hablará):"
      MSG_DIAGNOSE_LOG_LABEL="Ollama Log (recent errors):"
      MSG_DIAGNOSE_DISTRIBUTION="Distribution:"
      MSG_DIAGNOSE_CREATED="Created:"
      MSG_DIAGNOSE_SCRIPT="Script:"
      MSG_DIAGNOSE_SAVED="Report saved: %s"
      MSG_DIAGNOSE_SAVE_FAILED="Could not save report"
      MSG_DIAGNOSE_UNKNOWN="unknown"
      MSG_DIAGNOSE_NOT_INSTALLED="not installed"
      MSG_DIAGNOSE_NOT_REACHABLE="not reachable"
      MSG_DIAGNOSE_RUNNING="running"
      MSG_DIAGNOSE_NO_MODELS="    [no Hablará models found]"
      MSG_DIAGNOSE_NO_ERRORS="    [no errors found]"
      MSG_DIAGNOSE_NO_LOG="    [log file not found: %s]"
      MSG_DIAGNOSE_GPU_APPLE="Apple Silicon (Metal)"
      MSG_DIAGNOSE_GPU_NVIDIA="NVIDIA (CUDA)"
      MSG_DIAGNOSE_GPU_NONE="None"
      MSG_DIAGNOSE_RESPONDS="(responding)"
      MSG_DIAGNOSE_SECTION_SYSTEM="System"
      MSG_DIAGNOSE_SECTION_OLLAMA="Ollama"
      MSG_DIAGNOSE_SECTION_MODELS="Hablará Models"
      MSG_DIAGNOSE_STORAGE_DISK="Storage"
      MSG_DIAGNOSE_GPU_AMD="AMD (ROCm)"
      MSG_DIAGNOSE_GPU_INTEL="Intel (oneAPI)"
      MSG_GPU_STATUS_AMD="GPU: AMD (ROCm acceleration, experimental)"
      MSG_GPU_STATUS_INTEL="GPU: Intel (oneAPI acceleration, experimental)"
      MSG_HOMEBREW_INSTALLED="Ollama installed via Homebrew"
      # Cleanup
      MSG_CLEANUP_NEEDS_TTY="--cleanup requires an interactive session"
      MSG_CLEANUP_NO_OLLAMA="Ollama not found"
      MSG_CLEANUP_NO_SERVER="Ollama server not reachable"
      MSG_CLEANUP_START_HINT="Start Ollama and try again"
      MSG_CLEANUP_INSTALLED="Installed Hablará variants:"
      MSG_CLEANUP_PROMPT="Which variant to delete? (number, Enter=cancel, timeout 60s): "
      MSG_CLEANUP_ENTER_CANCEL="Enter=cancel"
      MSG_CLEANUP_INVALID="Invalid selection"
      MSG_CLEANUP_DELETED="%s deleted"
      MSG_CLEANUP_FAILED="%s could not be deleted: %s"
      MSG_CLEANUP_UNKNOWN_ERR="unknown error"
      MSG_CLEANUP_NONE_LEFT="No Hablará models installed anymore. Run setup again to install a model."
      MSG_CLEANUP_NO_MODELS="No Hablará models found."
      # Misc
      MSG_INTERNAL_ERROR="Internal error: MODEL_NAME not set"
      MSG_TEST_MODEL="Testing model..."
      MSG_TEST_OK="Model test successful"
      MSG_TEST_FAIL="Model test failed"
      MSG_WAIT_SERVER="Waiting for Ollama server..."
      MSG_SERVER_READY="Ollama server is ready"
      MSG_SERVER_NO_RESPONSE="Ollama server not responding after %ss"
      MSG_SETUP_FAILED="Setup failed"
      MSG_OLLAMA_LIST_TIMEOUT="ollama list timeout (15s) during model check"
      # Linux-specific service management
      MSG_SYSTEMD_START="Starting Ollama service..."
      MSG_SYSTEMD_ENABLE="Enabling Ollama service..."
      MSG_SYSTEMD_START_FAIL="Could not start Ollama service"
      MSG_SERVICE_MANUAL="Start manually: ollama serve"
      MSG_LINUX_CURL_INSTALL="Installing curl first..."
      MSG_LINUX_INSTALL_HINT="Install curl: sudo apt-get install -y curl"
      # Server management (start_ollama_server + show_summary)
      MSG_SERVER_ALREADY="Ollama server is already running"
      MSG_PORT_CHECK_HINT_SS="Check: ss -tlnp | grep 11434"
      MSG_SYSTEMD_SYSTEM_ACTIVE="Ollama system service active, waiting for API..."
      MSG_SYSTEMD_SYSTEM_START="Starting Ollama via systemd (system service)..."
      MSG_SYSTEMD_STARTED="Ollama server started (systemd)"
      MSG_SYSTEMD_USER_START="Starting Ollama via systemd (user service)..."
      MSG_NOHUP_START="Starting Ollama server (nohup)..."
      MSG_SERVER_STARTED_PID="Ollama server started (PID: %s)"
      MSG_PROCESS_FAILED="Ollama process failed - Log: %s"
      MSG_PROCESS_START_FAIL="Ollama process could not be started"
      MSG_SERVICE_MANAGEMENT="Service management:"
      MSG_GPU_AMD="AMD GPU detected (experimental)"
      MSG_GPU_INTEL="Intel GPU detected (experimental)"
      # Help
      MSG_HELP_DESCRIPTION="Installs Ollama and configures an optimized Hablará model."
      MSG_HELP_USAGE="Usage:"
      MSG_HELP_OPTS_LABEL="OPTIONS"
      MSG_HELP_OPTIONS="Options:"
      MSG_HELP_OPT_MODEL="  -m, --model VARIANT   Choose model variant: 1.5b, 3b, 7b, qwen3-8b (default: 3b)"
      MSG_HELP_OPT_UPDATE="  --update              Recreate Hablará custom model (update Modelfile)"
      MSG_HELP_OPT_STATUS="  --status              Health check: 7-point Ollama installation check"
      MSG_HELP_OPT_DIAGNOSE="  --diagnose            Generate support report (plain text, copyable)"
      MSG_HELP_OPT_CLEANUP="  --cleanup             Interactively delete installed variant (requires terminal)"
      MSG_HELP_OPT_LANG="  --lang CODE           Language: da (Danish), de (German), en (English), es (Spanish), fr (French), it (Italian), nl (Dutch), pl (Polish), pt (Portuguese), sv (Swedish)"
      MSG_HELP_OPT_HELP="  -h, --help            Show this help"
      MSG_HELP_NO_OPTS="Without options, an interactive menu starts."
      MSG_HELP_VARIANTS="Model variants:"
      MSG_HELP_EXAMPLES="Examples:"
      MSG_HELP_EX_MODEL="--model 3b                          Install 3b variant"
      MSG_HELP_EX_UPDATE="--update                            Update custom model"
      MSG_HELP_EX_STATUS="--status                            Check installation"
      MSG_HELP_EX_DIAGNOSE="--diagnose                          Create bug report"
      MSG_HELP_EX_CLEANUP="--cleanup                           Remove variant"
      MSG_HELP_EX_PIPE="  curl -fsSL URL | bash -s -- -m 3b      Via pipe with argument"
      MSG_HELP_EXIT_CODES="Exit codes:"
      MSG_HELP_EXIT_0="  0  Success"
      MSG_HELP_EXIT_1="  1  General error"
      MSG_HELP_EXIT_2="  2  Not enough disk space"
      MSG_HELP_EXIT_3="  3  No network connection"
      MSG_HELP_EXIT_4="  4  Wrong platform"
      # Hardware Detection
      MSG_HW_DETECTION_HEADER="Hardware detection:"
      MSG_HW_BANDWIDTH="Memory bandwidth: ~%s GB/s · %s GB RAM"
      MSG_HW_RECOMMENDATION="Model recommendation for your hardware:"
      MSG_HW_LOCAL_TOO_SLOW="Local models will be slow on this hardware"
      MSG_HW_CLOUD_HINT="Recommendation: OpenAI or Anthropic API for best experience"
      MSG_HW_PROCEED_LOCAL="Install locally anyway? [y/N]"
      MSG_HW_TAG_RECOMMENDED="recommended"
      MSG_HW_TAG_SLOW="slow"
      MSG_HW_TAG_TOO_SLOW="too slow"
      MSG_CHOICE_PROMPT_HW="Choice [1-4, Enter=%s]"
      MSG_HW_UNKNOWN_CHIP="Unknown processor — no bandwidth recommendation available"
      MSG_HW_MULTI_CALL_HINT="Hablará runs multiple analysis steps per recording"
      # Benchmark
      MSG_BENCH_RESULT="Benchmark: ~%s tok/s with %s"
      MSG_BENCH_EXCELLENT="Excellent — your hardware handles this model with ease"
      MSG_BENCH_GOOD="Good — this model runs well on your hardware"
      MSG_BENCH_MARGINAL="Marginal — consider a smaller model for smoother experience"
      MSG_BENCH_TOO_SLOW="Too slow — a smaller model or cloud provider is recommended"
      MSG_BENCH_SKIP="Benchmark skipped (measurement failed)"
      ;;
    es)
      MSG_ERROR_PREFIX="Error"
      # Model Menu
      MSG_CHOOSE_MODEL="Elige un modelo:"
      MSG_CHOICE_PROMPT="Selección [1-4, Enter=1]"
      MSG_MODEL_3B="Rendimiento general óptimo [Por defecto]"
      MSG_MODEL_1_5B="Rápido, precisión limitada [Básico]"
      MSG_MODEL_7B="Requiere hardware de alto rendimiento"
      MSG_MODEL_QWEN3="Mejor análisis de argumentación [Premium]"
      # Main Menu
      MSG_CHOOSE_ACTION="Elige una acción:"
      MSG_ACTION_SETUP="Instalar o actualizar Ollama"
      MSG_ACTION_STATUS="Comprobar estado"
      MSG_ACTION_DIAGNOSE="Diagnóstico (informe de soporte)"
      MSG_ACTION_CLEANUP="Limpiar modelos"
      MSG_ACTION_PROMPT="Selección [1-4, Enter=1]"
      # Select Model / Args
      MSG_OPT_NEEDS_ARG="La opción %s requiere un argumento"
      MSG_UNKNOWN_OPTION="Opción desconocida: %s"
      MSG_INVALID_MODEL="Variante de modelo no válida: %s"
      MSG_VALID_VARIANTS="Variantes válidas: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b"
      MSG_RAM_WARN_MODEL="Este modelo recomienda al menos %sGB de RAM"
      MSG_RAM_WARN_SYS="Tu sistema tiene %sGB de RAM"
      MSG_CONTINUE_ANYWAY="¿Continuar de todas formas?"
      MSG_CONFIRM_PROMPT="[s/N]"
      MSG_CONFIRM_YES='^[sS]$'
      MSG_ABORTED="Cancelado."
      MSG_SELECTED_MODEL="Modelo seleccionado: %s"
      MSG_PROCEED_NONINTERACTIVE="Continuando..."
      # Preflight
      MSG_PREFLIGHT="Ejecutando comprobaciones previas..."
      MSG_PLATFORM_ERROR_MAC="Este script es solo para macOS"
      MSG_PLATFORM_LINUX_HINT="Para Linux: scripts/setup-ollama-linux.sh"
      MSG_PLATFORM_ERROR_LINUX="Este script es solo para Linux"
      MSG_PLATFORM_MAC_HINT="Para macOS: scripts/setup-ollama-mac.sh"
      MSG_TOOL_MISSING="%s no encontrado (instálalo)"
      MSG_DISK_INSUFFICIENT="Espacio insuficiente: %sGB disponibles, %sGB requeridos"
      MSG_DISK_OK="Espacio en disco: %sGB disponibles"
      MSG_NETWORK_ERROR="Sin conexión de red a ollama.com"
      MSG_NETWORK_HINT="Comprueba: curl -I https://ollama.com"
      MSG_NETWORK_OK="Conexión de red OK"
      MSG_GPU_APPLE="Apple Silicon detectado (aceleración Metal)"
      MSG_GPU_NVIDIA="GPU NVIDIA detectada (aceleración CUDA)"
      MSG_GPU_NONE="Sin GPU detectada - procesamiento sin aceleración GPU"
      # Install Ollama
      MSG_INSTALLING_OLLAMA="Instalando Ollama..."
      MSG_OLLAMA_ALREADY="Ollama ya está instalado"
      MSG_OLLAMA_VERSION="Versión: %s"
      MSG_CHECKING_SERVER="Comprobando servidor Ollama..."
      MSG_SERVER_START_FAILED="No se pudo iniciar el servidor Ollama"
      MSG_SERVER_START_HINT="Iniciar manualmente: ollama serve"
      MSG_SERVER_RUNNING="Servidor Ollama en ejecución"
      MSG_USING_BREW="Usando Homebrew (tiempo límite: 10 minutos)..."
      MSG_BREW_TIMEOUT="brew install superó el tiempo límite de 10 minutos"
      MSG_BREW_ALT="Alternativa: https://ollama.com/download"
      MSG_BREW_FAILED="Instalación con Homebrew fallida"
      MSG_OLLAMA_PATH_ERROR="Ollama instalado, pero CLI no está en PATH"
      MSG_PATH_HINT="Reinicia el terminal o comprueba PATH"
      MSG_SERVER_START_WARN="Inicio del servidor fallido - inicia manualmente: ollama serve"
      MSG_DOWNLOADING_INSTALLER="Descargando instalador de Ollama..."
      MSG_INSTALLER_DOWNLOAD_FAILED="Descarga del instalador fallida"
      MSG_MANUAL_INSTALL="Instalación manual: https://ollama.com/download"
      MSG_RUNNING_INSTALLER="Ejecutando instalador (tiempo límite: 5 minutos)..."
      MSG_INSTALLER_TIMEOUT="Tiempo límite del instalador superado (5 minutos)"
      MSG_INSTALL_FAILED="Instalación de Ollama fallida"
      MSG_OLLAMA_INSTALLED="Ollama instalado"
      MSG_APT_HINT="Instalar: sudo apt-get install -y curl"
      MSG_OLLAMA_FOUND="Ollama encontrado: %s"
      MSG_OLLAMA_BREW_FOUND="Ollama vía Homebrew encontrado: %s"
      MSG_PORT_BUSY="Puerto 11434 ocupado, esperando API de Ollama..."
      MSG_PORT_BUSY_WARN="Puerto 11434 ocupado pero la API de Ollama no responde"
      MSG_PORT_CHECK_HINT="Comprueba: lsof -i :11434"
      MSG_VERSION_WARN="La versión de Ollama %s es anterior a la recomendada (%s)"
      MSG_UPDATE_HINT_BREW="Actualizar: brew upgrade ollama"
      MSG_UPDATE_HINT_APT="Actualizar: sudo apt-get install ollama"
      # Model Download
      MSG_DOWNLOADING_BASE="Descargando modelo base..."
      MSG_MODEL_EXISTS="Modelo ya presente: %s"
      MSG_DOWNLOADING_MODEL="Descargando %s (%s, tarda varios minutos según la conexión)..."
      MSG_DOWNLOAD_RESUME_TIP="Consejo: Si se interrumpe (Ctrl+C), reiniciar continúa la descarga"
      MSG_DOWNLOAD_HARD_TIMEOUT="Tiempo límite absoluto tras %s minutos — cancelando"
      MSG_DOWNLOAD_STALL="Sin progreso en la descarga durante %s minutos — cancelando"
      MSG_DOWNLOAD_RUNNING="  Descargando... (%ss)"
      MSG_DOWNLOAD_TIMEOUT_WARN="Tiempo límite de descarga tras %s minutos (intento %s/3)"
      MSG_DOWNLOAD_FAILED_WARN="Descarga fallida (intento %s/3)"
      MSG_DOWNLOAD_RETRY="Próximo intento en 5s..."
      MSG_DOWNLOAD_FAILED="Descarga del modelo fallida tras 3 intentos"
      MSG_DOWNLOAD_MANUAL="Intenta manualmente: ollama pull %s"
      MSG_DOWNLOAD_DONE="Modelo descargado: %s"
      # Custom Model
      MSG_CREATING_CUSTOM="Creando modelo Hablará..."
      MSG_UPDATING_CUSTOM="Actualizando modelo Hablará existente..."
      MSG_CUSTOM_EXISTS="    • El modelo Hablará %s ya está presente."
      MSG_CUSTOM_SKIP="Omitir (sin cambios)"
      MSG_CUSTOM_UPDATE_OPT="Actualizar modelo Hablará"
      MSG_CUSTOM_UPDATE_PROMPT="Selección [1-2, Enter=1]"
      MSG_CUSTOM_KEPT="Modelo Hablará conservado"
      MSG_CUSTOM_PRESENT="Modelo Hablará ya presente"
      MSG_USING_HABLARA_CONFIG="Usando configuración de Hablará"
      MSG_USING_DEFAULT_CONFIG="Usando configuración por defecto"
      MSG_CUSTOM_CREATING="Creando modelo Hablará %s..."
      MSG_CUSTOM_CREATE_TIMEOUT="ollama create superó el tiempo límite de 120s — usando modelo base"
      MSG_CUSTOM_CREATE_FAILED="El modelo Hablará no pudo ser %s - usando modelo base"
      MSG_CUSTOM_DONE="Modelo Hablará %s: %s"
      MSG_VERB_CREATED="creado"
      MSG_VERB_UPDATED="actualizado"
      # Verify
      MSG_VERIFYING="Verificando instalación..."
      MSG_OLLAMA_NOT_FOUND="Ollama no encontrado"
      MSG_SERVER_UNREACHABLE="Servidor Ollama no accesible"
      MSG_BASE_NOT_FOUND="Modelo base no encontrado: %s"
      MSG_BASE_OK="Modelo base disponible: %s"
      MSG_CUSTOM_OK="Modelo Hablará disponible: %s"
      MSG_CUSTOM_UNAVAILABLE="Modelo Hablará no disponible (usando modelo base)"
      MSG_INFERENCE_FAILED="Prueba del modelo fallida, prueba en la app"
      MSG_SETUP_DONE="¡Configuración completada!"
      # Main Summary
      MSG_SETUP_COMPLETE="¡Configuración Ollama de Hablará completada!"
      MSG_INSTALLED="Instalado:"
      MSG_BASE_MODEL_LABEL="  Modelo base:    "
      MSG_HABLARA_MODEL_LABEL="  Modelo Hablará: "
      MSG_OLLAMA_CONFIG="Configuración de Ollama:"
      MSG_MODEL_LABEL="  Modelo:   "
      MSG_BASE_URL_LABEL="  Base URL: "
      MSG_DOCS="Documentación: https://github.com/fidpa/hablara"
      # Status
      MSG_STATUS_TITLE_MAC="Estado Ollama de Hablará (macOS)"
      MSG_STATUS_TITLE_LINUX="Estado Ollama de Hablará (Linux)"
      MSG_STATUS_INSTALLED="Ollama instalado (v%s)"
      MSG_STATUS_UPDATE_REC_BREW="  ↳ Actualización recomendada (mínimo v%s): brew upgrade ollama"
      MSG_STATUS_UPDATE_REC_APT="  ↳ Actualización recomendada (mínimo v%s): sudo apt-get install ollama"
      MSG_STATUS_NOT_FOUND="Ollama no encontrado"
      MSG_STATUS_SERVER_OK="Servidor en ejecución"
      MSG_STATUS_SERVER_FAIL="Servidor no accesible"
      MSG_STATUS_GPU_APPLE="GPU: Apple Silicon (aceleración Metal)"
      MSG_STATUS_GPU_NVIDIA="GPU: NVIDIA (aceleración CUDA)"
      MSG_STATUS_NO_GPU="Sin GPU — procesamiento sin aceleración GPU"
      MSG_STATUS_BASE_MODEL="Modelo base: %s"
      MSG_STATUS_BASE_MODELS="Modelos base:"
      MSG_STATUS_NO_BASE="Sin modelo base encontrado"
      MSG_STATUS_HABLARA_MODEL="Modelo Hablará: %s"
      MSG_STATUS_HABLARA_MODELS="Modelos Hablará:"
      MSG_STATUS_NO_HABLARA="Sin modelo Hablará encontrado"
      MSG_STATUS_BASE_MISSING="  ↳ Modelo base ausente — el modelo Hablará lo requiere como base"
      MSG_STATUS_INFERENCE_SKIP="Prueba del modelo omitida (servidor no accesible)"
      MSG_STATUS_MODEL_OK="Modelo respondiendo"
      MSG_STATUS_MODEL_FAIL="Modelo no responde"
      MSG_STATUS_STORAGE="Uso de almacenamiento (Hablará): ~%s GB"
      MSG_STATUS_STORAGE_UNKNOWN="Uso de almacenamiento: no determinable"
      MSG_STATUS_ALL_OK="Todo está bien."
      MSG_STATUS_PROBLEMS="%s problema(s) encontrado(s)."
      MSG_STATUS_REPAIR="    Reparar:"
      # Diagnose
      MSG_DIAGNOSE_TITLE="=== Informe de Diagnóstico Ollama de Hablará ==="
      MSG_DIAGNOSE_OS="SO:"
      MSG_DIAGNOSE_RAM="RAM:"
      MSG_DIAGNOSE_RAM_AVAIL="disponible"
      MSG_DIAGNOSE_STORAGE_FREE="libre"
      MSG_DIAGNOSE_SHELL="Shell:"
      MSG_DIAGNOSE_VERSION="Versión:"
      MSG_DIAGNOSE_SERVER="Servidor:"
      MSG_DIAGNOSE_API="URL API:"
      MSG_DIAGNOSE_GPU="GPU:"
      MSG_DIAGNOSE_STORAGE_LABEL="Almacenamiento (Hablará):"
      MSG_DIAGNOSE_LOG_LABEL="Log de Ollama (errores recientes):"
      MSG_DIAGNOSE_DISTRIBUTION="Distribución:"
      MSG_DIAGNOSE_CREATED="Creado:"
      MSG_DIAGNOSE_SCRIPT="Script:"
      MSG_DIAGNOSE_SAVED="Informe guardado: %s"
      MSG_DIAGNOSE_SAVE_FAILED="No se pudo guardar el informe"
      MSG_DIAGNOSE_UNKNOWN="desconocido"
      MSG_DIAGNOSE_NOT_INSTALLED="no instalado"
      MSG_DIAGNOSE_NOT_REACHABLE="no accesible"
      MSG_DIAGNOSE_RUNNING="en ejecución"
      MSG_DIAGNOSE_NO_MODELS="    [sin modelos Hablará encontrados]"
      MSG_DIAGNOSE_NO_ERRORS="    [sin errores encontrados]"
      MSG_DIAGNOSE_NO_LOG="    [archivo de log no encontrado: %s]"
      MSG_DIAGNOSE_GPU_APPLE="Apple Silicon (Metal)"
      MSG_DIAGNOSE_GPU_NVIDIA="NVIDIA (CUDA)"
      MSG_DIAGNOSE_GPU_NONE="Ninguna"
      MSG_DIAGNOSE_RESPONDS="(respondiendo)"
      MSG_DIAGNOSE_SECTION_SYSTEM="Sistema"
      MSG_DIAGNOSE_SECTION_OLLAMA="Ollama"
      MSG_DIAGNOSE_SECTION_MODELS="Modelos Hablará"
      MSG_DIAGNOSE_STORAGE_DISK="Almacenamiento"
      MSG_DIAGNOSE_GPU_AMD="AMD (ROCm)"
      MSG_DIAGNOSE_GPU_INTEL="Intel (oneAPI)"
      MSG_GPU_STATUS_AMD="GPU: AMD (aceleración ROCm, experimental)"
      MSG_GPU_STATUS_INTEL="GPU: Intel (aceleración oneAPI, experimental)"
      MSG_HOMEBREW_INSTALLED="Ollama instalado vía Homebrew"
      # Cleanup
      MSG_CLEANUP_NEEDS_TTY="--cleanup requiere una sesión interactiva"
      MSG_CLEANUP_NO_OLLAMA="Ollama no encontrado"
      MSG_CLEANUP_NO_SERVER="Servidor Ollama no accesible"
      MSG_CLEANUP_START_HINT="Inicia Ollama e inténtalo de nuevo"
      MSG_CLEANUP_INSTALLED="Variantes Hablará instaladas:"
      MSG_CLEANUP_PROMPT="¿Qué variante eliminar? (número, Enter=cancelar, tiempo límite 60s): "
      MSG_CLEANUP_ENTER_CANCEL="Enter=cancelar"
      MSG_CLEANUP_INVALID="Selección no válida"
      MSG_CLEANUP_DELETED="%s eliminado"
      MSG_CLEANUP_FAILED="%s no se pudo eliminar: %s"
      MSG_CLEANUP_UNKNOWN_ERR="error desconocido"
      MSG_CLEANUP_NONE_LEFT="No quedan modelos Hablará instalados. Ejecuta el setup de nuevo para instalar un modelo."
      MSG_CLEANUP_NO_MODELS="No se encontraron modelos Hablará."
      # Misc
      MSG_INTERNAL_ERROR="Error interno: MODEL_NAME no establecido"
      MSG_TEST_MODEL="Probando modelo..."
      MSG_TEST_OK="Prueba del modelo exitosa"
      MSG_TEST_FAIL="Prueba del modelo fallida"
      MSG_WAIT_SERVER="Esperando servidor Ollama..."
      MSG_SERVER_READY="El servidor Ollama está listo"
      MSG_SERVER_NO_RESPONSE="El servidor Ollama no responde tras %ss"
      MSG_SETUP_FAILED="Configuración fallida"
      MSG_OLLAMA_LIST_TIMEOUT="ollama list superó el tiempo límite (15s) durante la comprobación del modelo"
      # Linux-specific service management
      MSG_SYSTEMD_START="Iniciando servicio Ollama..."
      MSG_SYSTEMD_ENABLE="Habilitando servicio Ollama..."
      MSG_SYSTEMD_START_FAIL="No se pudo iniciar el servicio Ollama"
      MSG_SERVICE_MANUAL="Iniciar manualmente: ollama serve"
      MSG_LINUX_CURL_INSTALL="Instalando curl primero..."
      MSG_LINUX_INSTALL_HINT="Instalar curl: sudo apt-get install -y curl"
      # Server management (start_ollama_server + show_summary)
      MSG_SERVER_ALREADY="El servidor Ollama ya está en ejecución"
      MSG_PORT_CHECK_HINT_SS="Comprueba: ss -tlnp | grep 11434"
      MSG_SYSTEMD_SYSTEM_ACTIVE="Servicio del sistema Ollama activo, esperando API..."
      MSG_SYSTEMD_SYSTEM_START="Iniciando Ollama vía systemd (servicio del sistema)..."
      MSG_SYSTEMD_STARTED="Servidor Ollama iniciado (systemd)"
      MSG_SYSTEMD_USER_START="Iniciando Ollama vía systemd (servicio de usuario)..."
      MSG_NOHUP_START="Iniciando servidor Ollama (nohup)..."
      MSG_SERVER_STARTED_PID="Servidor Ollama iniciado (PID: %s)"
      MSG_PROCESS_FAILED="Proceso Ollama fallido - Log: %s"
      MSG_PROCESS_START_FAIL="No se pudo iniciar el proceso Ollama"
      MSG_SERVICE_MANAGEMENT="Gestión del servicio:"
      MSG_GPU_AMD="GPU AMD detectada (experimental)"
      MSG_GPU_INTEL="GPU Intel detectada (experimental)"
      # Help
      MSG_HELP_DESCRIPTION="Instala Ollama y configura un modelo Hablará optimizado."
      MSG_HELP_USAGE="Uso:"
      MSG_HELP_OPTS_LABEL="OPCIONES"
      MSG_HELP_OPTIONS="Opciones:"
      MSG_HELP_OPT_MODEL="  -m, --model VARIANTE  Elegir variante de modelo: 1.5b, 3b, 7b, qwen3-8b (por defecto: 3b)"
      MSG_HELP_OPT_UPDATE="  --update              Recrear modelo personalizado Hablará (actualizar Modelfile)"
      MSG_HELP_OPT_STATUS="  --status              Health check: comprobación de 7 puntos de la instalación de Ollama"
      MSG_HELP_OPT_DIAGNOSE="  --diagnose            Generar informe de soporte (texto plano, copiable)"
      MSG_HELP_OPT_CLEANUP="  --cleanup             Eliminar variante instalada de forma interactiva (requiere terminal)"
      MSG_HELP_OPT_LANG="  --lang CODE           Idioma: da (Danés), de (Alemán), en (Inglés), es (Español), fr (Francés), it (Italiano), nl (Neerlandés), pl (Polaco), pt (Portugués), sv (Sueco)"
      MSG_HELP_OPT_HELP="  -h, --help            Mostrar esta ayuda"
      MSG_HELP_NO_OPTS="Sin opciones, se inicia un menú interactivo."
      MSG_HELP_VARIANTS="Variantes de modelo:"
      MSG_HELP_EXAMPLES="Ejemplos:"
      MSG_HELP_EX_MODEL="--model 3b                          Instalar variante 3b"
      MSG_HELP_EX_UPDATE="--update                            Actualizar modelo personalizado"
      MSG_HELP_EX_STATUS="--status                            Comprobar instalación"
      MSG_HELP_EX_DIAGNOSE="--diagnose                          Crear informe de error"
      MSG_HELP_EX_CLEANUP="--cleanup                           Eliminar variante"
      MSG_HELP_EX_PIPE="  curl -fsSL URL | bash -s -- -m 3b      Vía pipe con argumento"
      MSG_HELP_EXIT_CODES="Códigos de salida:"
      MSG_HELP_EXIT_0="  0  Éxito"
      MSG_HELP_EXIT_1="  1  Error general"
      MSG_HELP_EXIT_2="  2  Espacio en disco insuficiente"
      MSG_HELP_EXIT_3="  3  Sin conexión de red"
      MSG_HELP_EXIT_4="  4  Plataforma incorrecta"
      # Hardware Detection
      MSG_HW_DETECTION_HEADER="Detección de hardware:"
      MSG_HW_BANDWIDTH="Ancho de banda de memoria: ~%s GB/s · %s GB RAM"
      MSG_HW_RECOMMENDATION="Recomendación de modelo para tu hardware:"
      MSG_HW_LOCAL_TOO_SLOW="Los modelos locales serán lentos en este hardware"
      MSG_HW_CLOUD_HINT="Recomendación: API de OpenAI o Anthropic para mejor experiencia"
      MSG_HW_PROCEED_LOCAL="¿Instalar localmente de todos modos? [s/N]"
      MSG_HW_TAG_RECOMMENDED="recomendado"
      MSG_HW_TAG_SLOW="lento"
      MSG_HW_TAG_TOO_SLOW="demasiado lento"
      MSG_CHOICE_PROMPT_HW="Selección [1-4, Enter=%s]"
      MSG_HW_UNKNOWN_CHIP="Procesador desconocido — no se puede recomendar ancho de banda"
      MSG_HW_MULTI_CALL_HINT="Hablará ejecuta múltiples pasos de análisis por grabación"
      # Benchmark
      MSG_BENCH_RESULT="Benchmark: ~%s tok/s con %s"
      MSG_BENCH_EXCELLENT="Excelente — tu hardware maneja este modelo con facilidad"
      MSG_BENCH_GOOD="Bien — este modelo funciona bien en tu hardware"
      MSG_BENCH_MARGINAL="Límite — considera un modelo más pequeño para mayor fluidez"
      MSG_BENCH_TOO_SLOW="Demasiado lento — se recomienda un modelo más pequeño o proveedor en la nube"
      MSG_BENCH_SKIP="Benchmark omitido (medición fallida)"
      ;;
    fr)
      MSG_ERROR_PREFIX="Erreur"
      # Model Menu
      MSG_CHOOSE_MODEL="Choisissez un modèle :"
      MSG_CHOICE_PROMPT="Sélection [1-4, Entrée=1]"
      MSG_MODEL_3B="Performance optimale [Par défaut]"
      MSG_MODEL_1_5B="Rapide, précision limitée [Entrée de gamme]"
      MSG_MODEL_7B="Nécessite du matériel haute performance"
      MSG_MODEL_QWEN3="Meilleure analyse d'argumentation [Premium]"
      # Main Menu
      MSG_CHOOSE_ACTION="Choisissez une action :"
      MSG_ACTION_SETUP="Installer ou mettre à jour Ollama"
      MSG_ACTION_STATUS="Vérifier l'état"
      MSG_ACTION_DIAGNOSE="Diagnostic (rapport d'assistance)"
      MSG_ACTION_CLEANUP="Nettoyer les modèles"
      MSG_ACTION_PROMPT="Sélection [1-4, Entrée=1]"
      # Select Model / Args
      MSG_OPT_NEEDS_ARG="L'option %s nécessite un argument"
      MSG_UNKNOWN_OPTION="Option inconnue : %s"
      MSG_INVALID_MODEL="Variante de modèle invalide : %s"
      MSG_VALID_VARIANTS="Variantes valides : qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b"
      MSG_RAM_WARN_MODEL="Ce modèle recommande au moins %s Go de RAM"
      MSG_RAM_WARN_SYS="Votre système dispose de %s Go de RAM"
      MSG_CONTINUE_ANYWAY="Continuer quand même ?"
      MSG_CONFIRM_PROMPT="[o/N]"
      MSG_CONFIRM_YES='^[oO]$'
      MSG_ABORTED="Annulé."
      MSG_SELECTED_MODEL="Modèle sélectionné : %s"
      MSG_PROCEED_NONINTERACTIVE="Continuation..."
      # Preflight
      MSG_PREFLIGHT="Exécution des vérifications préalables..."
      MSG_PLATFORM_ERROR_MAC="Ce script est uniquement pour macOS"
      MSG_PLATFORM_LINUX_HINT="Pour Linux : scripts/setup-ollama-linux.sh"
      MSG_PLATFORM_ERROR_LINUX="Ce script est uniquement pour Linux"
      MSG_PLATFORM_MAC_HINT="Pour macOS : scripts/setup-ollama-mac.sh"
      MSG_TOOL_MISSING="%s manquant (veuillez l'installer)"
      MSG_DISK_INSUFFICIENT="Espace insuffisant : %s Go disponibles, %s Go requis"
      MSG_DISK_OK="Espace disque : %s Go disponibles"
      MSG_NETWORK_ERROR="Pas de connexion réseau à ollama.com"
      MSG_NETWORK_HINT="Vérifiez : curl -I https://ollama.com"
      MSG_NETWORK_OK="Connexion réseau OK"
      MSG_GPU_APPLE="Apple Silicon détecté (accélération Metal)"
      MSG_GPU_NVIDIA="GPU NVIDIA détecté (accélération CUDA)"
      MSG_GPU_NONE="Aucun GPU détecté - traitement sans accélération GPU"
      # Install Ollama
      MSG_INSTALLING_OLLAMA="Installation d'Ollama..."
      MSG_OLLAMA_ALREADY="Ollama est déjà installé"
      MSG_OLLAMA_VERSION="Version : %s"
      MSG_CHECKING_SERVER="Vérification du serveur Ollama..."
      MSG_SERVER_START_FAILED="Impossible de démarrer le serveur Ollama"
      MSG_SERVER_START_HINT="Démarrer manuellement : ollama serve"
      MSG_SERVER_RUNNING="Serveur Ollama en cours d'exécution"
      MSG_USING_BREW="Utilisation de Homebrew (délai : 10 minutes)..."
      MSG_BREW_TIMEOUT="brew install a dépassé le délai de 10 minutes"
      MSG_BREW_ALT="Alternative : https://ollama.com/download"
      MSG_BREW_FAILED="Échec de l'installation via Homebrew"
      MSG_OLLAMA_PATH_ERROR="Ollama installé, mais CLI introuvable dans le PATH"
      MSG_PATH_HINT="Redémarrez le terminal ou vérifiez le PATH"
      MSG_SERVER_START_WARN="Échec du démarrage du serveur - démarrer manuellement : ollama serve"
      MSG_DOWNLOADING_INSTALLER="Téléchargement de l'installateur Ollama..."
      MSG_INSTALLER_DOWNLOAD_FAILED="Échec du téléchargement de l'installateur"
      MSG_MANUAL_INSTALL="Installation manuelle : https://ollama.com/download"
      MSG_RUNNING_INSTALLER="Exécution de l'installateur (délai : 5 minutes)..."
      MSG_INSTALLER_TIMEOUT="Délai de l'installateur dépassé (5 minutes)"
      MSG_INSTALL_FAILED="Échec de l'installation d'Ollama"
      MSG_OLLAMA_INSTALLED="Ollama installé"
      MSG_APT_HINT="Installer : sudo apt-get install -y curl"
      MSG_OLLAMA_FOUND="Ollama trouvé : %s"
      MSG_OLLAMA_BREW_FOUND="Ollama via Homebrew trouvé : %s"
      MSG_PORT_BUSY="Le port 11434 est occupé, en attente de l'API Ollama..."
      MSG_PORT_BUSY_WARN="Port 11434 occupé mais l'API Ollama ne répond pas"
      MSG_PORT_CHECK_HINT="Vérifiez : lsof -i :11434"
      MSG_VERSION_WARN="La version Ollama %s est plus ancienne que recommandé (%s)"
      MSG_UPDATE_HINT_BREW="Mise à jour : brew upgrade ollama"
      MSG_UPDATE_HINT_APT="Mise à jour : sudo apt-get install ollama"
      # Model Download
      MSG_DOWNLOADING_BASE="Téléchargement du modèle de base..."
      MSG_MODEL_EXISTS="Modèle déjà présent : %s"
      MSG_DOWNLOADING_MODEL="Téléchargement de %s (%s, prend plusieurs minutes selon la connexion)..."
      MSG_DOWNLOAD_RESUME_TIP="Astuce : En cas d'interruption (Ctrl+C), relancer reprend le téléchargement"
      MSG_DOWNLOAD_HARD_TIMEOUT="Délai maximal atteint après %s minutes — annulation"
      MSG_DOWNLOAD_STALL="Aucune progression du téléchargement depuis %s minutes — annulation"
      MSG_DOWNLOAD_RUNNING="  Téléchargement en cours... (%ss)"
      MSG_DOWNLOAD_TIMEOUT_WARN="Délai de téléchargement dépassé après %s minutes (tentative %s/3)"
      MSG_DOWNLOAD_FAILED_WARN="Téléchargement échoué (tentative %s/3)"
      MSG_DOWNLOAD_RETRY="Prochaine tentative dans 5s..."
      MSG_DOWNLOAD_FAILED="Échec du téléchargement du modèle après 3 tentatives"
      MSG_DOWNLOAD_MANUAL="Essayez manuellement : ollama pull %s"
      MSG_DOWNLOAD_DONE="Modèle téléchargé : %s"
      # Custom Model
      MSG_CREATING_CUSTOM="Création du modèle Hablará..."
      MSG_UPDATING_CUSTOM="Mise à jour du modèle Hablará existant..."
      MSG_CUSTOM_EXISTS="    • Le modèle Hablará %s est déjà présent."
      MSG_CUSTOM_SKIP="Ignorer (aucune modification)"
      MSG_CUSTOM_UPDATE_OPT="Mettre à jour le modèle Hablará"
      MSG_CUSTOM_UPDATE_PROMPT="Sélection [1-2, Entrée=1]"
      MSG_CUSTOM_KEPT="Modèle Hablará conservé"
      MSG_CUSTOM_PRESENT="Modèle Hablará déjà présent"
      MSG_USING_HABLARA_CONFIG="Utilisation de la configuration Hablará"
      MSG_USING_DEFAULT_CONFIG="Utilisation de la configuration par défaut"
      MSG_CUSTOM_CREATING="Création du modèle Hablará %s..."
      MSG_CUSTOM_CREATE_TIMEOUT="ollama create a dépassé le délai de 120s — utilisation du modèle de base"
      MSG_CUSTOM_CREATE_FAILED="Le modèle Hablará n'a pas pu être %s - utilisation du modèle de base"
      MSG_CUSTOM_DONE="Modèle Hablará %s : %s"
      MSG_VERB_CREATED="créé"
      MSG_VERB_UPDATED="mis à jour"
      # Verify
      MSG_VERIFYING="Vérification de l'installation..."
      MSG_OLLAMA_NOT_FOUND="Ollama introuvable"
      MSG_SERVER_UNREACHABLE="Serveur Ollama inaccessible"
      MSG_BASE_NOT_FOUND="Modèle de base introuvable : %s"
      MSG_BASE_OK="Modèle de base disponible : %s"
      MSG_CUSTOM_OK="Modèle Hablará disponible : %s"
      MSG_CUSTOM_UNAVAILABLE="Modèle Hablará indisponible (utilisation du modèle de base)"
      MSG_INFERENCE_FAILED="Test du modèle échoué, testez dans l'application"
      MSG_SETUP_DONE="Configuration terminée !"
      # Main Summary
      MSG_SETUP_COMPLETE="Configuration Ollama Hablará terminée !"
      MSG_INSTALLED="Installé :"
      MSG_BASE_MODEL_LABEL="  Modèle de base :  "
      MSG_HABLARA_MODEL_LABEL="  Modèle Hablará :  "
      MSG_OLLAMA_CONFIG="Configuration Ollama :"
      MSG_MODEL_LABEL="  Modèle :   "
      MSG_BASE_URL_LABEL="  Base URL : "
      MSG_DOCS="Documentation : https://github.com/fidpa/hablara"
      # Status
      MSG_STATUS_TITLE_MAC="État Ollama Hablará (macOS)"
      MSG_STATUS_TITLE_LINUX="État Ollama Hablará (Linux)"
      MSG_STATUS_INSTALLED="Ollama installé (v%s)"
      MSG_STATUS_UPDATE_REC_BREW="  ↳ Mise à jour recommandée (minimum v%s) : brew upgrade ollama"
      MSG_STATUS_UPDATE_REC_APT="  ↳ Mise à jour recommandée (minimum v%s) : sudo apt-get install ollama"
      MSG_STATUS_NOT_FOUND="Ollama introuvable"
      MSG_STATUS_SERVER_OK="Serveur en cours d'exécution"
      MSG_STATUS_SERVER_FAIL="Serveur inaccessible"
      MSG_STATUS_GPU_APPLE="GPU : Apple Silicon (accélération Metal)"
      MSG_STATUS_GPU_NVIDIA="GPU : NVIDIA (accélération CUDA)"
      MSG_STATUS_NO_GPU="Aucun GPU — traitement sans accélération GPU"
      MSG_STATUS_BASE_MODEL="Modèle de base : %s"
      MSG_STATUS_BASE_MODELS="Modèles de base :"
      MSG_STATUS_NO_BASE="Aucun modèle de base trouvé"
      MSG_STATUS_HABLARA_MODEL="Modèle Hablará : %s"
      MSG_STATUS_HABLARA_MODELS="Modèles Hablará :"
      MSG_STATUS_NO_HABLARA="Aucun modèle Hablará trouvé"
      MSG_STATUS_BASE_MISSING="  ↳ Modèle de base manquant — le modèle Hablará en a besoin comme base"
      MSG_STATUS_INFERENCE_SKIP="Test du modèle ignoré (serveur inaccessible)"
      MSG_STATUS_MODEL_OK="Modèle répond"
      MSG_STATUS_MODEL_FAIL="Modèle ne répond pas"
      MSG_STATUS_STORAGE="Utilisation du stockage (Hablará) : ~%s Go"
      MSG_STATUS_STORAGE_UNKNOWN="Utilisation du stockage : indéterminable"
      MSG_STATUS_ALL_OK="Tout est en ordre."
      MSG_STATUS_PROBLEMS="%s problème(s) trouvé(s)."
      MSG_STATUS_REPAIR="    Réparer :"
      # Diagnose
      MSG_DIAGNOSE_TITLE="=== Rapport de Diagnostic Ollama Hablará ==="
      MSG_DIAGNOSE_OS="OS :"
      MSG_DIAGNOSE_RAM="RAM :"
      MSG_DIAGNOSE_RAM_AVAIL="disponible"
      MSG_DIAGNOSE_STORAGE_FREE="libre"
      MSG_DIAGNOSE_SHELL="Shell :"
      MSG_DIAGNOSE_VERSION="Version :"
      MSG_DIAGNOSE_SERVER="Serveur :"
      MSG_DIAGNOSE_API="URL API :"
      MSG_DIAGNOSE_GPU="GPU :"
      MSG_DIAGNOSE_STORAGE_LABEL="Stockage (Hablará) :"
      MSG_DIAGNOSE_LOG_LABEL="Journal Ollama (erreurs récentes) :"
      MSG_DIAGNOSE_DISTRIBUTION="Distribution :"
      MSG_DIAGNOSE_CREATED="Créé :"
      MSG_DIAGNOSE_SCRIPT="Script :"
      MSG_DIAGNOSE_SAVED="Rapport enregistré : %s"
      MSG_DIAGNOSE_SAVE_FAILED="Impossible d'enregistrer le rapport"
      MSG_DIAGNOSE_UNKNOWN="inconnu"
      MSG_DIAGNOSE_NOT_INSTALLED="non installé"
      MSG_DIAGNOSE_NOT_REACHABLE="inaccessible"
      MSG_DIAGNOSE_RUNNING="en cours d'exécution"
      MSG_DIAGNOSE_NO_MODELS="    [aucun modèle Hablará trouvé]"
      MSG_DIAGNOSE_NO_ERRORS="    [aucune erreur trouvée]"
      MSG_DIAGNOSE_NO_LOG="    [fichier journal introuvable : %s]"
      MSG_DIAGNOSE_GPU_APPLE="Apple Silicon (Metal)"
      MSG_DIAGNOSE_GPU_NVIDIA="NVIDIA (CUDA)"
      MSG_DIAGNOSE_GPU_NONE="Aucun"
      MSG_DIAGNOSE_RESPONDS="(répond)"
      MSG_DIAGNOSE_SECTION_SYSTEM="Système"
      MSG_DIAGNOSE_SECTION_OLLAMA="Ollama"
      MSG_DIAGNOSE_SECTION_MODELS="Modèles Hablará"
      MSG_DIAGNOSE_STORAGE_DISK="Stockage"
      MSG_DIAGNOSE_GPU_AMD="AMD (ROCm)"
      MSG_DIAGNOSE_GPU_INTEL="Intel (oneAPI)"
      MSG_GPU_STATUS_AMD="GPU : AMD (accélération ROCm, expérimental)"
      MSG_GPU_STATUS_INTEL="GPU : Intel (accélération oneAPI, expérimental)"
      MSG_HOMEBREW_INSTALLED="Ollama installé via Homebrew"
      # Cleanup
      MSG_CLEANUP_NEEDS_TTY="--cleanup nécessite une session interactive"
      MSG_CLEANUP_NO_OLLAMA="Ollama introuvable"
      MSG_CLEANUP_NO_SERVER="Serveur Ollama inaccessible"
      MSG_CLEANUP_START_HINT="Démarrez Ollama et réessayez"
      MSG_CLEANUP_INSTALLED="Variantes Hablará installées :"
      MSG_CLEANUP_PROMPT="Quelle variante supprimer ? (numéro, Entrée=annuler, délai 60s) : "
      MSG_CLEANUP_ENTER_CANCEL="Entrée=annuler"
      MSG_CLEANUP_INVALID="Sélection invalide"
      MSG_CLEANUP_DELETED="%s supprimé"
      MSG_CLEANUP_FAILED="%s n'a pas pu être supprimé : %s"
      MSG_CLEANUP_UNKNOWN_ERR="erreur inconnue"
      MSG_CLEANUP_NONE_LEFT="Aucun modèle Hablará installé. Relancez le setup pour installer un modèle."
      MSG_CLEANUP_NO_MODELS="Aucun modèle Hablará trouvé."
      # Misc
      MSG_INTERNAL_ERROR="Erreur interne : MODEL_NAME non défini"
      MSG_TEST_MODEL="Test du modèle..."
      MSG_TEST_OK="Test du modèle réussi"
      MSG_TEST_FAIL="Test du modèle échoué"
      MSG_WAIT_SERVER="En attente du serveur Ollama..."
      MSG_SERVER_READY="Le serveur Ollama est prêt"
      MSG_SERVER_NO_RESPONSE="Le serveur Ollama ne répond pas après %ss"
      MSG_SETUP_FAILED="Échec de la configuration"
      MSG_OLLAMA_LIST_TIMEOUT="ollama list a dépassé le délai (15s) lors de la vérification du modèle"
      # Linux-specific service management
      MSG_SYSTEMD_START="Démarrage du service Ollama..."
      MSG_SYSTEMD_ENABLE="Activation du service Ollama..."
      MSG_SYSTEMD_START_FAIL="Impossible de démarrer le service Ollama"
      MSG_SERVICE_MANUAL="Démarrer manuellement : ollama serve"
      MSG_LINUX_CURL_INSTALL="Installation de curl d'abord..."
      MSG_LINUX_INSTALL_HINT="Installer curl : sudo apt-get install -y curl"
      # Server management (start_ollama_server + show_summary)
      MSG_SERVER_ALREADY="Le serveur Ollama est déjà en cours d'exécution"
      MSG_PORT_CHECK_HINT_SS="Vérifiez : ss -tlnp | grep 11434"
      MSG_SYSTEMD_SYSTEM_ACTIVE="Service système Ollama actif, en attente de l'API..."
      MSG_SYSTEMD_SYSTEM_START="Démarrage d'Ollama via systemd (service système)..."
      MSG_SYSTEMD_STARTED="Serveur Ollama démarré (systemd)"
      MSG_SYSTEMD_USER_START="Démarrage d'Ollama via systemd (service utilisateur)..."
      MSG_NOHUP_START="Démarrage du serveur Ollama (nohup)..."
      MSG_SERVER_STARTED_PID="Serveur Ollama démarré (PID : %s)"
      MSG_PROCESS_FAILED="Processus Ollama échoué - Journal : %s"
      MSG_PROCESS_START_FAIL="Impossible de démarrer le processus Ollama"
      MSG_SERVICE_MANAGEMENT="Gestion du service :"
      MSG_GPU_AMD="GPU AMD détecté (expérimental)"
      MSG_GPU_INTEL="GPU Intel détecté (expérimental)"
      # Help
      MSG_HELP_DESCRIPTION="Installe Ollama et configure un modèle Hablará optimisé."
      MSG_HELP_USAGE="Utilisation :"
      MSG_HELP_OPTS_LABEL="OPTIONS"
      MSG_HELP_OPTIONS="Options :"
      MSG_HELP_OPT_MODEL="  -m, --model VARIANTE  Choisir la variante : 1.5b, 3b, 7b, qwen3-8b (par défaut : 3b)"
      MSG_HELP_OPT_UPDATE="  --update              Recréer le modèle Hablará (mettre à jour le Modelfile)"
      MSG_HELP_OPT_STATUS="  --status              Vérification : contrôle en 7 points de l'installation Ollama"
      MSG_HELP_OPT_DIAGNOSE="  --diagnose            Générer un rapport d'assistance (texte brut, copiable)"
      MSG_HELP_OPT_CLEANUP="  --cleanup             Supprimer interactivement une variante installée (nécessite un terminal)"
      MSG_HELP_OPT_LANG="  --lang CODE           Langue : da (Danois), de (Allemand), en (Anglais), es (Espagnol), fr (Français), it (Italien), nl (Néerlandais), pl (Polonais), pt (Portugais), sv (Suédois)"
      MSG_HELP_OPT_HELP="  -h, --help            Afficher cette aide"
      MSG_HELP_NO_OPTS="Sans options, un menu interactif démarre."
      MSG_HELP_VARIANTS="Variantes de modèle :"
      MSG_HELP_EXAMPLES="Exemples :"
      MSG_HELP_EX_MODEL="--model 3b                          Installer la variante 3b"
      MSG_HELP_EX_UPDATE="--update                            Mettre à jour le modèle personnalisé"
      MSG_HELP_EX_STATUS="--status                            Vérifier l'installation"
      MSG_HELP_EX_DIAGNOSE="--diagnose                          Créer un rapport de bug"
      MSG_HELP_EX_CLEANUP="--cleanup                           Supprimer une variante"
      MSG_HELP_EX_PIPE="  curl -fsSL URL | bash -s -- -m 3b      Via pipe avec argument"
      MSG_HELP_EXIT_CODES="Codes de sortie :"
      MSG_HELP_EXIT_0="  0  Succès"
      MSG_HELP_EXIT_1="  1  Erreur générale"
      MSG_HELP_EXIT_2="  2  Espace disque insuffisant"
      MSG_HELP_EXIT_3="  3  Pas de connexion réseau"
      MSG_HELP_EXIT_4="  4  Mauvaise plateforme"
      # Hardware Detection
      MSG_HW_DETECTION_HEADER="Détection matérielle :"
      MSG_HW_BANDWIDTH="Bande passante mémoire : ~%s Go/s · %s Go RAM"
      MSG_HW_RECOMMENDATION="Recommandation de modèle pour votre matériel :"
      MSG_HW_LOCAL_TOO_SLOW="Les modèles locaux seront lents sur ce matériel"
      MSG_HW_CLOUD_HINT="Recommandation : API OpenAI ou Anthropic pour la meilleure expérience"
      MSG_HW_PROCEED_LOCAL="Installer localement quand même ? [o/N]"
      MSG_HW_TAG_RECOMMENDED="recommandé"
      MSG_HW_TAG_SLOW="lent"
      MSG_HW_TAG_TOO_SLOW="trop lent"
      MSG_CHOICE_PROMPT_HW="Choix [1-4, Entrée=%s]"
      MSG_HW_UNKNOWN_CHIP="Processeur inconnu — pas de recommandation de bande passante possible"
      MSG_HW_MULTI_CALL_HINT="Hablará exécute plusieurs étapes d'analyse par enregistrement"
      # Benchmark
      MSG_BENCH_RESULT="Benchmark : ~%s tok/s avec %s"
      MSG_BENCH_EXCELLENT="Excellent — votre matériel gère ce modèle sans effort"
      MSG_BENCH_GOOD="Bon — ce modèle fonctionne bien sur votre matériel"
      MSG_BENCH_MARGINAL="Marginal — un modèle plus petit offre une meilleure fluidité"
      MSG_BENCH_TOO_SLOW="Trop lent — un modèle plus petit ou un fournisseur cloud est recommandé"
      MSG_BENCH_SKIP="Benchmark ignoré (mesure échouée)"
      ;;
    it)
      MSG_ERROR_PREFIX="Errore"
      # Model Menu
      MSG_CHOOSE_MODEL="Scegli un modello:"
      MSG_CHOICE_PROMPT="Selezione [1-4, Invio=1]"
      MSG_MODEL_3B="Prestazioni generali ottimali [Predefinito]"
      MSG_MODEL_1_5B="Veloce, precisione limitata [Base]"
      MSG_MODEL_7B="Richiede hardware ad alte prestazioni"
      MSG_MODEL_QWEN3="Migliore analisi dell'argomentazione [Premium]"
      # Main Menu
      MSG_CHOOSE_ACTION="Scegli un'azione:"
      MSG_ACTION_SETUP="Installare o aggiornare Ollama"
      MSG_ACTION_STATUS="Controlla lo stato"
      MSG_ACTION_DIAGNOSE="Diagnostica (rapporto di supporto)"
      MSG_ACTION_CLEANUP="Pulisci i modelli"
      MSG_ACTION_PROMPT="Selezione [1-4, Invio=1]"
      # Select Model / Args
      MSG_OPT_NEEDS_ARG="L'opzione %s richiede un argomento"
      MSG_UNKNOWN_OPTION="Opzione sconosciuta: %s"
      MSG_INVALID_MODEL="Variante di modello non valida: %s"
      MSG_VALID_VARIANTS="Varianti valide: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b"
      MSG_RAM_WARN_MODEL="Questo modello richiede almeno %sGB di RAM"
      MSG_RAM_WARN_SYS="Il tuo sistema ha %sGB di RAM"
      MSG_CONTINUE_ANYWAY="Continuare comunque?"
      MSG_CONFIRM_PROMPT="[s/N]"
      MSG_CONFIRM_YES='^[sS]$'
      MSG_ABORTED="Annullato."
      MSG_SELECTED_MODEL="Modello selezionato: %s"
      MSG_PROCEED_NONINTERACTIVE="Continuo..."
      # Preflight
      MSG_PREFLIGHT="Esecuzione dei controlli preliminari..."
      MSG_PLATFORM_ERROR_MAC="Questo script è solo per macOS"
      MSG_PLATFORM_LINUX_HINT="Per Linux: scripts/setup-ollama-linux.sh"
      MSG_PLATFORM_ERROR_LINUX="Questo script è solo per Linux"
      MSG_PLATFORM_MAC_HINT="Per macOS: scripts/setup-ollama-mac.sh"
      MSG_TOOL_MISSING="%s mancante (si prega di installarlo)"
      MSG_DISK_INSUFFICIENT="Spazio insufficiente: %sGB disponibili, %sGB richiesti"
      MSG_DISK_OK="Spazio su disco: %sGB disponibili"
      MSG_NETWORK_ERROR="Nessuna connessione di rete a ollama.com"
      MSG_NETWORK_HINT="Verifica: curl -I https://ollama.com"
      MSG_NETWORK_OK="Connessione di rete OK"
      MSG_GPU_APPLE="Apple Silicon rilevato (accelerazione Metal)"
      MSG_GPU_NVIDIA="GPU NVIDIA rilevata (accelerazione CUDA)"
      MSG_GPU_NONE="Nessuna GPU rilevata - elaborazione senza accelerazione GPU"
      # Install Ollama
      MSG_INSTALLING_OLLAMA="Installazione di Ollama..."
      MSG_OLLAMA_ALREADY="Ollama è già installato"
      MSG_OLLAMA_VERSION="Versione: %s"
      MSG_CHECKING_SERVER="Controllo del server Ollama..."
      MSG_SERVER_START_FAILED="Impossibile avviare il server Ollama"
      MSG_SERVER_START_HINT="Avviare manualmente: ollama serve"
      MSG_SERVER_RUNNING="Server Ollama in esecuzione"
      MSG_USING_BREW="Utilizzo di Homebrew (tempo massimo: 10 minuti)..."
      MSG_BREW_TIMEOUT="brew install ha superato il tempo massimo di 10 minuti"
      MSG_BREW_ALT="Alternativa: https://ollama.com/download"
      MSG_BREW_FAILED="Installazione con Homebrew fallita"
      MSG_OLLAMA_PATH_ERROR="Ollama installato, ma CLI non è nel PATH"
      MSG_PATH_HINT="Riavviare il terminale o verificare il PATH"
      MSG_SERVER_START_WARN="Avvio del server fallito - avviare manualmente: ollama serve"
      MSG_DOWNLOADING_INSTALLER="Scaricamento del programma di installazione Ollama..."
      MSG_INSTALLER_DOWNLOAD_FAILED="Scaricamento del programma di installazione fallito"
      MSG_MANUAL_INSTALL="Installazione manuale: https://ollama.com/download"
      MSG_RUNNING_INSTALLER="Esecuzione del programma di installazione (tempo massimo: 5 minuti)..."
      MSG_INSTALLER_TIMEOUT="Tempo massimo del programma di installazione superato (5 minuti)"
      MSG_INSTALL_FAILED="Installazione di Ollama fallita"
      MSG_OLLAMA_INSTALLED="Ollama installato"
      MSG_APT_HINT="Installare: sudo apt-get install -y curl"
      MSG_OLLAMA_FOUND="Ollama trovato: %s"
      MSG_OLLAMA_BREW_FOUND="Ollama via Homebrew trovato: %s"
      MSG_PORT_BUSY="La porta 11434 è occupata, in attesa dell'API Ollama..."
      MSG_PORT_BUSY_WARN="Porta 11434 occupata ma l'API Ollama non risponde"
      MSG_PORT_CHECK_HINT="Verifica: lsof -i :11434"
      MSG_VERSION_WARN="La versione Ollama %s è precedente a quella raccomandata (%s)"
      MSG_UPDATE_HINT_BREW="Aggiornare: brew upgrade ollama"
      MSG_UPDATE_HINT_APT="Aggiornare: sudo apt-get install ollama"
      # Model Download
      MSG_DOWNLOADING_BASE="Scaricamento del modello base..."
      MSG_MODEL_EXISTS="Modello già presente: %s"
      MSG_DOWNLOADING_MODEL="Scaricamento di %s (%s, richiede diversi minuti a seconda della connessione)..."
      MSG_DOWNLOAD_RESUME_TIP="Suggerimento: Se interrotto (Ctrl+C), riavviare continua lo scaricamento"
      MSG_DOWNLOAD_HARD_TIMEOUT="Tempo massimo superato dopo %s minuti — interruzione"
      MSG_DOWNLOAD_STALL="Nessun progresso nello scaricamento per %s minuti — interruzione"
      MSG_DOWNLOAD_RUNNING="  Scaricamento in corso... (%ss)"
      MSG_DOWNLOAD_TIMEOUT_WARN="Tempo massimo di scaricamento superato dopo %s minuti (tentativo %s/3)"
      MSG_DOWNLOAD_FAILED_WARN="Scaricamento fallito (tentativo %s/3)"
      MSG_DOWNLOAD_RETRY="Prossimo tentativo tra 5s..."
      MSG_DOWNLOAD_FAILED="Scaricamento del modello fallito dopo 3 tentativi"
      MSG_DOWNLOAD_MANUAL="Provare manualmente: ollama pull %s"
      MSG_DOWNLOAD_DONE="Modello scaricato: %s"
      # Custom Model
      MSG_CREATING_CUSTOM="Creazione del modello Hablará..."
      MSG_UPDATING_CUSTOM="Aggiornamento del modello Hablará esistente..."
      MSG_CUSTOM_EXISTS="    • Il modello Hablará %s è già presente."
      MSG_CUSTOM_SKIP="Salta (nessuna modifica)"
      MSG_CUSTOM_UPDATE_OPT="Aggiorna il modello Hablará"
      MSG_CUSTOM_UPDATE_PROMPT="Selezione [1-2, Invio=1]"
      MSG_CUSTOM_KEPT="Modello Hablará conservato"
      MSG_CUSTOM_PRESENT="Modello Hablará già presente"
      MSG_USING_HABLARA_CONFIG="Utilizzo della configurazione Hablará"
      MSG_USING_DEFAULT_CONFIG="Utilizzo della configurazione predefinita"
      MSG_CUSTOM_CREATING="Creazione del modello Hablará %s..."
      MSG_CUSTOM_CREATE_TIMEOUT="ollama create ha superato il tempo massimo di 120s — utilizzo del modello base"
      MSG_CUSTOM_CREATE_FAILED="Il modello Hablará non ha potuto essere %s - utilizzo del modello base"
      MSG_CUSTOM_DONE="Modello Hablará %s: %s"
      MSG_VERB_CREATED="creato"
      MSG_VERB_UPDATED="aggiornato"
      # Verify
      MSG_VERIFYING="Verifica dell'installazione..."
      MSG_OLLAMA_NOT_FOUND="Ollama non trovato"
      MSG_SERVER_UNREACHABLE="Server Ollama non raggiungibile"
      MSG_BASE_NOT_FOUND="Modello base non trovato: %s"
      MSG_BASE_OK="Modello base disponibile: %s"
      MSG_CUSTOM_OK="Modello Hablará disponibile: %s"
      MSG_CUSTOM_UNAVAILABLE="Modello Hablará non disponibile (utilizzo del modello base)"
      MSG_INFERENCE_FAILED="Test del modello fallito, testare nell'app"
      MSG_SETUP_DONE="Configurazione completata!"
      # Main Summary
      MSG_SETUP_COMPLETE="Configurazione Ollama Hablará completata!"
      MSG_INSTALLED="Installato:"
      MSG_BASE_MODEL_LABEL="  Modello base:    "
      MSG_HABLARA_MODEL_LABEL="  Modello Hablará: "
      MSG_OLLAMA_CONFIG="Configurazione Ollama:"
      MSG_MODEL_LABEL="  Modello:   "
      MSG_BASE_URL_LABEL="  Base URL: "
      MSG_DOCS="Documentazione: https://github.com/fidpa/hablara"
      # Status
      MSG_STATUS_TITLE_MAC="Stato Ollama Hablará (macOS)"
      MSG_STATUS_TITLE_LINUX="Stato Ollama Hablará (Linux)"
      MSG_STATUS_INSTALLED="Ollama installato (v%s)"
      MSG_STATUS_UPDATE_REC_BREW="  ↳ Aggiornamento raccomandato (minimo v%s): brew upgrade ollama"
      MSG_STATUS_UPDATE_REC_APT="  ↳ Aggiornamento raccomandato (minimo v%s): sudo apt-get install ollama"
      MSG_STATUS_NOT_FOUND="Ollama non trovato"
      MSG_STATUS_SERVER_OK="Server in esecuzione"
      MSG_STATUS_SERVER_FAIL="Server non raggiungibile"
      MSG_STATUS_GPU_APPLE="GPU: Apple Silicon (accelerazione Metal)"
      MSG_STATUS_GPU_NVIDIA="GPU: NVIDIA (accelerazione CUDA)"
      MSG_STATUS_NO_GPU="Nessuna GPU — elaborazione senza accelerazione GPU"
      MSG_STATUS_BASE_MODEL="Modello base: %s"
      MSG_STATUS_BASE_MODELS="Modelli base:"
      MSG_STATUS_NO_BASE="Nessun modello base trovato"
      MSG_STATUS_HABLARA_MODEL="Modello Hablará: %s"
      MSG_STATUS_HABLARA_MODELS="Modelli Hablará:"
      MSG_STATUS_NO_HABLARA="Nessun modello Hablará trovato"
      MSG_STATUS_BASE_MISSING="  ↳ Modello base mancante — il modello Hablará lo richiede come base"
      MSG_STATUS_INFERENCE_SKIP="Test del modello saltato (server non raggiungibile)"
      MSG_STATUS_MODEL_OK="Modello risponde"
      MSG_STATUS_MODEL_FAIL="Modello non risponde"
      MSG_STATUS_STORAGE="Utilizzo dell'archiviazione (Hablará): ~%s GB"
      MSG_STATUS_STORAGE_UNKNOWN="Utilizzo dell'archiviazione: non determinabile"
      MSG_STATUS_ALL_OK="Tutto è in ordine."
      MSG_STATUS_PROBLEMS="%s problema/i trovato/i."
      MSG_STATUS_REPAIR="    Riparare:"
      # Diagnose
      MSG_DIAGNOSE_TITLE="=== Rapporto di Diagnostica Ollama Hablará ==="
      MSG_DIAGNOSE_OS="OS:"
      MSG_DIAGNOSE_RAM="RAM:"
      MSG_DIAGNOSE_RAM_AVAIL="disponibile"
      MSG_DIAGNOSE_STORAGE_FREE="libero"
      MSG_DIAGNOSE_SHELL="Shell:"
      MSG_DIAGNOSE_VERSION="Versione:"
      MSG_DIAGNOSE_SERVER="Server:"
      MSG_DIAGNOSE_API="URL API:"
      MSG_DIAGNOSE_GPU="GPU:"
      MSG_DIAGNOSE_STORAGE_LABEL="Archiviazione (Hablará):"
      MSG_DIAGNOSE_LOG_LABEL="Log Ollama (errori recenti):"
      MSG_DIAGNOSE_DISTRIBUTION="Distribuzione:"
      MSG_DIAGNOSE_CREATED="Creato:"
      MSG_DIAGNOSE_SCRIPT="Script:"
      MSG_DIAGNOSE_SAVED="Report salvato: %s"
      MSG_DIAGNOSE_SAVE_FAILED="Impossibile salvare il report"
      MSG_DIAGNOSE_UNKNOWN="sconosciuto"
      MSG_DIAGNOSE_NOT_INSTALLED="non installato"
      MSG_DIAGNOSE_NOT_REACHABLE="non raggiungibile"
      MSG_DIAGNOSE_RUNNING="in esecuzione"
      MSG_DIAGNOSE_NO_MODELS="    [nessun modello Hablará trovato]"
      MSG_DIAGNOSE_NO_ERRORS="    [nessun errore trovato]"
      MSG_DIAGNOSE_NO_LOG="    [file di log non trovato: %s]"
      MSG_DIAGNOSE_GPU_APPLE="Apple Silicon (Metal)"
      MSG_DIAGNOSE_GPU_NVIDIA="NVIDIA (CUDA)"
      MSG_DIAGNOSE_GPU_NONE="Nessuna"
      MSG_DIAGNOSE_RESPONDS="(risponde)"
      MSG_DIAGNOSE_SECTION_SYSTEM="Sistema"
      MSG_DIAGNOSE_SECTION_OLLAMA="Ollama"
      MSG_DIAGNOSE_SECTION_MODELS="Modelli Hablará"
      MSG_DIAGNOSE_STORAGE_DISK="Archiviazione"
      MSG_DIAGNOSE_GPU_AMD="AMD (ROCm)"
      MSG_DIAGNOSE_GPU_INTEL="Intel (oneAPI)"
      MSG_GPU_STATUS_AMD="GPU: AMD (accelerazione ROCm, sperimentale)"
      MSG_GPU_STATUS_INTEL="GPU: Intel (accelerazione oneAPI, sperimentale)"
      MSG_HOMEBREW_INSTALLED="Ollama installato via Homebrew"
      # Cleanup
      MSG_CLEANUP_NEEDS_TTY="--cleanup richiede una sessione interattiva"
      MSG_CLEANUP_NO_OLLAMA="Ollama non trovato"
      MSG_CLEANUP_NO_SERVER="Server Ollama non raggiungibile"
      MSG_CLEANUP_START_HINT="Avvia Ollama e riprova"
      MSG_CLEANUP_INSTALLED="Varianti Hablará installate:"
      MSG_CLEANUP_PROMPT="Quale variante eliminare? (numero, Invio=annulla, tempo massimo 60s): "
      MSG_CLEANUP_ENTER_CANCEL="Invio=annulla"
      MSG_CLEANUP_INVALID="Selezione non valida"
      MSG_CLEANUP_DELETED="%s eliminato"
      MSG_CLEANUP_FAILED="%s non ha potuto essere eliminato: %s"
      MSG_CLEANUP_UNKNOWN_ERR="errore sconosciuto"
      MSG_CLEANUP_NONE_LEFT="Nessun modello Hablará più installato. Esegui di nuovo il setup per installare un modello."
      MSG_CLEANUP_NO_MODELS="Nessun modello Hablará trovato."
      # Misc
      MSG_INTERNAL_ERROR="Errore interno: MODEL_NAME non impostato"
      MSG_TEST_MODEL="Test del modello..."
      MSG_TEST_OK="Test del modello riuscito"
      MSG_TEST_FAIL="Test del modello fallito"
      MSG_WAIT_SERVER="In attesa del server Ollama..."
      MSG_SERVER_READY="Il server Ollama è pronto"
      MSG_SERVER_NO_RESPONSE="Il server Ollama non risponde dopo %ss"
      MSG_SETUP_FAILED="Configurazione fallita"
      MSG_OLLAMA_LIST_TIMEOUT="ollama list ha superato il tempo massimo (15s) durante il controllo del modello"
      # Linux-specific service management
      MSG_SYSTEMD_START="Avvio del servizio Ollama..."
      MSG_SYSTEMD_ENABLE="Abilitazione del servizio Ollama..."
      MSG_SYSTEMD_START_FAIL="Impossibile avviare il servizio Ollama"
      MSG_SERVICE_MANUAL="Avviare manualmente: ollama serve"
      MSG_LINUX_CURL_INSTALL="Installazione di curl prima..."
      MSG_LINUX_INSTALL_HINT="Installare curl: sudo apt-get install -y curl"
      # Server management (start_ollama_server + show_summary)
      MSG_SERVER_ALREADY="Il server Ollama è già in esecuzione"
      MSG_PORT_CHECK_HINT_SS="Verifica: ss -tlnp | grep 11434"
      MSG_SYSTEMD_SYSTEM_ACTIVE="Servizio di sistema Ollama attivo, in attesa dell'API..."
      MSG_SYSTEMD_SYSTEM_START="Avvio di Ollama tramite systemd (servizio di sistema)..."
      MSG_SYSTEMD_STARTED="Server Ollama avviato (systemd)"
      MSG_SYSTEMD_USER_START="Avvio di Ollama tramite systemd (servizio utente)..."
      MSG_NOHUP_START="Avvio del server Ollama (nohup)..."
      MSG_SERVER_STARTED_PID="Server Ollama avviato (PID: %s)"
      MSG_PROCESS_FAILED="Processo Ollama fallito - Log: %s"
      MSG_PROCESS_START_FAIL="Impossibile avviare il processo Ollama"
      MSG_SERVICE_MANAGEMENT="Gestione del servizio:"
      MSG_GPU_AMD="GPU AMD rilevata (sperimentale)"
      MSG_GPU_INTEL="GPU Intel rilevata (sperimentale)"
      # Help
      MSG_HELP_DESCRIPTION="Installa Ollama e configura un modello Hablará ottimizzato."
      MSG_HELP_USAGE="Utilizzo:"
      MSG_HELP_OPTS_LABEL="OPZIONI"
      MSG_HELP_OPTIONS="Opzioni:"
      MSG_HELP_OPT_MODEL="  -m, --model VARIANTE  Scegli la variante: 1.5b, 3b, 7b, qwen3-8b (predefinito: 3b)"
      MSG_HELP_OPT_UPDATE="  --update              Ricreare il modello Hablará (aggiornare il Modelfile)"
      MSG_HELP_OPT_STATUS="  --status              Verifica: controllo in 7 punti dell'installazione Ollama"
      MSG_HELP_OPT_DIAGNOSE="  --diagnose            Generare rapporto di supporto (testo normale, copiabile)"
      MSG_HELP_OPT_CLEANUP="  --cleanup             Eliminare interattivamente la variante installata (richiede terminale)"
      MSG_HELP_OPT_LANG="  --lang CODE           Lingua: da (Danese), de (Tedesco), en (Inglese), es (Spagnolo), fr (Francese), it (Italiano), nl (Olandese), pl (Polacco), pt (Portoghese), sv (Svedese)"
      MSG_HELP_OPT_HELP="  -h, --help            Mostrare questa guida"
      MSG_HELP_NO_OPTS="Senza opzioni, viene avviato un menu interattivo."
      MSG_HELP_VARIANTS="Varianti del modello:"
      MSG_HELP_EXAMPLES="Esempi:"
      MSG_HELP_EX_MODEL="--model 3b                          Installare la variante 3b"
      MSG_HELP_EX_UPDATE="--update                            Aggiornare il modello personalizzato"
      MSG_HELP_EX_STATUS="--status                            Verificare l'installazione"
      MSG_HELP_EX_DIAGNOSE="--diagnose                          Creare rapporto di bug"
      MSG_HELP_EX_CLEANUP="--cleanup                           Rimuovere la variante"
      MSG_HELP_EX_PIPE="  curl -fsSL URL | bash -s -- -m 3b      Tramite pipe con argomento"
      MSG_HELP_EXIT_CODES="Codici di uscita:"
      MSG_HELP_EXIT_0="  0  Successo"
      MSG_HELP_EXIT_1="  1  Errore generale"
      MSG_HELP_EXIT_2="  2  Spazio su disco insufficiente"
      MSG_HELP_EXIT_3="  3  Nessuna connessione di rete"
      MSG_HELP_EXIT_4="  4  Piattaforma errata"
      # Hardware Detection
      MSG_HW_DETECTION_HEADER="Rilevamento hardware:"
      MSG_HW_BANDWIDTH="Larghezza di banda memoria: ~%s GB/s · %s GB RAM"
      MSG_HW_RECOMMENDATION="Raccomandazione modello per il tuo hardware:"
      MSG_HW_LOCAL_TOO_SLOW="I modelli locali saranno lenti su questo hardware"
      MSG_HW_CLOUD_HINT="Raccomandazione: API OpenAI o Anthropic per la migliore esperienza"
      MSG_HW_PROCEED_LOCAL="Installare localmente comunque? [s/N]"
      MSG_HW_TAG_RECOMMENDED="raccomandato"
      MSG_HW_TAG_SLOW="lento"
      MSG_HW_TAG_TOO_SLOW="troppo lento"
      MSG_CHOICE_PROMPT_HW="Scelta [1-4, Invio=%s]"
      MSG_HW_UNKNOWN_CHIP="Processore sconosciuto — nessuna raccomandazione di banda possibile"
      MSG_HW_MULTI_CALL_HINT="Hablará esegue più fasi di analisi per registrazione"
      # Benchmark
      MSG_BENCH_RESULT="Benchmark: ~%s tok/s con %s"
      MSG_BENCH_EXCELLENT="Eccellente — il tuo hardware gestisce questo modello con facilità"
      MSG_BENCH_GOOD="Buono — questo modello funziona bene sul tuo hardware"
      MSG_BENCH_MARGINAL="Marginale — un modello più piccolo offre un'esperienza più fluida"
      MSG_BENCH_TOO_SLOW="Troppo lento — si consiglia un modello più piccolo o un provider cloud"
      MSG_BENCH_SKIP="Benchmark saltato (misurazione fallita)"
      ;;
    nl)
      MSG_ERROR_PREFIX="Fout"
      # Model Menu
      MSG_CHOOSE_MODEL="Kies een model:"
      MSG_CHOICE_PROMPT="Keuze [1-4, Enter=1]"
      MSG_MODEL_3B="Optimale algehele prestaties [Standaard]"
      MSG_MODEL_1_5B="Snel, beperkte nauwkeurigheid [Instap]"
      MSG_MODEL_7B="Vereist krachtige hardware"
      MSG_MODEL_QWEN3="Beste argumentatieanalyse [Premium]"
      # Main Menu
      MSG_CHOOSE_ACTION="Kies een actie:"
      MSG_ACTION_SETUP="Ollama instellen of bijwerken"
      MSG_ACTION_STATUS="Status controleren"
      MSG_ACTION_DIAGNOSE="Diagnose (ondersteuningsrapport)"
      MSG_ACTION_CLEANUP="Modellen opruimen"
      MSG_ACTION_PROMPT="Keuze [1-4, Enter=1]"
      # Select Model / Args
      MSG_OPT_NEEDS_ARG="Optie %s vereist een argument"
      MSG_UNKNOWN_OPTION="Onbekende optie: %s"
      MSG_INVALID_MODEL="Ongeldige modelvariante: %s"
      MSG_VALID_VARIANTS="Geldige varianten: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b"
      MSG_RAM_WARN_MODEL="Dit model vereist minimaal %sGB RAM"
      MSG_RAM_WARN_SYS="Uw systeem heeft %sGB RAM"
      MSG_CONTINUE_ANYWAY="Toch doorgaan?"
      MSG_CONFIRM_PROMPT="[j/N]"
      MSG_CONFIRM_YES='^[jJyY]$'
      MSG_ABORTED="Afgebroken."
      MSG_SELECTED_MODEL="Geselecteerd model: %s"
      MSG_PROCEED_NONINTERACTIVE="Doorgaan..."
      # Preflight
      MSG_PREFLIGHT="Voorafgaande controles uitvoeren..."
      MSG_PLATFORM_ERROR_MAC="Dit script is alleen voor macOS"
      MSG_PLATFORM_LINUX_HINT="Voor Linux: scripts/setup-ollama-linux.sh"
      MSG_PLATFORM_ERROR_LINUX="Dit script is alleen voor Linux"
      MSG_PLATFORM_MAC_HINT="Voor macOS: scripts/setup-ollama-mac.sh"
      MSG_TOOL_MISSING="%s ontbreekt (installeer dit)"
      MSG_DISK_INSUFFICIENT="Onvoldoende schijfruimte: %sGB beschikbaar, %sGB vereist"
      MSG_DISK_OK="Schijfruimte: %sGB beschikbaar"
      MSG_NETWORK_ERROR="Geen netwerkverbinding met ollama.com"
      MSG_NETWORK_HINT="Controleer: curl -I https://ollama.com"
      MSG_NETWORK_OK="Netwerkverbinding OK"
      MSG_GPU_APPLE="Apple Silicon gedetecteerd (Metal-versnelling)"
      MSG_GPU_NVIDIA="NVIDIA GPU gedetecteerd (CUDA-versnelling)"
      MSG_GPU_NONE="Geen GPU gedetecteerd - verwerking zonder GPU-versnelling"
      # Install Ollama
      MSG_INSTALLING_OLLAMA="Ollama installeren..."
      MSG_OLLAMA_ALREADY="Ollama is al geïnstalleerd"
      MSG_OLLAMA_VERSION="Versie: %s"
      MSG_CHECKING_SERVER="Ollama-server controleren..."
      MSG_SERVER_START_FAILED="Kon de Ollama-server niet starten"
      MSG_SERVER_START_HINT="Handmatig starten: ollama serve"
      MSG_SERVER_RUNNING="Ollama-server actief"
      MSG_USING_BREW="Homebrew gebruiken (time-out: 10 minuten)..."
      MSG_BREW_TIMEOUT="brew install time-out na 10 minuten"
      MSG_BREW_ALT="Alternatief: https://ollama.com/download"
      MSG_BREW_FAILED="Homebrew-installatie mislukt"
      MSG_OLLAMA_PATH_ERROR="Ollama geïnstalleerd, maar CLI niet in PATH"
      MSG_PATH_HINT="Terminal opnieuw starten of PATH controleren"
      MSG_SERVER_START_WARN="Server starten mislukt - handmatig starten: ollama serve"
      MSG_DOWNLOADING_INSTALLER="Ollama-installatieprogramma downloaden..."
      MSG_INSTALLER_DOWNLOAD_FAILED="Download van installatieprogramma mislukt"
      MSG_MANUAL_INSTALL="Handmatige installatie: https://ollama.com/download"
      MSG_RUNNING_INSTALLER="Installatieprogramma uitvoeren (time-out: 5 minuten)..."
      MSG_INSTALLER_TIMEOUT="Installatieprogramma time-out na 5 minuten"
      MSG_INSTALL_FAILED="Ollama-installatie mislukt"
      MSG_OLLAMA_INSTALLED="Ollama geïnstalleerd"
      MSG_APT_HINT="Installeren: sudo apt-get install -y curl"
      MSG_OLLAMA_FOUND="Ollama gevonden: %s"
      MSG_OLLAMA_BREW_FOUND="Ollama via Homebrew gevonden: %s"
      MSG_PORT_BUSY="Poort 11434 is bezet, wachten op Ollama API..."
      MSG_PORT_BUSY_WARN="Poort 11434 bezet, maar Ollama API reageert niet"
      MSG_PORT_CHECK_HINT="Controleer: lsof -i :11434"
      MSG_VERSION_WARN="Ollama versie %s is ouder dan aanbevolen (%s)"
      MSG_UPDATE_HINT_BREW="Bijwerken: brew upgrade ollama"
      MSG_UPDATE_HINT_APT="Bijwerken: sudo apt-get install ollama"
      # Model Download
      MSG_DOWNLOADING_BASE="Basismodel downloaden..."
      MSG_MODEL_EXISTS="Model al aanwezig: %s"
      MSG_DOWNLOADING_MODEL="%s downloaden (%s, duurt enkele minuten afhankelijk van de verbinding)..."
      MSG_DOWNLOAD_RESUME_TIP="Tip: Bij onderbreking (Ctrl+C) wordt de download hervat bij opnieuw starten"
      MSG_DOWNLOAD_HARD_TIMEOUT="Harde time-out na %s minuten — afbreken"
      MSG_DOWNLOAD_STALL="Geen downloadvoortgang in %s minuten — afbreken"
      MSG_DOWNLOAD_RUNNING="  Download actief... (%ss)"
      MSG_DOWNLOAD_TIMEOUT_WARN="Download time-out na %s minuten (poging %s/3)"
      MSG_DOWNLOAD_FAILED_WARN="Download mislukt (poging %s/3)"
      MSG_DOWNLOAD_RETRY="Volgende poging in 5s..."
      MSG_DOWNLOAD_FAILED="Modeldownload mislukt na 3 pogingen"
      MSG_DOWNLOAD_MANUAL="Handmatig proberen: ollama pull %s"
      MSG_DOWNLOAD_DONE="Model gedownload: %s"
      # Custom Model
      MSG_CREATING_CUSTOM="Hablará-model aanmaken..."
      MSG_UPDATING_CUSTOM="Bestaand Hablará-model bijwerken..."
      MSG_CUSTOM_EXISTS="    • Hablará-model %s al aanwezig."
      MSG_CUSTOM_SKIP="Overslaan (geen wijziging)"
      MSG_CUSTOM_UPDATE_OPT="Hablará-model bijwerken"
      MSG_CUSTOM_UPDATE_PROMPT="Keuze [1-2, Enter=1]"
      MSG_CUSTOM_KEPT="Hablará-model behouden"
      MSG_CUSTOM_PRESENT="Hablará-model al aanwezig"
      MSG_USING_HABLARA_CONFIG="Hablará-configuratie gebruiken"
      MSG_USING_DEFAULT_CONFIG="Standaardconfiguratie gebruiken"
      MSG_CUSTOM_CREATING="Hablará-model %s aanmaken..."
      MSG_CUSTOM_CREATE_TIMEOUT="ollama create time-out na 120s — basismodel gebruiken"
      MSG_CUSTOM_CREATE_FAILED="Hablará-model kon niet worden %s - basismodel gebruiken"
      MSG_CUSTOM_DONE="Hablará-model %s: %s"
      MSG_VERB_CREATED="aangemaakt"
      MSG_VERB_UPDATED="bijgewerkt"
      # Verify
      MSG_VERIFYING="Installatie controleren..."
      MSG_OLLAMA_NOT_FOUND="Ollama niet gevonden"
      MSG_SERVER_UNREACHABLE="Ollama-server niet bereikbaar"
      MSG_BASE_NOT_FOUND="Basismodel niet gevonden: %s"
      MSG_BASE_OK="Basismodel beschikbaar: %s"
      MSG_CUSTOM_OK="Hablará-model beschikbaar: %s"
      MSG_CUSTOM_UNAVAILABLE="Hablará-model niet beschikbaar (basismodel gebruiken)"
      MSG_INFERENCE_FAILED="Modeltest mislukt, testen in de app"
      MSG_SETUP_DONE="Installatie voltooid!"
      # Main Summary
      MSG_SETUP_COMPLETE="Hablará Ollama-installatie voltooid!"
      MSG_INSTALLED="Geïnstalleerd:"
      MSG_BASE_MODEL_LABEL="  Basismodel:      "
      MSG_HABLARA_MODEL_LABEL="  Hablará-model:   "
      MSG_OLLAMA_CONFIG="Ollama-configuratie:"
      MSG_MODEL_LABEL="  Model:    "
      MSG_BASE_URL_LABEL="  Base URL: "
      MSG_DOCS="Documentatie: https://github.com/fidpa/hablara"
      # Status
      MSG_STATUS_TITLE_MAC="Hablará Ollama Status (macOS)"
      MSG_STATUS_TITLE_LINUX="Hablará Ollama Status (Linux)"
      MSG_STATUS_INSTALLED="Ollama geïnstalleerd (v%s)"
      MSG_STATUS_UPDATE_REC_BREW="  ↳ Update aanbevolen (minimaal v%s): brew upgrade ollama"
      MSG_STATUS_UPDATE_REC_APT="  ↳ Update aanbevolen (minimaal v%s): sudo apt-get install ollama"
      MSG_STATUS_NOT_FOUND="Ollama niet gevonden"
      MSG_STATUS_SERVER_OK="Server actief"
      MSG_STATUS_SERVER_FAIL="Server niet bereikbaar"
      MSG_STATUS_GPU_APPLE="GPU: Apple Silicon (Metal-versnelling)"
      MSG_STATUS_GPU_NVIDIA="GPU: NVIDIA (CUDA-versnelling)"
      MSG_STATUS_NO_GPU="Geen GPU — verwerking zonder GPU-versnelling"
      MSG_STATUS_BASE_MODEL="Basismodel: %s"
      MSG_STATUS_BASE_MODELS="Basismodellen:"
      MSG_STATUS_NO_BASE="Geen basismodel gevonden"
      MSG_STATUS_HABLARA_MODEL="Hablará-model: %s"
      MSG_STATUS_HABLARA_MODELS="Hablará-modellen:"
      MSG_STATUS_NO_HABLARA="Geen Hablará-model gevonden"
      MSG_STATUS_BASE_MISSING="  ↳ Basismodel ontbreekt — Hablará-model heeft dit als basis nodig"
      MSG_STATUS_INFERENCE_SKIP="Modeltest overgeslagen (server niet bereikbaar)"
      MSG_STATUS_MODEL_OK="Model reageert"
      MSG_STATUS_MODEL_FAIL="Model reageert niet"
      MSG_STATUS_STORAGE="Opslaggebruik (Hablará): ~%s GB"
      MSG_STATUS_STORAGE_UNKNOWN="Opslaggebruik: niet te bepalen"
      MSG_STATUS_ALL_OK="Alles is in orde."
      MSG_STATUS_PROBLEMS="%s probleem/problemen gevonden."
      MSG_STATUS_REPAIR="    Repareren:"
      # Diagnose
      MSG_DIAGNOSE_TITLE="=== Hablará Ollama Diagnoserapport ==="
      MSG_DIAGNOSE_OS="OS:"
      MSG_DIAGNOSE_RAM="RAM:"
      MSG_DIAGNOSE_RAM_AVAIL="beschikbaar"
      MSG_DIAGNOSE_STORAGE_FREE="vrij"
      MSG_DIAGNOSE_SHELL="Shell:"
      MSG_DIAGNOSE_VERSION="Versie:"
      MSG_DIAGNOSE_SERVER="Server:"
      MSG_DIAGNOSE_API="API-URL:"
      MSG_DIAGNOSE_GPU="GPU:"
      MSG_DIAGNOSE_STORAGE_LABEL="Opslag (Hablará):"
      MSG_DIAGNOSE_LOG_LABEL="Ollama-log (recente fouten):"
      MSG_DIAGNOSE_DISTRIBUTION="Distributie:"
      MSG_DIAGNOSE_CREATED="Aangemaakt:"
      MSG_DIAGNOSE_SCRIPT="Script:"
      MSG_DIAGNOSE_SAVED="Rapport opgeslagen: %s"
      MSG_DIAGNOSE_SAVE_FAILED="Rapport kon niet worden opgeslagen"
      MSG_DIAGNOSE_UNKNOWN="onbekend"
      MSG_DIAGNOSE_NOT_INSTALLED="niet geïnstalleerd"
      MSG_DIAGNOSE_NOT_REACHABLE="niet bereikbaar"
      MSG_DIAGNOSE_RUNNING="actief"
      MSG_DIAGNOSE_NO_MODELS="    [geen Hablará-modellen gevonden]"
      MSG_DIAGNOSE_NO_ERRORS="    [geen fouten gevonden]"
      MSG_DIAGNOSE_NO_LOG="    [logbestand niet gevonden: %s]"
      MSG_DIAGNOSE_GPU_APPLE="Apple Silicon (Metal)"
      MSG_DIAGNOSE_GPU_NVIDIA="NVIDIA (CUDA)"
      MSG_DIAGNOSE_GPU_NONE="Geen"
      MSG_DIAGNOSE_RESPONDS="(reageert)"
      MSG_DIAGNOSE_SECTION_SYSTEM="Systeem"
      MSG_DIAGNOSE_SECTION_OLLAMA="Ollama"
      MSG_DIAGNOSE_SECTION_MODELS="Hablará-modellen"
      MSG_DIAGNOSE_STORAGE_DISK="Opslag"
      MSG_DIAGNOSE_GPU_AMD="AMD (ROCm)"
      MSG_DIAGNOSE_GPU_INTEL="Intel (oneAPI)"
      MSG_GPU_STATUS_AMD="GPU: AMD (ROCm-versnelling, experimenteel)"
      MSG_GPU_STATUS_INTEL="GPU: Intel (oneAPI-versnelling, experimenteel)"
      MSG_HOMEBREW_INSTALLED="Ollama via Homebrew geïnstalleerd"
      # Cleanup
      MSG_CLEANUP_NEEDS_TTY="--cleanup vereist een interactieve sessie"
      MSG_CLEANUP_NO_OLLAMA="Ollama niet gevonden"
      MSG_CLEANUP_NO_SERVER="Ollama-server niet bereikbaar"
      MSG_CLEANUP_START_HINT="Start Ollama en probeer opnieuw"
      MSG_CLEANUP_INSTALLED="Geïnstalleerde Hablará-varianten:"
      MSG_CLEANUP_PROMPT="Welke variant verwijderen? (nummer, Enter=annuleren, time-out 60s): "
      MSG_CLEANUP_ENTER_CANCEL="Enter=annuleren"
      MSG_CLEANUP_INVALID="Ongeldige selectie"
      MSG_CLEANUP_DELETED="%s verwijderd"
      MSG_CLEANUP_FAILED="%s kon niet worden verwijderd: %s"
      MSG_CLEANUP_UNKNOWN_ERR="onbekende fout"
      MSG_CLEANUP_NONE_LEFT="Geen Hablará-modellen meer geïnstalleerd. Voer de installatie opnieuw uit om een model te installeren."
      MSG_CLEANUP_NO_MODELS="Geen Hablará-modellen gevonden."
      # Misc
      MSG_INTERNAL_ERROR="Interne fout: MODEL_NAME niet ingesteld"
      MSG_TEST_MODEL="Model testen..."
      MSG_TEST_OK="Modeltest geslaagd"
      MSG_TEST_FAIL="Modeltest mislukt"
      MSG_WAIT_SERVER="Wachten op Ollama-server..."
      MSG_SERVER_READY="Ollama-server is gereed"
      MSG_SERVER_NO_RESPONSE="Ollama-server reageert niet na %ss"
      MSG_SETUP_FAILED="Installatie mislukt"
      MSG_OLLAMA_LIST_TIMEOUT="ollama list time-out (15s) bij modelcontrole"
      # Linux-specific service management
      MSG_SYSTEMD_START="Ollama-service starten..."
      MSG_SYSTEMD_ENABLE="Ollama-service inschakelen..."
      MSG_SYSTEMD_START_FAIL="Kon de Ollama-service niet starten"
      MSG_SERVICE_MANUAL="Handmatig starten: ollama serve"
      MSG_LINUX_CURL_INSTALL="curl installeren..."
      MSG_LINUX_INSTALL_HINT="curl installeren: sudo apt-get install -y curl"
      # Server management (start_ollama_server + show_summary)
      MSG_SERVER_ALREADY="Ollama-server is al actief"
      MSG_PORT_CHECK_HINT_SS="Controleer: ss -tlnp | grep 11434"
      MSG_SYSTEMD_SYSTEM_ACTIVE="Ollama-systeemservice actief, wachten op API..."
      MSG_SYSTEMD_SYSTEM_START="Ollama starten via systemd (systeemservice)..."
      MSG_SYSTEMD_STARTED="Ollama-server gestart (systemd)"
      MSG_SYSTEMD_USER_START="Ollama starten via systemd (gebruikersservice)..."
      MSG_NOHUP_START="Ollama-server starten (nohup)..."
      MSG_SERVER_STARTED_PID="Ollama-server gestart (PID: %s)"
      MSG_PROCESS_FAILED="Ollama-proces mislukt - Log: %s"
      MSG_PROCESS_START_FAIL="Ollama-proces kon niet worden gestart"
      MSG_SERVICE_MANAGEMENT="Servicebeheer:"
      MSG_GPU_AMD="AMD GPU gedetecteerd (experimenteel)"
      MSG_GPU_INTEL="Intel GPU gedetecteerd (experimenteel)"
      # Help
      MSG_HELP_DESCRIPTION="Installeert Ollama en configureert een geoptimaliseerd Hablará-model."
      MSG_HELP_USAGE="Gebruik:"
      MSG_HELP_OPTS_LABEL="OPTIES"
      MSG_HELP_OPTIONS="Opties:"
      MSG_HELP_OPT_MODEL="  -m, --model VARIANT   Modelvariante kiezen: 1.5b, 3b, 7b, qwen3-8b (standaard: 3b)"
      MSG_HELP_OPT_UPDATE="  --update              Hablará-aangepast model opnieuw aanmaken (Modelfile bijwerken)"
      MSG_HELP_OPT_STATUS="  --status              Statuscontrole: 7-punts controle van de Ollama-installatie"
      MSG_HELP_OPT_DIAGNOSE="  --diagnose            Ondersteuningsrapport genereren (platte tekst, kopieerbaar)"
      MSG_HELP_OPT_CLEANUP="  --cleanup             Geïnstalleerde variant interactief verwijderen (vereist terminal)"
      MSG_HELP_OPT_LANG="  --lang CODE           Taal: da (Deens), de (Duits), en (Engels), es (Spaans), fr (Frans), it (Italiaans), nl (Nederlands), pl (Pools), pt (Portugees), sv (Zweeds)"
      MSG_HELP_OPT_HELP="  -h, --help            Deze help weergeven"
      MSG_HELP_NO_OPTS="Zonder opties wordt een interactief menu gestart."
      MSG_HELP_VARIANTS="Modelvarianten:"
      MSG_HELP_EXAMPLES="Voorbeelden:"
      MSG_HELP_EX_MODEL="--model 3b                          3b-variant installeren"
      MSG_HELP_EX_UPDATE="--update                            Aangepast model bijwerken"
      MSG_HELP_EX_STATUS="--status                            Installatie controleren"
      MSG_HELP_EX_DIAGNOSE="--diagnose                          Bugrapport aanmaken"
      MSG_HELP_EX_CLEANUP="--cleanup                           Variant verwijderen"
      MSG_HELP_EX_PIPE="  curl -fsSL URL | bash -s -- -m 3b      Via pipe met argument"
      MSG_HELP_EXIT_CODES="Afsluitcodes:"
      MSG_HELP_EXIT_0="  0  Geslaagd"
      MSG_HELP_EXIT_1="  1  Algemene fout"
      MSG_HELP_EXIT_2="  2  Onvoldoende schijfruimte"
      MSG_HELP_EXIT_3="  3  Geen netwerkverbinding"
      MSG_HELP_EXIT_4="  4  Verkeerd platform"
      # Hardware Detection
      MSG_HW_DETECTION_HEADER="Hardware-detectie:"
      MSG_HW_BANDWIDTH="Geheugenbandbreedte: ~%s GB/s · %s GB RAM"
      MSG_HW_RECOMMENDATION="Modelaanbeveling voor jouw hardware:"
      MSG_HW_LOCAL_TOO_SLOW="Lokale modellen zullen traag zijn op deze hardware"
      MSG_HW_CLOUD_HINT="Aanbeveling: OpenAI of Anthropic API voor de beste ervaring"
      MSG_HW_PROCEED_LOCAL="Toch lokaal installeren? [j/N]"
      MSG_HW_TAG_RECOMMENDED="aanbevolen"
      MSG_HW_TAG_SLOW="traag"
      MSG_HW_TAG_TOO_SLOW="te traag"
      MSG_CHOICE_PROMPT_HW="Keuze [1-4, Enter=%s]"
      MSG_HW_UNKNOWN_CHIP="Onbekende processor — geen bandbreedteaanbeveling mogelijk"
      MSG_HW_MULTI_CALL_HINT="Hablará voert meerdere analysestappen per opname uit"
      # Benchmark
      MSG_BENCH_RESULT="Benchmark: ~%s tok/s met %s"
      MSG_BENCH_EXCELLENT="Uitstekend — jouw hardware verwerkt dit model moeiteloos"
      MSG_BENCH_GOOD="Goed — dit model draait goed op jouw hardware"
      MSG_BENCH_MARGINAL="Marginaal — een kleiner model zorgt voor een vloeiendere ervaring"
      MSG_BENCH_TOO_SLOW="Te traag — een kleiner model of cloud-aanbieder wordt aanbevolen"
      MSG_BENCH_SKIP="Benchmark overgeslagen (meting mislukt)"
      ;;
    pt)
      MSG_ERROR_PREFIX="Erro"
      # Model Menu
      MSG_CHOOSE_MODEL="Escolha um modelo:"
      MSG_CHOICE_PROMPT="Opção [1-4, Enter=1]"
      MSG_MODEL_3B="Melhor desempenho geral [Padrão]"
      MSG_MODEL_1_5B="Rápido, precisão limitada [Básico]"
      MSG_MODEL_7B="Requer hardware potente"
      MSG_MODEL_QWEN3="Melhor análise de argumentação [Premium]"
      # Main Menu
      MSG_CHOOSE_ACTION="Escolha uma ação:"
      MSG_ACTION_SETUP="Instalar ou atualizar o Ollama"
      MSG_ACTION_STATUS="Verificar status"
      MSG_ACTION_DIAGNOSE="Diagnóstico (relatório de suporte)"
      MSG_ACTION_CLEANUP="Limpar modelos"
      MSG_ACTION_PROMPT="Opção [1-4, Enter=1]"
      # Select Model / Args
      MSG_OPT_NEEDS_ARG="A opção %s requer um argumento"
      MSG_UNKNOWN_OPTION="Opção desconhecida: %s"
      MSG_INVALID_MODEL="Variante de modelo inválida: %s"
      MSG_VALID_VARIANTS="Variantes válidas: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b"
      MSG_RAM_WARN_MODEL="Este modelo requer pelo menos %sGB de RAM"
      MSG_RAM_WARN_SYS="O seu sistema tem %sGB de RAM"
      MSG_CONTINUE_ANYWAY="Continuar mesmo assim?"
      MSG_CONFIRM_PROMPT="[s/N]"
      MSG_CONFIRM_YES='^[sS]$'
      MSG_ABORTED="Cancelado."
      MSG_SELECTED_MODEL="Modelo selecionado: %s"
      MSG_PROCEED_NONINTERACTIVE="A continuar..."
      # Preflight
      MSG_PREFLIGHT="Executando verificações iniciais..."
      MSG_PLATFORM_ERROR_MAC="Este script é apenas para macOS"
      MSG_PLATFORM_LINUX_HINT="Para Linux: scripts/setup-ollama-linux.sh"
      MSG_PLATFORM_ERROR_LINUX="Este script é apenas para Linux"
      MSG_PLATFORM_MAC_HINT="Para macOS: scripts/setup-ollama-mac.sh"
      MSG_TOOL_MISSING="%s não encontrado (instale-o)"
      MSG_DISK_INSUFFICIENT="Espaço em disco insuficiente: %sGB disponíveis, %sGB necessários"
      MSG_DISK_OK="Espaço em disco: %sGB disponíveis"
      MSG_NETWORK_ERROR="Sem ligação à rede para ollama.com"
      MSG_NETWORK_HINT="Verificar: curl -I https://ollama.com"
      MSG_NETWORK_OK="Ligação à rede OK"
      MSG_GPU_APPLE="Apple Silicon detetado (aceleração Metal)"
      MSG_GPU_NVIDIA="GPU NVIDIA detetada (aceleração CUDA)"
      MSG_GPU_NONE="Nenhuma GPU detetada - processamento sem aceleração de GPU"
      # Install Ollama
      MSG_INSTALLING_OLLAMA="A instalar o Ollama..."
      MSG_OLLAMA_ALREADY="O Ollama já está instalado"
      MSG_OLLAMA_VERSION="Versão: %s"
      MSG_CHECKING_SERVER="A verificar o servidor Ollama..."
      MSG_SERVER_START_FAILED="Não foi possível iniciar o servidor Ollama"
      MSG_SERVER_START_HINT="Iniciar manualmente: ollama serve"
      MSG_SERVER_RUNNING="Servidor Ollama em execução"
      MSG_USING_BREW="A utilizar Homebrew (tempo limite: 10 minutos)..."
      MSG_BREW_TIMEOUT="brew install atingiu o tempo limite de 10 minutos"
      MSG_BREW_ALT="Alternativa: https://ollama.com/download"
      MSG_BREW_FAILED="Instalação via Homebrew falhou"
      MSG_OLLAMA_PATH_ERROR="Ollama instalado, mas CLI não está no PATH"
      MSG_PATH_HINT="Reinicie o terminal ou verifique o PATH"
      MSG_SERVER_START_WARN="Falha ao iniciar o servidor - iniciar manualmente: ollama serve"
      MSG_DOWNLOADING_INSTALLER="A descarregar o instalador do Ollama..."
      MSG_INSTALLER_DOWNLOAD_FAILED="Falha ao descarregar o instalador"
      MSG_MANUAL_INSTALL="Instalação manual: https://ollama.com/download"
      MSG_RUNNING_INSTALLER="A executar o instalador (tempo limite: 5 minutos)..."
      MSG_INSTALLER_TIMEOUT="Instalador atingiu o tempo limite de 5 minutos"
      MSG_INSTALL_FAILED="Instalação do Ollama falhou"
      MSG_OLLAMA_INSTALLED="Ollama instalado"
      MSG_APT_HINT="Instalar: sudo apt-get install -y curl"
      MSG_OLLAMA_FOUND="Ollama encontrado: %s"
      MSG_OLLAMA_BREW_FOUND="Ollama via Homebrew encontrado: %s"
      MSG_PORT_BUSY="Porta 11434 ocupada, a aguardar a API do Ollama..."
      MSG_PORT_BUSY_WARN="Porta 11434 ocupada, mas a API do Ollama não responde"
      MSG_PORT_CHECK_HINT="Verificar: lsof -i :11434"
      MSG_VERSION_WARN="Ollama versão %s é mais antiga que a recomendada (%s)"
      MSG_UPDATE_HINT_BREW="Atualizar: brew upgrade ollama"
      MSG_UPDATE_HINT_APT="Atualizar: sudo apt-get install ollama"
      # Model Download
      MSG_DOWNLOADING_BASE="A descarregar o modelo base..."
      MSG_MODEL_EXISTS="Modelo já disponível: %s"
      MSG_DOWNLOADING_MODEL="A descarregar %s (%s, pode demorar alguns minutos dependendo da ligação)..."
      MSG_DOWNLOAD_RESUME_TIP="Dica: Se interrompido (Ctrl+C), o descarregamento será retomado ao reiniciar"
      MSG_DOWNLOAD_HARD_TIMEOUT="Tempo limite rígido de %s minutos atingido — a cancelar"
      MSG_DOWNLOAD_STALL="Nenhum progresso no descarregamento em %s minutos — a cancelar"
      MSG_DOWNLOAD_RUNNING="  Descarregamento em curso... (%ss)"
      MSG_DOWNLOAD_TIMEOUT_WARN="Tempo limite do descarregamento após %s minutos (tentativa %s/3)"
      MSG_DOWNLOAD_FAILED_WARN="Descarregamento falhou (tentativa %s/3)"
      MSG_DOWNLOAD_RETRY="Próxima tentativa em 5s..."
      MSG_DOWNLOAD_FAILED="Descarregamento do modelo falhou após 3 tentativas"
      MSG_DOWNLOAD_MANUAL="Tentar manualmente: ollama pull %s"
      MSG_DOWNLOAD_DONE="Modelo descarregado: %s"
      # Custom Model
      MSG_CREATING_CUSTOM="A criar o modelo Hablará..."
      MSG_UPDATING_CUSTOM="A atualizar o modelo Hablará existente..."
      MSG_CUSTOM_EXISTS="    • Modelo Hablará %s já disponível."
      MSG_CUSTOM_SKIP="Ignorar (sem alterações)"
      MSG_CUSTOM_UPDATE_OPT="Atualizar o modelo Hablará"
      MSG_CUSTOM_UPDATE_PROMPT="Opção [1-2, Enter=1]"
      MSG_CUSTOM_KEPT="Modelo Hablará mantido"
      MSG_CUSTOM_PRESENT="Modelo Hablará já disponível"
      MSG_USING_HABLARA_CONFIG="A utilizar a configuração Hablará"
      MSG_USING_DEFAULT_CONFIG="A utilizar a configuração padrão"
      MSG_CUSTOM_CREATING="A criar o modelo Hablará %s..."
      MSG_CUSTOM_CREATE_TIMEOUT="ollama create atingiu o tempo limite de 120s — a utilizar o modelo base"
      MSG_CUSTOM_CREATE_FAILED="Não foi possível %s o modelo Hablará - a utilizar o modelo base"
      MSG_CUSTOM_DONE="Modelo Hablará %s: %s"
      MSG_VERB_CREATED="criado"
      MSG_VERB_UPDATED="atualizado"
      # Verify
      MSG_VERIFYING="A verificar a instalação..."
      MSG_OLLAMA_NOT_FOUND="Ollama não encontrado"
      MSG_SERVER_UNREACHABLE="Servidor Ollama inacessível"
      MSG_BASE_NOT_FOUND="Modelo base não encontrado: %s"
      MSG_BASE_OK="Modelo base disponível: %s"
      MSG_CUSTOM_OK="Modelo Hablará disponível: %s"
      MSG_CUSTOM_UNAVAILABLE="Modelo Hablará não disponível (a utilizar o modelo base)"
      MSG_INFERENCE_FAILED="Teste do modelo falhou, testar na aplicação"
      MSG_SETUP_DONE="Instalação concluída!"
      # Main Summary
      MSG_SETUP_COMPLETE="Instalação do Ollama para Hablará concluída!"
      MSG_INSTALLED="Instalado:"
      MSG_BASE_MODEL_LABEL="  Modelo base:      "
      MSG_HABLARA_MODEL_LABEL="  Modelo Hablará:   "
      MSG_OLLAMA_CONFIG="Configuração do Ollama:"
      MSG_MODEL_LABEL="  Modelo:    "
      MSG_BASE_URL_LABEL="  Base URL: "
      MSG_DOCS="Documentação: https://github.com/fidpa/hablara"
      # Status
      MSG_STATUS_TITLE_MAC="Hablará Ollama Status (macOS)"
      MSG_STATUS_TITLE_LINUX="Hablará Ollama Status (Linux)"
      MSG_STATUS_INSTALLED="Ollama instalado (v%s)"
      MSG_STATUS_UPDATE_REC_BREW="  ↳ Atualização recomendada (mínimo v%s): brew upgrade ollama"
      MSG_STATUS_UPDATE_REC_APT="  ↳ Atualização recomendada (mínimo v%s): sudo apt-get install ollama"
      MSG_STATUS_NOT_FOUND="Ollama não encontrado"
      MSG_STATUS_SERVER_OK="Servidor em execução"
      MSG_STATUS_SERVER_FAIL="Servidor inacessível"
      MSG_STATUS_GPU_APPLE="GPU: Apple Silicon (aceleração Metal)"
      MSG_STATUS_GPU_NVIDIA="GPU: NVIDIA (aceleração CUDA)"
      MSG_STATUS_NO_GPU="Sem GPU — processamento sem aceleração de GPU"
      MSG_STATUS_BASE_MODEL="Modelo base: %s"
      MSG_STATUS_BASE_MODELS="Modelos base:"
      MSG_STATUS_NO_BASE="Nenhum modelo base encontrado"
      MSG_STATUS_HABLARA_MODEL="Modelo Hablará: %s"
      MSG_STATUS_HABLARA_MODELS="Modelos Hablará:"
      MSG_STATUS_NO_HABLARA="Nenhum modelo Hablará encontrado"
      MSG_STATUS_BASE_MISSING="  ↳ Modelo base em falta — o modelo Hablará necessita dele como base"
      MSG_STATUS_INFERENCE_SKIP="Teste do modelo ignorado (servidor inacessível)"
      MSG_STATUS_MODEL_OK="Modelo responde"
      MSG_STATUS_MODEL_FAIL="Modelo não responde"
      MSG_STATUS_STORAGE="Uso de armazenamento (Hablará): ~%s GB"
      MSG_STATUS_STORAGE_UNKNOWN="Uso de armazenamento: não determinável"
      MSG_STATUS_ALL_OK="Tudo está em ordem."
      MSG_STATUS_PROBLEMS="%s problema(s) encontrado(s)."
      MSG_STATUS_REPAIR="    Reparar:"
      # Diagnose
      MSG_DIAGNOSE_TITLE="=== Relatório de Diagnóstico Ollama do Hablará ==="
      MSG_DIAGNOSE_OS="SO:"
      MSG_DIAGNOSE_RAM="RAM:"
      MSG_DIAGNOSE_RAM_AVAIL="disponível"
      MSG_DIAGNOSE_STORAGE_FREE="livre"
      MSG_DIAGNOSE_SHELL="Shell:"
      MSG_DIAGNOSE_VERSION="Versão:"
      MSG_DIAGNOSE_SERVER="Servidor:"
      MSG_DIAGNOSE_API="URL da API:"
      MSG_DIAGNOSE_GPU="GPU:"
      MSG_DIAGNOSE_STORAGE_LABEL="Armazenamento (Hablará):"
      MSG_DIAGNOSE_LOG_LABEL="Registo do Ollama (erros recentes):"
      MSG_DIAGNOSE_DISTRIBUTION="Distribuição:"
      MSG_DIAGNOSE_CREATED="Criado:"
      MSG_DIAGNOSE_SCRIPT="Script:"
      MSG_DIAGNOSE_SAVED="Relatório guardado: %s"
      MSG_DIAGNOSE_SAVE_FAILED="Não foi possível guardar o relatório"
      MSG_DIAGNOSE_UNKNOWN="desconhecido"
      MSG_DIAGNOSE_NOT_INSTALLED="não instalado"
      MSG_DIAGNOSE_NOT_REACHABLE="inacessível"
      MSG_DIAGNOSE_RUNNING="em execução"
      MSG_DIAGNOSE_NO_MODELS="    [nenhum modelo Hablará encontrado]"
      MSG_DIAGNOSE_NO_ERRORS="    [nenhum erro encontrado]"
      MSG_DIAGNOSE_NO_LOG="    [ficheiro de registo não encontrado: %s]"
      MSG_DIAGNOSE_GPU_APPLE="Apple Silicon (Metal)"
      MSG_DIAGNOSE_GPU_NVIDIA="NVIDIA (CUDA)"
      MSG_DIAGNOSE_GPU_NONE="Nenhuma"
      MSG_DIAGNOSE_RESPONDS="(responde)"
      MSG_DIAGNOSE_SECTION_SYSTEM="Sistema"
      MSG_DIAGNOSE_SECTION_OLLAMA="Ollama"
      MSG_DIAGNOSE_SECTION_MODELS="Modelos Hablará"
      MSG_DIAGNOSE_STORAGE_DISK="Armazenamento"
      MSG_DIAGNOSE_GPU_AMD="AMD (ROCm)"
      MSG_DIAGNOSE_GPU_INTEL="Intel (oneAPI)"
      MSG_GPU_STATUS_AMD="GPU: AMD (aceleração ROCm, experimental)"
      MSG_GPU_STATUS_INTEL="GPU: Intel (aceleração oneAPI, experimental)"
      MSG_HOMEBREW_INSTALLED="Ollama instalado via Homebrew"
      # Cleanup
      MSG_CLEANUP_NEEDS_TTY="--cleanup requer uma sessão interativa"
      MSG_CLEANUP_NO_OLLAMA="Ollama não encontrado"
      MSG_CLEANUP_NO_SERVER="Servidor Ollama inacessível"
      MSG_CLEANUP_START_HINT="Inicie o Ollama e tente novamente"
      MSG_CLEANUP_INSTALLED="Variantes Hablará instaladas:"
      MSG_CLEANUP_PROMPT="Qual variante remover? (número, Enter=cancelar, tempo limite 60s): "
      MSG_CLEANUP_ENTER_CANCEL="Enter=cancelar"
      MSG_CLEANUP_INVALID="Seleção inválida"
      MSG_CLEANUP_DELETED="%s removido"
      MSG_CLEANUP_FAILED="Não foi possível remover %s: %s"
      MSG_CLEANUP_UNKNOWN_ERR="erro desconhecido"
      MSG_CLEANUP_NONE_LEFT="Nenhum modelo Hablará instalado. Execute a instalação novamente para instalar um modelo."
      MSG_CLEANUP_NO_MODELS="Nenhum modelo Hablará encontrado."
      # Misc
      MSG_INTERNAL_ERROR="Erro interno: MODEL_NAME não definido"
      MSG_TEST_MODEL="A testar o modelo..."
      MSG_TEST_OK="Teste do modelo bem-sucedido"
      MSG_TEST_FAIL="Teste do modelo falhou"
      MSG_WAIT_SERVER="A aguardar o servidor Ollama..."
      MSG_SERVER_READY="Servidor Ollama pronto"
      MSG_SERVER_NO_RESPONSE="Servidor Ollama não responde após %ss"
      MSG_SETUP_FAILED="Instalação falhou"
      MSG_OLLAMA_LIST_TIMEOUT="ollama list atingiu o tempo limite (15s) na verificação do modelo"
      # Linux-specific service management
      MSG_SYSTEMD_START="A iniciar o serviço Ollama..."
      MSG_SYSTEMD_ENABLE="A ativar o serviço Ollama..."
      MSG_SYSTEMD_START_FAIL="Não foi possível iniciar o serviço Ollama"
      MSG_SERVICE_MANUAL="Iniciar manualmente: ollama serve"
      MSG_LINUX_CURL_INSTALL="A instalar curl..."
      MSG_LINUX_INSTALL_HINT="Instalar curl: sudo apt-get install -y curl"
      # Server management (start_ollama_server + show_summary)
      MSG_SERVER_ALREADY="O servidor Ollama já está em execução"
      MSG_PORT_CHECK_HINT_SS="Verificar: ss -tlnp | grep 11434"
      MSG_SYSTEMD_SYSTEM_ACTIVE="Serviço do sistema Ollama ativo, a aguardar pela API..."
      MSG_SYSTEMD_SYSTEM_START="A iniciar o Ollama via systemd (serviço do sistema)..."
      MSG_SYSTEMD_STARTED="Servidor Ollama iniciado (systemd)"
      MSG_SYSTEMD_USER_START="A iniciar o Ollama via systemd (serviço do utilizador)..."
      MSG_NOHUP_START="A iniciar o servidor Ollama (nohup)..."
      MSG_SERVER_STARTED_PID="Servidor Ollama iniciado (PID: %s)"
      MSG_PROCESS_FAILED="Processo Ollama falhou - Registo: %s"
      MSG_PROCESS_START_FAIL="Não foi possível iniciar o processo Ollama"
      MSG_SERVICE_MANAGEMENT="Gestão de serviços:"
      MSG_GPU_AMD="GPU AMD detetada (experimental)"
      MSG_GPU_INTEL="GPU Intel detetada (experimental)"
      # Help
      MSG_HELP_DESCRIPTION="Instala o Ollama e configura um modelo Hablará otimizado."
      MSG_HELP_USAGE="Uso:"
      MSG_HELP_OPTS_LABEL="OPÇÕES"
      MSG_HELP_OPTIONS="Opções:"
      MSG_HELP_OPT_MODEL="  -m, --model VARIANTE  Escolher variante: 1.5b, 3b, 7b, qwen3-8b (padrão: 3b)"
      MSG_HELP_OPT_UPDATE="  --update              Recriar o modelo personalizado Hablará (atualizar Modelfile)"
      MSG_HELP_OPT_STATUS="  --status              Verificação de status: 7 pontos de verificação da instalação do Ollama"
      MSG_HELP_OPT_DIAGNOSE="  --diagnose            Gerar relatório de suporte (texto simples, copiável)"
      MSG_HELP_OPT_CLEANUP="  --cleanup             Remover variante instalada interativamente (requer terminal)"
      MSG_HELP_OPT_LANG="  --lang CÓDIGO         Idioma: da (Dinamarquês), de (Alemão), en (Inglês), es (Espanhol), fr (Francês), it (Italiano), nl (Holandês), pl (Polaco), pt (Português), sv (Sueco)"
      MSG_HELP_OPT_HELP="  -h, --help            Mostrar esta ajuda"
      MSG_HELP_NO_OPTS="Sem opções, é iniciado um menu interativo."
      MSG_HELP_VARIANTS="Variantes de modelos:"
      MSG_HELP_EXAMPLES="Exemplos:"
      MSG_HELP_EX_MODEL="--model 3b                          Instalar variante 3b"
      MSG_HELP_EX_UPDATE="--update                            Atualizar modelo personalizado"
      MSG_HELP_EX_STATUS="--status                            Verificar instalação"
      MSG_HELP_EX_DIAGNOSE="--diagnose                          Criar relatório de erros"
      MSG_HELP_EX_CLEANUP="--cleanup                           Remover variante"
      MSG_HELP_EX_PIPE="  curl -fsSL URL | bash -s -- -m 3b      Via pipe com argumento"
      MSG_HELP_EXIT_CODES="Códigos de saída:"
      MSG_HELP_EXIT_0="  0  Sucesso"
      MSG_HELP_EXIT_1="  1  Erro geral"
      MSG_HELP_EXIT_2="  2  Espaço em disco insuficiente"
      MSG_HELP_EXIT_3="  3  Sem ligação à rede"
      MSG_HELP_EXIT_4="  4  Plataforma incorreta"
      # Hardware Detection
      MSG_HW_DETECTION_HEADER="Detecção de hardware:"
      MSG_HW_BANDWIDTH="Largura de banda de memória: ~%s GB/s · %s GB RAM"
      MSG_HW_RECOMMENDATION="Recomendação de modelo para o seu hardware:"
      MSG_HW_LOCAL_TOO_SLOW="Os modelos locais serão lentos neste hardware"
      MSG_HW_CLOUD_HINT="Recomendação: API OpenAI ou Anthropic para melhor experiência"
      MSG_HW_PROCEED_LOCAL="Instalar localmente mesmo assim? [s/N]"
      MSG_HW_TAG_RECOMMENDED="recomendado"
      MSG_HW_TAG_SLOW="lento"
      MSG_HW_TAG_TOO_SLOW="demasiado lento"
      MSG_CHOICE_PROMPT_HW="Escolha [1-4, Enter=%s]"
      MSG_HW_UNKNOWN_CHIP="Processador desconhecido — recomendação de largura de banda não disponível"
      MSG_HW_MULTI_CALL_HINT="Hablará executa várias etapas de análise por gravação"
      # Benchmark
      MSG_BENCH_RESULT="Benchmark: ~%s tok/s com %s"
      MSG_BENCH_EXCELLENT="Excelente — o seu hardware lida com este modelo com facilidade"
      MSG_BENCH_GOOD="Bom — este modelo funciona bem no seu hardware"
      MSG_BENCH_MARGINAL="Marginal — considere um modelo menor para uma experiência mais fluida"
      MSG_BENCH_TOO_SLOW="Demasiado lento — recomenda-se um modelo menor ou provedor cloud"
      MSG_BENCH_SKIP="Benchmark ignorado (medição falhou)"
      ;;
    pl)
      MSG_ERROR_PREFIX="Błąd"
      # Model Menu
      MSG_CHOOSE_MODEL="Wybierz model:"
      MSG_CHOICE_PROMPT="Wybór [1-4, Enter=1]"
      MSG_MODEL_3B="Najlepsza ogólna wydajność [Domyślny]"
      MSG_MODEL_1_5B="Szybki, ograniczona dokładność [Podstawowy]"
      MSG_MODEL_7B="Wymaga wydajnego sprzętu"
      MSG_MODEL_QWEN3="Najlepsza analiza argumentów [Premium]"
      # Main Menu
      MSG_CHOOSE_ACTION="Wybierz akcję:"
      MSG_ACTION_SETUP="Zainstaluj lub zaktualizuj Ollama"
      MSG_ACTION_STATUS="Sprawdź status"
      MSG_ACTION_DIAGNOSE="Diagnostyka (raport pomocy technicznej)"
      MSG_ACTION_CLEANUP="Wyczyść modele"
      MSG_ACTION_PROMPT="Wybór [1-4, Enter=1]"
      # Select Model / Args
      MSG_OPT_NEEDS_ARG="Opcja %s wymaga argumentu"
      MSG_UNKNOWN_OPTION="Nieznana opcja: %s"
      MSG_INVALID_MODEL="Nieprawidłowy wariant modelu: %s"
      MSG_VALID_VARIANTS="Prawidłowe warianty: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b"
      MSG_RAM_WARN_MODEL="Ten model wymaga co najmniej %sGB pamięci RAM"
      MSG_RAM_WARN_SYS="Twój system ma %sGB pamięci RAM"
      MSG_CONTINUE_ANYWAY="Kontynuować mimo to?"
      MSG_CONFIRM_PROMPT="[t/N]"
      MSG_CONFIRM_YES='^[tT]$'
      MSG_ABORTED="Anulowano."
      MSG_SELECTED_MODEL="Wybrany model: %s"
      MSG_PROCEED_NONINTERACTIVE="Kontynuowanie..."
      # Preflight
      MSG_PREFLIGHT="Wykonywanie wstępnych sprawdzeń..."
      MSG_PLATFORM_ERROR_MAC="Ten skrypt jest przeznaczony tylko dla macOS"
      MSG_PLATFORM_LINUX_HINT="Dla Linux: scripts/setup-ollama-linux.sh"
      MSG_PLATFORM_ERROR_LINUX="Ten skrypt jest przeznaczony tylko dla Linux"
      MSG_PLATFORM_MAC_HINT="Dla macOS: scripts/setup-ollama-mac.sh"
      MSG_TOOL_MISSING="%s nie znaleziono (zainstaluj)"
      MSG_DISK_INSUFFICIENT="Niewystarczające miejsce na dysku: dostępne %sGB, wymagane %sGB"
      MSG_DISK_OK="Miejsce na dysku: dostępne %sGB"
      MSG_NETWORK_ERROR="Brak połączenia sieciowego z ollama.com"
      MSG_NETWORK_HINT="Sprawdź: curl -I https://ollama.com"
      MSG_NETWORK_OK="Połączenie sieciowe OK"
      MSG_GPU_APPLE="Wykryto Apple Silicon (akceleracja Metal)"
      MSG_GPU_NVIDIA="Wykryto GPU NVIDIA (akceleracja CUDA)"
      MSG_GPU_NONE="Nie wykryto GPU — przetwarzanie bez akceleracji GPU"
      # Install Ollama
      MSG_INSTALLING_OLLAMA="Instalowanie Ollama..."
      MSG_OLLAMA_ALREADY="Ollama jest już zainstalowane"
      MSG_OLLAMA_VERSION="Wersja: %s"
      MSG_CHECKING_SERVER="Sprawdzanie serwera Ollama..."
      MSG_SERVER_START_FAILED="Nie udało się uruchomić serwera Ollama"
      MSG_SERVER_START_HINT="Uruchom ręcznie: ollama serve"
      MSG_SERVER_RUNNING="Serwer Ollama działa"
      MSG_USING_BREW="Używanie Homebrew (limit czasu: 10 minut)..."
      MSG_BREW_TIMEOUT="brew install przekroczył limit czasu 10 minut"
      MSG_BREW_ALT="Alternatywa: https://ollama.com/download"
      MSG_BREW_FAILED="Instalacja przez Homebrew nie powiodła się"
      MSG_OLLAMA_PATH_ERROR="Ollama zainstalowane, ale CLI nie jest w PATH"
      MSG_PATH_HINT="Uruchom ponownie terminal lub sprawdź PATH"
      MSG_SERVER_START_WARN="Nie udało się uruchomić serwera — uruchom ręcznie: ollama serve"
      MSG_DOWNLOADING_INSTALLER="Pobieranie instalatora Ollama..."
      MSG_INSTALLER_DOWNLOAD_FAILED="Pobieranie instalatora nie powiodło się"
      MSG_MANUAL_INSTALL="Instalacja ręczna: https://ollama.com/download"
      MSG_RUNNING_INSTALLER="Uruchamianie instalatora (limit czasu: 5 minut)..."
      MSG_INSTALLER_TIMEOUT="Instalator przekroczył limit czasu 5 minut"
      MSG_INSTALL_FAILED="Instalacja Ollama nie powiodła się"
      MSG_OLLAMA_INSTALLED="Ollama zainstalowane"
      MSG_APT_HINT="Zainstaluj: sudo apt-get install -y curl"
      MSG_OLLAMA_FOUND="Znaleziono Ollama: %s"
      MSG_OLLAMA_BREW_FOUND="Znaleziono Ollama przez Homebrew: %s"
      MSG_PORT_BUSY="Port 11434 zajęty, oczekiwanie na API Ollama..."
      MSG_PORT_BUSY_WARN="Port 11434 zajęty, ale API Ollama nie odpowiada"
      MSG_PORT_CHECK_HINT="Sprawdź: lsof -i :11434"
      MSG_VERSION_WARN="Ollama w wersji %s jest starsza od zalecanej (%s)"
      MSG_UPDATE_HINT_BREW="Aktualizuj: brew upgrade ollama"
      MSG_UPDATE_HINT_APT="Aktualizuj: sudo apt-get install ollama"
      # Model Download
      MSG_DOWNLOADING_BASE="Pobieranie modelu bazowego..."
      MSG_MODEL_EXISTS="Model już dostępny: %s"
      MSG_DOWNLOADING_MODEL="Pobieranie %s (%s, może potrwać kilka minut w zależności od połączenia)..."
      MSG_DOWNLOAD_RESUME_TIP="Wskazówka: Po przerwaniu (Ctrl+C) pobieranie zostanie wznowione po ponownym uruchomieniu"
      MSG_DOWNLOAD_HARD_TIMEOUT="Osiągnięto twardy limit czasu %s minut — anulowanie"
      MSG_DOWNLOAD_STALL="Brak postępu pobierania przez %s minut — anulowanie"
      MSG_DOWNLOAD_RUNNING="  Pobieranie w toku... (%ss)"
      MSG_DOWNLOAD_TIMEOUT_WARN="Przekroczono limit czasu pobierania po %s minutach (próba %s/3)"
      MSG_DOWNLOAD_FAILED_WARN="Pobieranie nie powiodło się (próba %s/3)"
      MSG_DOWNLOAD_RETRY="Następna próba za 5s..."
      MSG_DOWNLOAD_FAILED="Pobieranie modelu nie powiodło się po 3 próbach"
      MSG_DOWNLOAD_MANUAL="Spróbuj ręcznie: ollama pull %s"
      MSG_DOWNLOAD_DONE="Model pobrany: %s"
      # Custom Model
      MSG_CREATING_CUSTOM="Tworzenie modelu Hablará..."
      MSG_UPDATING_CUSTOM="Aktualizowanie istniejącego modelu Hablará..."
      MSG_CUSTOM_EXISTS="    • Model Hablará %s już dostępny."
      MSG_CUSTOM_SKIP="Pomiń (bez zmian)"
      MSG_CUSTOM_UPDATE_OPT="Zaktualizuj model Hablará"
      MSG_CUSTOM_UPDATE_PROMPT="Wybór [1-2, Enter=1]"
      MSG_CUSTOM_KEPT="Model Hablará zachowany"
      MSG_CUSTOM_PRESENT="Model Hablará już dostępny"
      MSG_USING_HABLARA_CONFIG="Używanie konfiguracji Hablará"
      MSG_USING_DEFAULT_CONFIG="Używanie domyślnej konfiguracji"
      MSG_CUSTOM_CREATING="Tworzenie modelu Hablará %s..."
      MSG_CUSTOM_CREATE_TIMEOUT="ollama create przekroczył limit czasu 120s — używanie modelu bazowego"
      MSG_CUSTOM_CREATE_FAILED="Nie udało się %s modelu Hablará — używanie modelu bazowego"
      MSG_CUSTOM_DONE="Model Hablará %s: %s"
      MSG_VERB_CREATED="utworzony"
      MSG_VERB_UPDATED="zaktualizowany"
      # Verify
      MSG_VERIFYING="Weryfikowanie instalacji..."
      MSG_OLLAMA_NOT_FOUND="Nie znaleziono Ollama"
      MSG_SERVER_UNREACHABLE="Serwer Ollama niedostępny"
      MSG_BASE_NOT_FOUND="Nie znaleziono modelu bazowego: %s"
      MSG_BASE_OK="Model bazowy dostępny: %s"
      MSG_CUSTOM_OK="Model Hablará dostępny: %s"
      MSG_CUSTOM_UNAVAILABLE="Model Hablará niedostępny (używanie modelu bazowego)"
      MSG_INFERENCE_FAILED="Test modelu nie powiódł się, przetestuj w aplikacji"
      MSG_SETUP_DONE="Instalacja zakończona!"
      # Main Summary
      MSG_SETUP_COMPLETE="Instalacja Ollama dla Hablará zakończona!"
      MSG_INSTALLED="Zainstalowano:"
      MSG_BASE_MODEL_LABEL="  Model bazowy:    "
      MSG_HABLARA_MODEL_LABEL="  Model Hablará:   "
      MSG_OLLAMA_CONFIG="Konfiguracja Ollama:"
      MSG_MODEL_LABEL="  Model:    "
      MSG_BASE_URL_LABEL="  Base URL: "
      MSG_DOCS="Dokumentacja: https://github.com/fidpa/hablara"
      # Status
      MSG_STATUS_TITLE_MAC="Hablará Ollama Status (macOS)"
      MSG_STATUS_TITLE_LINUX="Hablará Ollama Status (Linux)"
      MSG_STATUS_INSTALLED="Ollama zainstalowane (v%s)"
      MSG_STATUS_UPDATE_REC_BREW="  ↳ Zalecana aktualizacja (minimum v%s): brew upgrade ollama"
      MSG_STATUS_UPDATE_REC_APT="  ↳ Zalecana aktualizacja (minimum v%s): sudo apt-get install ollama"
      MSG_STATUS_NOT_FOUND="Nie znaleziono Ollama"
      MSG_STATUS_SERVER_OK="Serwer działa"
      MSG_STATUS_SERVER_FAIL="Serwer niedostępny"
      MSG_STATUS_GPU_APPLE="GPU: Apple Silicon (akceleracja Metal)"
      MSG_STATUS_GPU_NVIDIA="GPU: NVIDIA (akceleracja CUDA)"
      MSG_STATUS_NO_GPU="Brak GPU — przetwarzanie bez akceleracji GPU"
      MSG_STATUS_BASE_MODEL="Model bazowy: %s"
      MSG_STATUS_BASE_MODELS="Modele bazowe:"
      MSG_STATUS_NO_BASE="Nie znaleziono modelu bazowego"
      MSG_STATUS_HABLARA_MODEL="Model Hablará: %s"
      MSG_STATUS_HABLARA_MODELS="Modele Hablará:"
      MSG_STATUS_NO_HABLARA="Nie znaleziono modelu Hablará"
      MSG_STATUS_BASE_MISSING="  ↳ Brak modelu bazowego — model Hablará potrzebuje go jako podstawy"
      MSG_STATUS_INFERENCE_SKIP="Test modelu pominięty (serwer niedostępny)"
      MSG_STATUS_MODEL_OK="Model odpowiada"
      MSG_STATUS_MODEL_FAIL="Model nie odpowiada"
      MSG_STATUS_STORAGE="Użycie pamięci (Hablará): ~%s GB"
      MSG_STATUS_STORAGE_UNKNOWN="Użycie pamięci: nie można określić"
      MSG_STATUS_ALL_OK="Wszystko jest w porządku."
      MSG_STATUS_PROBLEMS="Znaleziono %s problem(y/ów)."
      MSG_STATUS_REPAIR="    Napraw:"
      # Diagnose
      MSG_DIAGNOSE_TITLE="=== Raport diagnostyczny Ollama Hablará ==="
      MSG_DIAGNOSE_OS="System:"
      MSG_DIAGNOSE_RAM="RAM:"
      MSG_DIAGNOSE_RAM_AVAIL="dostępne"
      MSG_DIAGNOSE_STORAGE_FREE="wolne"
      MSG_DIAGNOSE_SHELL="Shell:"
      MSG_DIAGNOSE_VERSION="Wersja:"
      MSG_DIAGNOSE_SERVER="Serwer:"
      MSG_DIAGNOSE_API="URL API:"
      MSG_DIAGNOSE_GPU="GPU:"
      MSG_DIAGNOSE_STORAGE_LABEL="Pamięć (Hablará):"
      MSG_DIAGNOSE_LOG_LABEL="Dziennik Ollama (ostatnie błędy):"
      MSG_DIAGNOSE_DISTRIBUTION="Dystrybucja:"
      MSG_DIAGNOSE_CREATED="Utworzono:"
      MSG_DIAGNOSE_SCRIPT="Skrypt:"
      MSG_DIAGNOSE_SAVED="Raport zapisany: %s"
      MSG_DIAGNOSE_SAVE_FAILED="Nie można zapisać raportu"
      MSG_DIAGNOSE_UNKNOWN="nieznane"
      MSG_DIAGNOSE_NOT_INSTALLED="nie zainstalowane"
      MSG_DIAGNOSE_NOT_REACHABLE="niedostępne"
      MSG_DIAGNOSE_RUNNING="działa"
      MSG_DIAGNOSE_NO_MODELS="    [nie znaleziono modeli Hablará]"
      MSG_DIAGNOSE_NO_ERRORS="    [nie znaleziono błędów]"
      MSG_DIAGNOSE_NO_LOG="    [nie znaleziono pliku dziennika: %s]"
      MSG_DIAGNOSE_GPU_APPLE="Apple Silicon (Metal)"
      MSG_DIAGNOSE_GPU_NVIDIA="NVIDIA (CUDA)"
      MSG_DIAGNOSE_GPU_NONE="Brak"
      MSG_DIAGNOSE_RESPONDS="(odpowiada)"
      MSG_DIAGNOSE_SECTION_SYSTEM="System"
      MSG_DIAGNOSE_SECTION_OLLAMA="Ollama"
      MSG_DIAGNOSE_SECTION_MODELS="Modele Hablará"
      MSG_DIAGNOSE_STORAGE_DISK="Pamięć"
      MSG_DIAGNOSE_GPU_AMD="AMD (ROCm)"
      MSG_DIAGNOSE_GPU_INTEL="Intel (oneAPI)"
      MSG_GPU_STATUS_AMD="GPU: AMD (akceleracja ROCm, eksperymentalne)"
      MSG_GPU_STATUS_INTEL="GPU: Intel (akceleracja oneAPI, eksperymentalne)"
      MSG_HOMEBREW_INSTALLED="Ollama zainstalowane przez Homebrew"
      # Cleanup
      MSG_CLEANUP_NEEDS_TTY="--cleanup wymaga sesji interaktywnej"
      MSG_CLEANUP_NO_OLLAMA="Nie znaleziono Ollama"
      MSG_CLEANUP_NO_SERVER="Serwer Ollama niedostępny"
      MSG_CLEANUP_START_HINT="Uruchom Ollama i spróbuj ponownie"
      MSG_CLEANUP_INSTALLED="Zainstalowane warianty Hablará:"
      MSG_CLEANUP_PROMPT="Który wariant usunąć? (numer, Enter=anuluj, limit czasu 60s): "
      MSG_CLEANUP_ENTER_CANCEL="Enter=anuluj"
      MSG_CLEANUP_INVALID="Nieprawidłowy wybór"
      MSG_CLEANUP_DELETED="%s usunięty"
      MSG_CLEANUP_FAILED="Nie udało się usunąć %s: %s"
      MSG_CLEANUP_UNKNOWN_ERR="nieznany błąd"
      MSG_CLEANUP_NONE_LEFT="Nie zainstalowano żadnych modeli Hablará. Uruchom ponownie instalację, aby zainstalować model."
      MSG_CLEANUP_NO_MODELS="Nie znaleziono modeli Hablará."
      # Misc
      MSG_INTERNAL_ERROR="Błąd wewnętrzny: MODEL_NAME nie zdefiniowany"
      MSG_TEST_MODEL="Testowanie modelu..."
      MSG_TEST_OK="Test modelu zakończony pomyślnie"
      MSG_TEST_FAIL="Test modelu nie powiódł się"
      MSG_WAIT_SERVER="Oczekiwanie na serwer Ollama..."
      MSG_SERVER_READY="Serwer Ollama gotowy"
      MSG_SERVER_NO_RESPONSE="Serwer Ollama nie odpowiada po %ss"
      MSG_SETUP_FAILED="Instalacja nie powiodła się"
      MSG_OLLAMA_LIST_TIMEOUT="ollama list przekroczył limit czasu (15s) podczas sprawdzania modelu"
      # Linux-specific service management
      MSG_SYSTEMD_START="Uruchamianie usługi Ollama..."
      MSG_SYSTEMD_ENABLE="Włączanie usługi Ollama..."
      MSG_SYSTEMD_START_FAIL="Nie udało się uruchomić usługi Ollama"
      MSG_SERVICE_MANUAL="Uruchom ręcznie: ollama serve"
      MSG_LINUX_CURL_INSTALL="Instalowanie curl..."
      MSG_LINUX_INSTALL_HINT="Zainstaluj curl: sudo apt-get install -y curl"
      # Server management (start_ollama_server + show_summary)
      MSG_SERVER_ALREADY="Serwer Ollama jest już uruchomiony"
      MSG_PORT_CHECK_HINT_SS="Sprawdź: ss -tlnp | grep 11434"
      MSG_SYSTEMD_SYSTEM_ACTIVE="Usługa systemowa Ollama aktywna, oczekiwanie na API..."
      MSG_SYSTEMD_SYSTEM_START="Uruchamianie Ollama przez systemd (usługa systemowa)..."
      MSG_SYSTEMD_STARTED="Serwer Ollama uruchomiony (systemd)"
      MSG_SYSTEMD_USER_START="Uruchamianie Ollama przez systemd (usługa użytkownika)..."
      MSG_NOHUP_START="Uruchamianie serwera Ollama (nohup)..."
      MSG_SERVER_STARTED_PID="Serwer Ollama uruchomiony (PID: %s)"
      MSG_PROCESS_FAILED="Proces Ollama nie powiódł się — Dziennik: %s"
      MSG_PROCESS_START_FAIL="Nie udało się uruchomić procesu Ollama"
      MSG_SERVICE_MANAGEMENT="Zarządzanie usługami:"
      MSG_GPU_AMD="Wykryto GPU AMD (eksperymentalne)"
      MSG_GPU_INTEL="Wykryto GPU Intel (eksperymentalne)"
      # Help
      MSG_HELP_DESCRIPTION="Instaluje Ollama i konfiguruje zoptymalizowany model Hablará."
      MSG_HELP_USAGE="Użycie:"
      MSG_HELP_OPTS_LABEL="OPCJE"
      MSG_HELP_OPTIONS="Opcje:"
      MSG_HELP_OPT_MODEL="  -m, --model WARIANT   Wybierz wariant: 1.5b, 3b, 7b, qwen3-8b (domyślny: 3b)"
      MSG_HELP_OPT_UPDATE="  --update              Odtwórz niestandardowy model Hablará (aktualizacja Modelfile)"
      MSG_HELP_OPT_STATUS="  --status              Sprawdzenie statusu: 7 punktów kontrolnych instalacji Ollama"
      MSG_HELP_OPT_DIAGNOSE="  --diagnose            Generuj raport pomocy technicznej (tekst, do skopiowania)"
      MSG_HELP_OPT_CLEANUP="  --cleanup             Interaktywne usuwanie zainstalowanego wariantu (wymaga terminala)"
      MSG_HELP_OPT_LANG="  --lang KOD            Język: da (Duński), de (Niemiecki), en (Angielski), es (Hiszpański), fr (Francuski), it (Włoski), nl (Niderlandzki), pl (Polski), pt (Portugalski), sv (Szwedzki)"
      MSG_HELP_OPT_HELP="  -h, --help            Wyświetl tę pomoc"
      MSG_HELP_NO_OPTS="Bez opcji uruchamiany jest interaktywny menu."
      MSG_HELP_VARIANTS="Warianty modeli:"
      MSG_HELP_EXAMPLES="Przykłady:"
      MSG_HELP_EX_MODEL="--model 3b                          Zainstaluj wariant 3b"
      MSG_HELP_EX_UPDATE="--update                            Zaktualizuj niestandardowy model"
      MSG_HELP_EX_STATUS="--status                            Sprawdź instalację"
      MSG_HELP_EX_DIAGNOSE="--diagnose                          Utwórz raport błędów"
      MSG_HELP_EX_CLEANUP="--cleanup                           Usuń wariant"
      MSG_HELP_EX_PIPE="  curl -fsSL URL | bash -s -- -m 3b      Przez potok z argumentem"
      MSG_HELP_EXIT_CODES="Kody wyjścia:"
      MSG_HELP_EXIT_0="  0  Sukces"
      MSG_HELP_EXIT_1="  1  Błąd ogólny"
      MSG_HELP_EXIT_2="  2  Niewystarczające miejsce na dysku"
      MSG_HELP_EXIT_3="  3  Brak połączenia sieciowego"
      MSG_HELP_EXIT_4="  4  Nieprawidłowa platforma"
      # Hardware Detection
      MSG_HW_DETECTION_HEADER="Wykrywanie sprzętu:"
      MSG_HW_BANDWIDTH="Przepustowość pamięci: ~%s GB/s · %s GB RAM"
      MSG_HW_RECOMMENDATION="Rekomendacja modelu dla Twojego sprzętu:"
      MSG_HW_LOCAL_TOO_SLOW="Lokalne modele będą wolne na tym sprzęcie"
      MSG_HW_CLOUD_HINT="Rekomendacja: API OpenAI lub Anthropic dla najlepszego doświadczenia"
      MSG_HW_PROCEED_LOCAL="Zainstalować lokalnie mimo to? [t/N]"
      MSG_HW_TAG_RECOMMENDED="zalecany"
      MSG_HW_TAG_SLOW="wolny"
      MSG_HW_TAG_TOO_SLOW="za wolny"
      MSG_CHOICE_PROMPT_HW="Wybór [1-4, Enter=%s]"
      MSG_HW_UNKNOWN_CHIP="Nieznany procesor — brak rekomendacji przepustowości"
      MSG_HW_MULTI_CALL_HINT="Hablará wykonuje wiele kroków analizy na nagranie"
      # Benchmark
      MSG_BENCH_RESULT="Benchmark: ~%s tok/s z %s"
      MSG_BENCH_EXCELLENT="Doskonały — twój sprzęt obsługuje ten model bez trudu"
      MSG_BENCH_GOOD="Dobrze — ten model działa dobrze na twoim sprzęcie"
      MSG_BENCH_MARGINAL="Graniczny — mniejszy model zapewni płynniejsze działanie"
      MSG_BENCH_TOO_SLOW="Za wolno — zalecany jest mniejszy model lub dostawca chmury"
      MSG_BENCH_SKIP="Pominięto benchmark (pomiar nie powiódł się)"
      ;;
    sv)
      MSG_ERROR_PREFIX="Fel"
      # Model Menu
      MSG_CHOOSE_MODEL="Välj en modell:"
      MSG_CHOICE_PROMPT="Val [1-4, Enter=1]"
      MSG_MODEL_3B="Optimal helhetsprestanda [Standard]"
      MSG_MODEL_1_5B="Snabb, begränsad noggrannhet [Grundnivå]"
      MSG_MODEL_7B="Kräver kraftfull hårdvara"
      MSG_MODEL_QWEN3="Bästa argumentationsanalys [Premium]"
      # Main Menu
      MSG_CHOOSE_ACTION="Välj en åtgärd:"
      MSG_ACTION_SETUP="Installera eller uppdatera Ollama"
      MSG_ACTION_STATUS="Kontrollera status"
      MSG_ACTION_DIAGNOSE="Diagnostik (supportrapport)"
      MSG_ACTION_CLEANUP="Rensa modeller"
      MSG_ACTION_PROMPT="Val [1-4, Enter=1]"
      # Select Model / Args
      MSG_OPT_NEEDS_ARG="Alternativet %s kräver ett argument"
      MSG_UNKNOWN_OPTION="Okänt alternativ: %s"
      MSG_INVALID_MODEL="Ogiltig modellvariant: %s"
      MSG_VALID_VARIANTS="Giltiga varianter: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b"
      MSG_RAM_WARN_MODEL="Den här modellen rekommenderar minst %sGB RAM"
      MSG_RAM_WARN_SYS="Ditt system har %sGB RAM"
      MSG_CONTINUE_ANYWAY="Fortsätt ändå?"
      MSG_CONFIRM_PROMPT="[j/N]"
      MSG_CONFIRM_YES='^[jJyY]$'
      MSG_ABORTED="Avbruten."
      MSG_SELECTED_MODEL="Vald modell: %s"
      MSG_PROCEED_NONINTERACTIVE="Fortsätter..."
      # Preflight
      MSG_PREFLIGHT="Kör förkontroller..."
      MSG_PLATFORM_ERROR_MAC="Det här skriptet är endast för macOS"
      MSG_PLATFORM_LINUX_HINT="För Linux: scripts/setup-ollama-linux.sh"
      MSG_PLATFORM_ERROR_LINUX="Det här skriptet är endast för Linux"
      MSG_PLATFORM_MAC_HINT="För macOS: scripts/setup-ollama-mac.sh"
      MSG_TOOL_MISSING="%s saknas (installera det)"
      MSG_DISK_INSUFFICIENT="Inte tillräckligt med utrymme: %sGB tillgängligt, %sGB krävs"
      MSG_DISK_OK="Diskutrymme: %sGB tillgängligt"
      MSG_NETWORK_ERROR="Ingen nätverksanslutning till ollama.com"
      MSG_NETWORK_HINT="Kontrollera: curl -I https://ollama.com"
      MSG_NETWORK_OK="Nätverksanslutning OK"
      MSG_GPU_APPLE="Apple Silicon detekterat (Metal-acceleration)"
      MSG_GPU_NVIDIA="NVIDIA GPU detekterat (CUDA-acceleration)"
      MSG_GPU_NONE="Ingen GPU detekterad – bearbetning utan GPU-acceleration"
      # Install Ollama
      MSG_INSTALLING_OLLAMA="Installerar Ollama..."
      MSG_OLLAMA_ALREADY="Ollama är redan installerat"
      MSG_OLLAMA_VERSION="Version: %s"
      MSG_CHECKING_SERVER="Kontrollerar Ollama-server..."
      MSG_SERVER_START_FAILED="Kunde inte starta Ollama-server"
      MSG_SERVER_START_HINT="Starta manuellt: ollama serve"
      MSG_SERVER_RUNNING="Ollama-server körs"
      MSG_USING_BREW="Använder Homebrew (timeout: 10 minuter)..."
      MSG_BREW_TIMEOUT="brew install timeout efter 10 minuter"
      MSG_BREW_ALT="Alternativ: https://ollama.com/download"
      MSG_BREW_FAILED="Homebrew-installation misslyckades"
      MSG_OLLAMA_PATH_ERROR="Ollama installerat men CLI inte i PATH"
      MSG_PATH_HINT="Starta om terminalen eller kontrollera PATH"
      MSG_SERVER_START_WARN="Serverstart misslyckades – starta manuellt: ollama serve"
      MSG_DOWNLOADING_INSTALLER="Laddar ned Ollama-installerare..."
      MSG_INSTALLER_DOWNLOAD_FAILED="Nedladdning av installerare misslyckades"
      MSG_MANUAL_INSTALL="Manuell installation: https://ollama.com/download"
      MSG_RUNNING_INSTALLER="Kör installerare (timeout: 5 minuter)..."
      MSG_INSTALLER_TIMEOUT="Installerare timeout efter 5 minuter"
      MSG_INSTALL_FAILED="Ollama-installation misslyckades"
      MSG_OLLAMA_INSTALLED="Ollama installerat"
      MSG_APT_HINT="Installera: sudo apt-get install -y curl"
      MSG_OLLAMA_FOUND="Ollama hittad: %s"
      MSG_OLLAMA_BREW_FOUND="Ollama via Homebrew hittad: %s"
      MSG_PORT_BUSY="Port 11434 är upptagen, väntar på Ollama API..."
      MSG_PORT_BUSY_WARN="Port 11434 upptagen men Ollama API svarar inte"
      MSG_PORT_CHECK_HINT="Kontrollera: lsof -i :11434"
      MSG_VERSION_WARN="Ollama-version %s är äldre än rekommenderad (%s)"
      MSG_UPDATE_HINT_BREW="Uppdatera: brew upgrade ollama"
      MSG_UPDATE_HINT_APT="Uppdatera: sudo apt-get install ollama"
      # Model Download
      MSG_DOWNLOADING_BASE="Laddar ned basmodell..."
      MSG_MODEL_EXISTS="Modell finns redan: %s"
      MSG_DOWNLOADING_MODEL="Laddar ned %s (%s, tar flera minuter beroende på anslutning)..."
      MSG_DOWNLOAD_RESUME_TIP="Tips: Om avbrutet (Ctrl+C) fortsätter nedladdningen vid omstart"
      MSG_DOWNLOAD_HARD_TIMEOUT="Hård timeout efter %s minuter – avbryter"
      MSG_DOWNLOAD_STALL="Ingen nedladdningsframgång under %s minuter – avbryter"
      MSG_DOWNLOAD_RUNNING="  Nedladdning pågår... (%ss)"
      MSG_DOWNLOAD_TIMEOUT_WARN="Nedladdningstimeout efter %s minuter (försök %s/3)"
      MSG_DOWNLOAD_FAILED_WARN="Nedladdning misslyckades (försök %s/3)"
      MSG_DOWNLOAD_RETRY="Nästa försök om 5s..."
      MSG_DOWNLOAD_FAILED="Modellnedladdning misslyckades efter 3 försök"
      MSG_DOWNLOAD_MANUAL="Prova manuellt: ollama pull %s"
      MSG_DOWNLOAD_DONE="Modell nedladdad: %s"
      # Custom Model
      MSG_CREATING_CUSTOM="Skapar Hablará-modell..."
      MSG_UPDATING_CUSTOM="Uppdaterar befintlig Hablará-modell..."
      MSG_CUSTOM_EXISTS="    • Hablará-modell %s finns redan."
      MSG_CUSTOM_SKIP="Hoppa över (inga ändringar)"
      MSG_CUSTOM_UPDATE_OPT="Uppdatera Hablará-modell"
      MSG_CUSTOM_UPDATE_PROMPT="Val [1-2, Enter=1]"
      MSG_CUSTOM_KEPT="Hablará-modell behållen"
      MSG_CUSTOM_PRESENT="Hablará-modell finns redan"
      MSG_USING_HABLARA_CONFIG="Använder Hablará-konfiguration"
      MSG_USING_DEFAULT_CONFIG="Använder standardkonfiguration"
      MSG_CUSTOM_CREATING="Skapar Hablará-modell %s..."
      MSG_CUSTOM_CREATE_TIMEOUT="ollama create timeout efter 120s – använder basmodell"
      MSG_CUSTOM_CREATE_FAILED="Hablará-modell kunde inte %s – använder basmodell"
      MSG_CUSTOM_DONE="Hablará-modell %s: %s"
      MSG_VERB_CREATED="skapad"
      MSG_VERB_UPDATED="uppdaterad"
      # Verify
      MSG_VERIFYING="Verifierar installation..."
      MSG_OLLAMA_NOT_FOUND="Ollama hittades inte"
      MSG_SERVER_UNREACHABLE="Ollama-server inte nåbar"
      MSG_BASE_NOT_FOUND="Basmodell hittades inte: %s"
      MSG_BASE_OK="Basmodell tillgänglig: %s"
      MSG_CUSTOM_OK="Hablará-modell tillgänglig: %s"
      MSG_CUSTOM_UNAVAILABLE="Hablará-modell otillgänglig (använder basmodell)"
      MSG_INFERENCE_FAILED="Modelltest misslyckades, testa i appen"
      MSG_SETUP_DONE="Installation klar!"
      # Main Summary
      MSG_SETUP_COMPLETE="Hablará Ollama-installation klar!"
      MSG_INSTALLED="Installerat:"
      MSG_BASE_MODEL_LABEL="  Basmodell:        "
      MSG_HABLARA_MODEL_LABEL="  Hablará-modell: "
      MSG_OLLAMA_CONFIG="Ollama-konfiguration:"
      MSG_MODEL_LABEL="  Modell:    "
      MSG_BASE_URL_LABEL="  Bas-URL:   "
      MSG_DOCS="Dokumentation: https://github.com/fidpa/hablara"
      # Status
      MSG_STATUS_TITLE_MAC="Hablará Ollama-status (macOS)"
      MSG_STATUS_TITLE_LINUX="Hablará Ollama-status (Linux)"
      MSG_STATUS_INSTALLED="Ollama installerat (v%s)"
      MSG_STATUS_UPDATE_REC_BREW="  ↳ Uppdatering rekommenderas (minimum v%s): brew upgrade ollama"
      MSG_STATUS_UPDATE_REC_APT="  ↳ Uppdatering rekommenderas (minimum v%s): sudo apt-get install ollama"
      MSG_STATUS_NOT_FOUND="Ollama hittades inte"
      MSG_STATUS_SERVER_OK="Server körs"
      MSG_STATUS_SERVER_FAIL="Server inte nåbar"
      MSG_STATUS_GPU_APPLE="GPU: Apple Silicon (Metal-acceleration)"
      MSG_STATUS_GPU_NVIDIA="GPU: NVIDIA (CUDA-acceleration)"
      MSG_STATUS_NO_GPU="Ingen GPU – bearbetning utan GPU-acceleration"
      MSG_STATUS_BASE_MODEL="Basmodell: %s"
      MSG_STATUS_BASE_MODELS="Basmodeller:"
      MSG_STATUS_NO_BASE="Ingen basmodell hittad"
      MSG_STATUS_HABLARA_MODEL="Hablará-modell: %s"
      MSG_STATUS_HABLARA_MODELS="Hablará-modeller:"
      MSG_STATUS_NO_HABLARA="Ingen Hablará-modell hittad"
      MSG_STATUS_BASE_MISSING="  ↳ Basmodell saknas – Hablará-modell kräver den som grund"
      MSG_STATUS_INFERENCE_SKIP="Modelltest hoppades över (server inte nåbar)"
      MSG_STATUS_MODEL_OK="Modell svarar"
      MSG_STATUS_MODEL_FAIL="Modell svarar inte"
      MSG_STATUS_STORAGE="Lagringsanvändning (Hablará): ~%s GB"
      MSG_STATUS_STORAGE_UNKNOWN="Lagringsanvändning: ej bestämbar"
      MSG_STATUS_ALL_OK="Allt är i ordning."
      MSG_STATUS_PROBLEMS="%s problem hittade."
      MSG_STATUS_REPAIR="    Reparera:"
      # Diagnose
      MSG_DIAGNOSE_TITLE="=== Hablará Ollama Diagnostikrapport ==="
      MSG_DIAGNOSE_OS="OS:"
      MSG_DIAGNOSE_RAM="RAM:"
      MSG_DIAGNOSE_RAM_AVAIL="tillgängligt"
      MSG_DIAGNOSE_STORAGE_FREE="fritt"
      MSG_DIAGNOSE_SHELL="Shell:"
      MSG_DIAGNOSE_VERSION="Version:"
      MSG_DIAGNOSE_SERVER="Server:"
      MSG_DIAGNOSE_API="API-URL:"
      MSG_DIAGNOSE_GPU="GPU:"
      MSG_DIAGNOSE_STORAGE_LABEL="Lagring (Hablará):"
      MSG_DIAGNOSE_LOG_LABEL="Ollama-logg (senaste fel):"
      MSG_DIAGNOSE_DISTRIBUTION="Distribution:"
      MSG_DIAGNOSE_CREATED="Skapad:"
      MSG_DIAGNOSE_SCRIPT="Skript:"
      MSG_DIAGNOSE_SAVED="Rapport sparad: %s"
      MSG_DIAGNOSE_SAVE_FAILED="Det gick inte att spara rapporten"
      MSG_DIAGNOSE_UNKNOWN="okänd"
      MSG_DIAGNOSE_NOT_INSTALLED="inte installerat"
      MSG_DIAGNOSE_NOT_REACHABLE="inte nåbar"
      MSG_DIAGNOSE_RUNNING="körs"
      MSG_DIAGNOSE_NO_MODELS="    [inga Hablará-modeller hittade]"
      MSG_DIAGNOSE_NO_ERRORS="    [inga fel hittade]"
      MSG_DIAGNOSE_NO_LOG="    [loggfil hittades inte: %s]"
      MSG_DIAGNOSE_GPU_APPLE="Apple Silicon (Metal)"
      MSG_DIAGNOSE_GPU_NVIDIA="NVIDIA (CUDA)"
      MSG_DIAGNOSE_GPU_NONE="Ingen"
      MSG_DIAGNOSE_RESPONDS="(svarar)"
      MSG_DIAGNOSE_SECTION_SYSTEM="System"
      MSG_DIAGNOSE_SECTION_OLLAMA="Ollama"
      MSG_DIAGNOSE_SECTION_MODELS="Hablará-modeller"
      MSG_DIAGNOSE_STORAGE_DISK="Lagring"
      MSG_DIAGNOSE_GPU_AMD="AMD (ROCm)"
      MSG_DIAGNOSE_GPU_INTEL="Intel (oneAPI)"
      MSG_GPU_STATUS_AMD="GPU: AMD (ROCm-acceleration, experimentell)"
      MSG_GPU_STATUS_INTEL="GPU: Intel (oneAPI-acceleration, experimentell)"
      MSG_HOMEBREW_INSTALLED="Ollama installerat via Homebrew"
      # Cleanup
      MSG_CLEANUP_NEEDS_TTY="--cleanup kräver en interaktiv session"
      MSG_CLEANUP_NO_OLLAMA="Ollama hittades inte"
      MSG_CLEANUP_NO_SERVER="Ollama-server inte nåbar"
      MSG_CLEANUP_START_HINT="Starta Ollama och försök igen"
      MSG_CLEANUP_INSTALLED="Installerade Hablará-varianter:"
      MSG_CLEANUP_PROMPT="Vilken variant ska tas bort? (nummer, Enter=avbryt, timeout 60s): "
      MSG_CLEANUP_ENTER_CANCEL="Enter=avbryt"
      MSG_CLEANUP_INVALID="Ogiltigt val"
      MSG_CLEANUP_DELETED="%s borttagen"
      MSG_CLEANUP_FAILED="%s kunde inte tas bort: %s"
      MSG_CLEANUP_UNKNOWN_ERR="okänt fel"
      MSG_CLEANUP_NONE_LEFT="Inga Hablará-modeller installerade längre. Kör installationen igen för att installera en modell."
      MSG_CLEANUP_NO_MODELS="Inga Hablará-modeller hittade."
      # Misc
      MSG_INTERNAL_ERROR="Internt fel: MODEL_NAME är inte satt"
      MSG_TEST_MODEL="Testar modell..."
      MSG_TEST_OK="Modelltest lyckades"
      MSG_TEST_FAIL="Modelltest misslyckades"
      MSG_WAIT_SERVER="Väntar på Ollama-server..."
      MSG_SERVER_READY="Ollama-server är redo"
      MSG_SERVER_NO_RESPONSE="Ollama-server svarar inte efter %ss"
      MSG_SETUP_FAILED="Installationen misslyckades"
      MSG_OLLAMA_LIST_TIMEOUT="ollama list timeout (15s) vid modellkontroll"
      # Linux-specific service management
      MSG_SYSTEMD_START="Startar Ollama-tjänst..."
      MSG_SYSTEMD_ENABLE="Aktiverar Ollama-tjänst..."
      MSG_SYSTEMD_START_FAIL="Kunde inte starta Ollama-tjänst"
      MSG_SERVICE_MANUAL="Starta manuellt: ollama serve"
      MSG_LINUX_CURL_INSTALL="Installerar curl först..."
      MSG_LINUX_INSTALL_HINT="Installera curl: sudo apt-get install -y curl"
      # Server management (start_ollama_server + show_summary)
      MSG_SERVER_ALREADY="Ollama-server körs redan"
      MSG_PORT_CHECK_HINT_SS="Kontrollera: ss -tlnp | grep 11434"
      MSG_SYSTEMD_SYSTEM_ACTIVE="Ollama systemtjänst aktiv, väntar på API..."
      MSG_SYSTEMD_SYSTEM_START="Startar Ollama via systemd (systemtjänst)..."
      MSG_SYSTEMD_STARTED="Ollama-server startad (systemd)"
      MSG_SYSTEMD_USER_START="Startar Ollama via systemd (användartjänst)..."
      MSG_NOHUP_START="Startar Ollama-server (nohup)..."
      MSG_SERVER_STARTED_PID="Ollama-server startad (PID: %s)"
      MSG_PROCESS_FAILED="Ollama-process misslyckades – Logg: %s"
      MSG_PROCESS_START_FAIL="Ollama-processen kunde inte startas"
      MSG_SERVICE_MANAGEMENT="Tjänstehantering:"
      MSG_GPU_AMD="AMD GPU detekterad (experimentell)"
      MSG_GPU_INTEL="Intel GPU detekterad (experimentell)"
      # Help
      MSG_HELP_DESCRIPTION="Installerar Ollama och konfigurerar en optimerad Hablará-modell."
      MSG_HELP_USAGE="Användning:"
      MSG_HELP_OPTS_LABEL="ALTERNATIV"
      MSG_HELP_OPTIONS="Alternativ:"
      MSG_HELP_OPT_MODEL="  -m, --model VARIANT   Välj modellvariant: 1.5b, 3b, 7b, qwen3-8b (standard: 3b)"
      MSG_HELP_OPT_UPDATE="  --update              Återskapa Hablará anpassad modell (uppdatera Modelfile)"
      MSG_HELP_OPT_STATUS="  --status              Hälsokontroll: 7-punkts Ollama-installationskontroll"
      MSG_HELP_OPT_DIAGNOSE="  --diagnose            Generera supportrapport (klartext, kopierbar)"
      MSG_HELP_OPT_CLEANUP="  --cleanup             Interaktivt ta bort installerad variant (kräver terminal)"
      MSG_HELP_OPT_LANG="  --lang KOD            Språk: da (danska), de (tyska), en (engelska), es (spanska), fr (franska), it (italienska), nl (holländska), pl (polska), pt (portugisiska), sv (svenska)"
      MSG_HELP_OPT_HELP="  -h, --help            Visa den här hjälpen"
      MSG_HELP_NO_OPTS="Utan alternativ startar en interaktiv meny."
      MSG_HELP_VARIANTS="Modellvarianter:"
      MSG_HELP_EXAMPLES="Exempel:"
      MSG_HELP_EX_MODEL="--model 3b                          Installera 3b-variant"
      MSG_HELP_EX_UPDATE="--update                            Uppdatera anpassad modell"
      MSG_HELP_EX_STATUS="--status                            Kontrollera installation"
      MSG_HELP_EX_DIAGNOSE="--diagnose                          Skapa felrapport"
      MSG_HELP_EX_CLEANUP="--cleanup                           Ta bort variant"
      MSG_HELP_EX_PIPE="  curl -fsSL URL | bash -s -- -m 3b      Via pipe med argument"
      MSG_HELP_EXIT_CODES="Utgångskoder:"
      MSG_HELP_EXIT_0="  0  Lyckades"
      MSG_HELP_EXIT_1="  1  Allmänt fel"
      MSG_HELP_EXIT_2="  2  Inte tillräckligt med diskutrymme"
      MSG_HELP_EXIT_3="  3  Ingen nätverksanslutning"
      MSG_HELP_EXIT_4="  4  Fel plattform"
      # Hardware Detection
      MSG_HW_DETECTION_HEADER="Maskinvarudetektering:"
      MSG_HW_BANDWIDTH="Minnesbandbredd: ~%s GB/s · %s GB RAM"
      MSG_HW_RECOMMENDATION="Modellrekommendation för din maskinvara:"
      MSG_HW_LOCAL_TOO_SLOW="Lokala modeller kommer vara långsamma på denna maskinvara"
      MSG_HW_CLOUD_HINT="Rekommendation: OpenAI eller Anthropic API för bästa upplevelse"
      MSG_HW_PROCEED_LOCAL="Installera lokalt ändå? [j/N]"
      MSG_HW_TAG_RECOMMENDED="rekommenderad"
      MSG_HW_TAG_SLOW="långsam"
      MSG_HW_TAG_TOO_SLOW="för långsam"
      MSG_CHOICE_PROMPT_HW="Val [1-4, Enter=%s]"
      MSG_HW_UNKNOWN_CHIP="Okänd processor — ingen bandbreddsrekommendation möjlig"
      MSG_HW_MULTI_CALL_HINT="Hablará kör flera analyssteg per inspelning"
      # Benchmark
      MSG_BENCH_RESULT="Benchmark: ~%s tok/s med %s"
      MSG_BENCH_EXCELLENT="Utmärkt — din maskinvara hanterar den här modellen utan problem"
      MSG_BENCH_GOOD="Bra — den här modellen körs bra på din maskinvara"
      MSG_BENCH_MARGINAL="Marginellt — en mindre modell ger en smidigare upplevelse"
      MSG_BENCH_TOO_SLOW="För långsamt — en mindre modell eller molnleverantör rekommenderas"
      MSG_BENCH_SKIP="Benchmark hoppades över (mätning misslyckades)"
      ;;
    da)
      MSG_ERROR_PREFIX="Fejl"
      # Model Menu
      MSG_CHOOSE_MODEL="Vælg en model:"
      MSG_CHOICE_PROMPT="Valg [1-4, Enter=1]"
      MSG_MODEL_3B="Bedste samlede ydelse [Standard]"
      MSG_MODEL_1_5B="Hurtig, begrænset præcision [Grundlæggende]"
      MSG_MODEL_7B="Kræver kraftfuld hardware"
      MSG_MODEL_QWEN3="Bedste argumentationsanalyse [Premium]"
      # Main Menu
      MSG_CHOOSE_ACTION="Vælg en handling:"
      MSG_ACTION_SETUP="Installer eller opdater Ollama"
      MSG_ACTION_STATUS="Kontrollér status"
      MSG_ACTION_DIAGNOSE="Diagnostik (supportrapport)"
      MSG_ACTION_CLEANUP="Rens modeller"
      MSG_ACTION_PROMPT="Valg [1-4, Enter=1]"
      # Select Model / Args
      MSG_OPT_NEEDS_ARG="Tilvalget %s kræver et argument"
      MSG_UNKNOWN_OPTION="Ukendt tilvalg: %s"
      MSG_INVALID_MODEL="Ugyldig modelvariant: %s"
      MSG_VALID_VARIANTS="Gyldige varianter: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b"
      MSG_RAM_WARN_MODEL="Denne model anbefaler mindst %sGB RAM"
      MSG_RAM_WARN_SYS="Dit system har %sGB RAM"
      MSG_CONTINUE_ANYWAY="Fortsæt alligevel?"
      MSG_CONFIRM_PROMPT="[j/N]"
      MSG_CONFIRM_YES='^[jJyY]$'
      MSG_ABORTED="Afbrudt."
      MSG_SELECTED_MODEL="Valgt model: %s"
      MSG_PROCEED_NONINTERACTIVE="Fortsætter..."
      # Preflight
      MSG_PREFLIGHT="Udfører forhåndskontrol..."
      MSG_PLATFORM_ERROR_MAC="Dette script er kun til macOS"
      MSG_PLATFORM_LINUX_HINT="Til Linux: scripts/setup-ollama-linux.sh"
      MSG_PLATFORM_ERROR_LINUX="Dette script er kun til Linux"
      MSG_PLATFORM_MAC_HINT="Til macOS: scripts/setup-ollama-mac.sh"
      MSG_TOOL_MISSING="%s mangler (installer det)"
      MSG_DISK_INSUFFICIENT="Ikke nok diskplads: %sGB tilgængelig, %sGB krævet"
      MSG_DISK_OK="Diskplads: %sGB tilgængelig"
      MSG_NETWORK_ERROR="Ingen netværksforbindelse til ollama.com"
      MSG_NETWORK_HINT="Kontrollér: curl -I https://ollama.com"
      MSG_NETWORK_OK="Netværksforbindelse OK"
      MSG_GPU_APPLE="Apple Silicon registreret (Metal-acceleration)"
      MSG_GPU_NVIDIA="NVIDIA GPU registreret (CUDA-acceleration)"
      MSG_GPU_NONE="Ingen GPU registreret – behandling uden GPU-acceleration"
      # Install Ollama
      MSG_INSTALLING_OLLAMA="Installerer Ollama..."
      MSG_OLLAMA_ALREADY="Ollama er allerede installeret"
      MSG_OLLAMA_VERSION="Version: %s"
      MSG_CHECKING_SERVER="Kontrollerer Ollama-server..."
      MSG_SERVER_START_FAILED="Kunne ikke starte Ollama-server"
      MSG_SERVER_START_HINT="Start manuelt: ollama serve"
      MSG_SERVER_RUNNING="Ollama-server kører"
      MSG_USING_BREW="Bruger Homebrew (timeout: 10 minutter)..."
      MSG_BREW_TIMEOUT="brew install timeout efter 10 minutter"
      MSG_BREW_ALT="Alternativ: https://ollama.com/download"
      MSG_BREW_FAILED="Homebrew-installation mislykkedes"
      MSG_OLLAMA_PATH_ERROR="Ollama installeret, men CLI er ikke i PATH"
      MSG_PATH_HINT="Genstart terminal eller kontrollér PATH"
      MSG_SERVER_START_WARN="Serverstart mislykkedes – start manuelt: ollama serve"
      MSG_DOWNLOADING_INSTALLER="Henter Ollama-installationsprogram..."
      MSG_INSTALLER_DOWNLOAD_FAILED="Download af installationsprogram mislykkedes"
      MSG_MANUAL_INSTALL="Manuel installation: https://ollama.com/download"
      MSG_RUNNING_INSTALLER="Kører installationsprogram (timeout: 5 minutter)..."
      MSG_INSTALLER_TIMEOUT="Installationsprogram timeout efter 5 minutter"
      MSG_INSTALL_FAILED="Ollama-installation mislykkedes"
      MSG_OLLAMA_INSTALLED="Ollama installeret"
      MSG_APT_HINT="Installer: sudo apt-get install -y curl"
      MSG_OLLAMA_FOUND="Ollama fundet: %s"
      MSG_OLLAMA_BREW_FOUND="Ollama via Homebrew fundet: %s"
      MSG_PORT_BUSY="Port 11434 er optaget, venter på Ollama API..."
      MSG_PORT_BUSY_WARN="Port 11434 optaget, men Ollama API svarer ikke"
      MSG_PORT_CHECK_HINT="Kontrollér: lsof -i :11434"
      MSG_VERSION_WARN="Ollama-version %s er ældre end anbefalet (%s)"
      MSG_UPDATE_HINT_BREW="Opdatér: brew upgrade ollama"
      MSG_UPDATE_HINT_APT="Opdatér: sudo apt-get install ollama"
      # Model Download
      MSG_DOWNLOADING_BASE="Henter basismodel..."
      MSG_MODEL_EXISTS="Model findes allerede: %s"
      MSG_DOWNLOADING_MODEL="Henter %s (%s, tager nogle minutter afhængigt af forbindelsen)..."
      MSG_DOWNLOAD_RESUME_TIP="Tip: Hvis afbrudt (Ctrl+C) genoptages download ved genstart"
      MSG_DOWNLOAD_HARD_TIMEOUT="Hård timeout efter %s minutter – afbryder"
      MSG_DOWNLOAD_STALL="Ingen downloadfremgang i %s minutter – afbryder"
      MSG_DOWNLOAD_RUNNING="  Download i gang... (%ss)"
      MSG_DOWNLOAD_TIMEOUT_WARN="Download-timeout efter %s minutter (forsøg %s/3)"
      MSG_DOWNLOAD_FAILED_WARN="Download mislykkedes (forsøg %s/3)"
      MSG_DOWNLOAD_RETRY="Næste forsøg om 5s..."
      MSG_DOWNLOAD_FAILED="Modeldownload mislykkedes efter 3 forsøg"
      MSG_DOWNLOAD_MANUAL="Prøv manuelt: ollama pull %s"
      MSG_DOWNLOAD_DONE="Model hentet: %s"
      # Custom Model
      MSG_CREATING_CUSTOM="Opretter Hablará-model..."
      MSG_UPDATING_CUSTOM="Opdaterer eksisterende Hablará-model..."
      MSG_CUSTOM_EXISTS="    • Hablará-model %s findes allerede."
      MSG_CUSTOM_SKIP="Spring over (ingen ændringer)"
      MSG_CUSTOM_UPDATE_OPT="Opdatér Hablará-model"
      MSG_CUSTOM_UPDATE_PROMPT="Valg [1-2, Enter=1]"
      MSG_CUSTOM_KEPT="Hablará-model beholdt"
      MSG_CUSTOM_PRESENT="Hablará-model findes allerede"
      MSG_USING_HABLARA_CONFIG="Bruger Hablará-konfiguration"
      MSG_USING_DEFAULT_CONFIG="Bruger standardkonfiguration"
      MSG_CUSTOM_CREATING="Opretter Hablará-model %s..."
      MSG_CUSTOM_CREATE_TIMEOUT="ollama create timeout efter 120s – bruger basismodel"
      MSG_CUSTOM_CREATE_FAILED="Hablará-model kunne ikke %s – bruger basismodel"
      MSG_CUSTOM_DONE="Hablará-model %s: %s"
      MSG_VERB_CREATED="oprettet"
      MSG_VERB_UPDATED="opdateret"
      # Verify
      MSG_VERIFYING="Verificerer installation..."
      MSG_OLLAMA_NOT_FOUND="Ollama ikke fundet"
      MSG_SERVER_UNREACHABLE="Ollama-server ikke tilgængelig"
      MSG_BASE_NOT_FOUND="Basismodel ikke fundet: %s"
      MSG_BASE_OK="Basismodel tilgængelig: %s"
      MSG_CUSTOM_OK="Hablará-model tilgængelig: %s"
      MSG_CUSTOM_UNAVAILABLE="Hablará-model ikke tilgængelig (bruger basismodel)"
      MSG_INFERENCE_FAILED="Modeltest mislykkedes, test i appen"
      MSG_SETUP_DONE="Installation fuldført!"
      # Main Summary
      MSG_SETUP_COMPLETE="Hablará Ollama-installation fuldført!"
      MSG_INSTALLED="Installeret:"
      MSG_BASE_MODEL_LABEL="  Basismodel:       "
      MSG_HABLARA_MODEL_LABEL="  Hablará-model:  "
      MSG_OLLAMA_CONFIG="Ollama-konfiguration:"
      MSG_MODEL_LABEL="  Model:     "
      MSG_BASE_URL_LABEL="  Basis-URL: "
      MSG_DOCS="Dokumentation: https://github.com/fidpa/hablara"
      # Status
      MSG_STATUS_TITLE_MAC="Hablará Ollama-status (macOS)"
      MSG_STATUS_TITLE_LINUX="Hablará Ollama-status (Linux)"
      MSG_STATUS_INSTALLED="Ollama installeret (v%s)"
      MSG_STATUS_UPDATE_REC_BREW="  ↳ Opdatering anbefales (minimum v%s): brew upgrade ollama"
      MSG_STATUS_UPDATE_REC_APT="  ↳ Opdatering anbefales (minimum v%s): sudo apt-get install ollama"
      MSG_STATUS_NOT_FOUND="Ollama ikke fundet"
      MSG_STATUS_SERVER_OK="Server kører"
      MSG_STATUS_SERVER_FAIL="Server ikke tilgængelig"
      MSG_STATUS_GPU_APPLE="GPU: Apple Silicon (Metal-acceleration)"
      MSG_STATUS_GPU_NVIDIA="GPU: NVIDIA (CUDA-acceleration)"
      MSG_STATUS_NO_GPU="Ingen GPU – behandling uden GPU-acceleration"
      MSG_STATUS_BASE_MODEL="Basismodel: %s"
      MSG_STATUS_BASE_MODELS="Basismodeller:"
      MSG_STATUS_NO_BASE="Ingen basismodel fundet"
      MSG_STATUS_HABLARA_MODEL="Hablará-model: %s"
      MSG_STATUS_HABLARA_MODELS="Hablará-modeller:"
      MSG_STATUS_NO_HABLARA="Ingen Hablará-model fundet"
      MSG_STATUS_BASE_MISSING="  ↳ Basismodel mangler – Hablará-model kræver den som grundlag"
      MSG_STATUS_INFERENCE_SKIP="Modeltest sprunget over (server ikke tilgængelig)"
      MSG_STATUS_MODEL_OK="Model svarer"
      MSG_STATUS_MODEL_FAIL="Model svarer ikke"
      MSG_STATUS_STORAGE="Lagringsforbrug (Hablará): ~%s GB"
      MSG_STATUS_STORAGE_UNKNOWN="Lagringsforbrug: kan ikke bestemmes"
      MSG_STATUS_ALL_OK="Alt er i orden."
      MSG_STATUS_PROBLEMS="%s problem(er) fundet."
      MSG_STATUS_REPAIR="    Reparer:"
      # Diagnose
      MSG_DIAGNOSE_TITLE="=== Hablará Ollama Diagnostikrapport ==="
      MSG_DIAGNOSE_OS="OS:"
      MSG_DIAGNOSE_RAM="RAM:"
      MSG_DIAGNOSE_RAM_AVAIL="tilgængelig"
      MSG_DIAGNOSE_STORAGE_FREE="fri"
      MSG_DIAGNOSE_SHELL="Shell:"
      MSG_DIAGNOSE_VERSION="Version:"
      MSG_DIAGNOSE_SERVER="Server:"
      MSG_DIAGNOSE_API="API-URL:"
      MSG_DIAGNOSE_GPU="GPU:"
      MSG_DIAGNOSE_STORAGE_LABEL="Lagring (Hablará):"
      MSG_DIAGNOSE_LOG_LABEL="Ollama-log (seneste fejl):"
      MSG_DIAGNOSE_DISTRIBUTION="Distribution:"
      MSG_DIAGNOSE_CREATED="Oprettet:"
      MSG_DIAGNOSE_SCRIPT="Script:"
      MSG_DIAGNOSE_SAVED="Rapport gemt: %s"
      MSG_DIAGNOSE_SAVE_FAILED="Rapporten kunne ikke gemmes"
      MSG_DIAGNOSE_UNKNOWN="ukendt"
      MSG_DIAGNOSE_NOT_INSTALLED="ikke installeret"
      MSG_DIAGNOSE_NOT_REACHABLE="ikke tilgængelig"
      MSG_DIAGNOSE_RUNNING="kører"
      MSG_DIAGNOSE_NO_MODELS="    [ingen Hablará-modeller fundet]"
      MSG_DIAGNOSE_NO_ERRORS="    [ingen fejl fundet]"
      MSG_DIAGNOSE_NO_LOG="    [logfil ikke fundet: %s]"
      MSG_DIAGNOSE_GPU_APPLE="Apple Silicon (Metal)"
      MSG_DIAGNOSE_GPU_NVIDIA="NVIDIA (CUDA)"
      MSG_DIAGNOSE_GPU_NONE="Ingen"
      MSG_DIAGNOSE_RESPONDS="(svarer)"
      MSG_DIAGNOSE_SECTION_SYSTEM="System"
      MSG_DIAGNOSE_SECTION_OLLAMA="Ollama"
      MSG_DIAGNOSE_SECTION_MODELS="Hablará-modeller"
      MSG_DIAGNOSE_STORAGE_DISK="Lagring"
      MSG_DIAGNOSE_GPU_AMD="AMD (ROCm)"
      MSG_DIAGNOSE_GPU_INTEL="Intel (oneAPI)"
      MSG_GPU_STATUS_AMD="GPU: AMD (ROCm-acceleration, eksperimentel)"
      MSG_GPU_STATUS_INTEL="GPU: Intel (oneAPI-acceleration, eksperimentel)"
      MSG_HOMEBREW_INSTALLED="Ollama installeret via Homebrew"
      # Cleanup
      MSG_CLEANUP_NEEDS_TTY="--cleanup kræver en interaktiv session"
      MSG_CLEANUP_NO_OLLAMA="Ollama ikke fundet"
      MSG_CLEANUP_NO_SERVER="Ollama-server ikke tilgængelig"
      MSG_CLEANUP_START_HINT="Start Ollama og prøv igen"
      MSG_CLEANUP_INSTALLED="Installerede Hablará-varianter:"
      MSG_CLEANUP_PROMPT="Hvilken variant skal fjernes? (nummer, Enter=annullér, timeout 60s): "
      MSG_CLEANUP_ENTER_CANCEL="Enter=annullér"
      MSG_CLEANUP_INVALID="Ugyldigt valg"
      MSG_CLEANUP_DELETED="%s fjernet"
      MSG_CLEANUP_FAILED="%s kunne ikke fjernes: %s"
      MSG_CLEANUP_UNKNOWN_ERR="ukendt fejl"
      MSG_CLEANUP_NONE_LEFT="Ingen Hablará-modeller installeret længere. Kør installationen igen for at installere en model."
      MSG_CLEANUP_NO_MODELS="Ingen Hablará-modeller fundet."
      # Misc
      MSG_INTERNAL_ERROR="Intern fejl: MODEL_NAME er ikke sat"
      MSG_TEST_MODEL="Tester model..."
      MSG_TEST_OK="Modeltest lykkedes"
      MSG_TEST_FAIL="Modeltest mislykkedes"
      MSG_WAIT_SERVER="Venter på Ollama-server..."
      MSG_SERVER_READY="Ollama-server er klar"
      MSG_SERVER_NO_RESPONSE="Ollama-server svarer ikke efter %ss"
      MSG_SETUP_FAILED="Installation mislykkedes"
      MSG_OLLAMA_LIST_TIMEOUT="ollama list timeout (15s) ved modelkontrol"
      # Linux-specific service management
      MSG_SYSTEMD_START="Starter Ollama-tjeneste..."
      MSG_SYSTEMD_ENABLE="Aktiverer Ollama-tjeneste..."
      MSG_SYSTEMD_START_FAIL="Kunne ikke starte Ollama-tjeneste"
      MSG_SERVICE_MANUAL="Start manuelt: ollama serve"
      MSG_LINUX_CURL_INSTALL="Installerer curl først..."
      MSG_LINUX_INSTALL_HINT="Installer curl: sudo apt-get install -y curl"
      # Server management (start_ollama_server + show_summary)
      MSG_SERVER_ALREADY="Ollama-server kører allerede"
      MSG_PORT_CHECK_HINT_SS="Kontrollér: ss -tlnp | grep 11434"
      MSG_SYSTEMD_SYSTEM_ACTIVE="Ollama systemtjeneste aktiv, venter på API..."
      MSG_SYSTEMD_SYSTEM_START="Starter Ollama via systemd (systemtjeneste)..."
      MSG_SYSTEMD_STARTED="Ollama-server startet (systemd)"
      MSG_SYSTEMD_USER_START="Starter Ollama via systemd (brugertjeneste)..."
      MSG_NOHUP_START="Starter Ollama-server (nohup)..."
      MSG_SERVER_STARTED_PID="Ollama-server startet (PID: %s)"
      MSG_PROCESS_FAILED="Ollama-proces mislykkedes – Log: %s"
      MSG_PROCESS_START_FAIL="Ollama-processen kunne ikke startes"
      MSG_SERVICE_MANAGEMENT="Tjenestestyring:"
      MSG_GPU_AMD="AMD GPU registreret (eksperimentel)"
      MSG_GPU_INTEL="Intel GPU registreret (eksperimentel)"
      # Help
      MSG_HELP_DESCRIPTION="Installerer Ollama og konfigurerer en optimeret Hablará-model."
      MSG_HELP_USAGE="Brug:"
      MSG_HELP_OPTS_LABEL="TILVALG"
      MSG_HELP_OPTIONS="Tilvalg:"
      MSG_HELP_OPT_MODEL="  -m, --model VARIANT   Vælg modelvariant: 1.5b, 3b, 7b, qwen3-8b (standard: 3b)"
      MSG_HELP_OPT_UPDATE="  --update              Gengenerér Hablará tilpasset model (opdatér Modelfile)"
      MSG_HELP_OPT_STATUS="  --status              Sundhedstjek: 7-punkts Ollama-installationskontrol"
      MSG_HELP_OPT_DIAGNOSE="  --diagnose            Generér supportrapport (klartekst, kopierbar)"
      MSG_HELP_OPT_CLEANUP="  --cleanup             Fjern installeret variant interaktivt (kræver terminal)"
      MSG_HELP_OPT_LANG="  --lang KODE           Sprog: da (dansk), de (tysk), en (engelsk), es (spansk), fr (fransk), it (italiensk), nl (nederlandsk), pl (polsk), pt (portugisisk), sv (svensk)"
      MSG_HELP_OPT_HELP="  -h, --help            Vis denne hjælp"
      MSG_HELP_NO_OPTS="Uden tilvalg startes en interaktiv menu."
      MSG_HELP_VARIANTS="Modelvarianter:"
      MSG_HELP_EXAMPLES="Eksempler:"
      MSG_HELP_EX_MODEL="--model 3b                          Installer 3b-variant"
      MSG_HELP_EX_UPDATE="--update                            Opdatér tilpasset model"
      MSG_HELP_EX_STATUS="--status                            Kontrollér installation"
      MSG_HELP_EX_DIAGNOSE="--diagnose                          Opret fejlrapport"
      MSG_HELP_EX_CLEANUP="--cleanup                           Fjern variant"
      MSG_HELP_EX_PIPE="  curl -fsSL URL | bash -s -- -m 3b      Via pipe med argument"
      MSG_HELP_EXIT_CODES="Afslutningskoder:"
      MSG_HELP_EXIT_0="  0  Lykkedes"
      MSG_HELP_EXIT_1="  1  Generel fejl"
      MSG_HELP_EXIT_2="  2  Ikke nok diskplads"
      MSG_HELP_EXIT_3="  3  Ingen netværksforbindelse"
      MSG_HELP_EXIT_4="  4  Forkert platform"
      # Hardware Detection
      MSG_HW_DETECTION_HEADER="Hardware-detektion:"
      MSG_HW_BANDWIDTH="Hukommelsesbåndbredde: ~%s GB/s · %s GB RAM"
      MSG_HW_RECOMMENDATION="Modelanbefaling til din hardware:"
      MSG_HW_LOCAL_TOO_SLOW="Lokale modeller vil være langsomme på denne hardware"
      MSG_HW_CLOUD_HINT="Anbefaling: OpenAI eller Anthropic API for den bedste oplevelse"
      MSG_HW_PROCEED_LOCAL="Installér lokalt alligevel? [j/N]"
      MSG_HW_TAG_RECOMMENDED="anbefalet"
      MSG_HW_TAG_SLOW="langsom"
      MSG_HW_TAG_TOO_SLOW="for langsom"
      MSG_CHOICE_PROMPT_HW="Valg [1-4, Enter=%s]"
      MSG_HW_UNKNOWN_CHIP="Ukendt processor — ingen båndbreddeanbefaling mulig"
      MSG_HW_MULTI_CALL_HINT="Hablará udfører flere analysetrin per optagelse"
      # Benchmark
      MSG_BENCH_RESULT="Benchmark: ~%s tok/s med %s"
      MSG_BENCH_EXCELLENT="Fremragende — din hardware håndterer denne model med lethed"
      MSG_BENCH_GOOD="Godt — denne model kører godt på din hardware"
      MSG_BENCH_MARGINAL="Grænsetilfælde — en mindre model giver en mere flydende oplevelse"
      MSG_BENCH_TOO_SLOW="For langsomt — en mindre model eller cloud-udbyder anbefales"
      MSG_BENCH_SKIP="Benchmark sprunget over (måling mislykkedes)"
      ;;
    de|*)
      MSG_ERROR_PREFIX="Fehler"
      # Model Menu
      MSG_CHOOSE_MODEL="Wähle ein Modell:"
      MSG_CHOICE_PROMPT="Auswahl [1-4, Enter=1]"
      MSG_MODEL_3B="Optimale Gesamtleistung [Standard]"
      MSG_MODEL_1_5B="Schnell, eingeschränkte Genauigkeit [Einstieg]"
      MSG_MODEL_7B="Erfordert sehr leistungsfähige Hardware"
      MSG_MODEL_QWEN3="Beste Argumentationsanalyse [Premium]"
      # Main Menu
      MSG_CHOOSE_ACTION="Wähle eine Aktion:"
      MSG_ACTION_SETUP="Ollama einrichten oder aktualisieren"
      MSG_ACTION_STATUS="Status prüfen"
      MSG_ACTION_DIAGNOSE="Diagnose (Support-Report)"
      MSG_ACTION_CLEANUP="Modelle aufräumen"
      MSG_ACTION_PROMPT="Auswahl [1-4, Enter=1]"
      # Select Model / Args
      MSG_OPT_NEEDS_ARG="Option %s benötigt ein Argument"
      MSG_UNKNOWN_OPTION="Unbekannte Option: %s"
      MSG_INVALID_MODEL="Ungültige Modell-Variante: %s"
      MSG_VALID_VARIANTS="Gültige Varianten: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b"
      MSG_RAM_WARN_MODEL="Dieses Modell empfiehlt mindestens %sGB RAM"
      MSG_RAM_WARN_SYS="Dein System hat %sGB RAM"
      MSG_CONTINUE_ANYWAY="Trotzdem fortfahren?"
      MSG_CONFIRM_PROMPT="[j/N]"
      MSG_CONFIRM_YES='^[jJyY]$'
      MSG_ABORTED="Abgebrochen."
      MSG_SELECTED_MODEL="Ausgewähltes Modell: %s"
      MSG_PROCEED_NONINTERACTIVE="Fahre fort..."
      # Preflight
      MSG_PREFLIGHT="Führe Vorab-Prüfungen durch..."
      MSG_PLATFORM_ERROR_MAC="Dieses Script ist nur für macOS"
      MSG_PLATFORM_LINUX_HINT="Für Linux: scripts/setup-ollama-linux.sh"
      MSG_PLATFORM_ERROR_LINUX="Dieses Script ist nur für Linux"
      MSG_PLATFORM_MAC_HINT="Für macOS: scripts/setup-ollama-mac.sh"
      MSG_TOOL_MISSING="%s fehlt (bitte installieren)"
      MSG_DISK_INSUFFICIENT="Nicht genügend Speicher: %sGB verfügbar, %sGB benötigt"
      MSG_DISK_OK="Speicherplatz: %sGB verfügbar"
      MSG_NETWORK_ERROR="Keine Netzwerkverbindung zu ollama.com"
      MSG_NETWORK_HINT="Prüfe: curl -I https://ollama.com"
      MSG_NETWORK_OK="Netzwerkverbindung OK"
      MSG_GPU_APPLE="Apple Silicon erkannt (Metal-Beschleunigung)"
      MSG_GPU_NVIDIA="NVIDIA GPU erkannt (CUDA-Beschleunigung)"
      MSG_GPU_NONE="Keine GPU erkannt - Verarbeitung ohne GPU-Beschleunigung"
      # Install Ollama
      MSG_INSTALLING_OLLAMA="Installiere Ollama..."
      MSG_OLLAMA_ALREADY="Ollama bereits installiert"
      MSG_OLLAMA_VERSION="Version: %s"
      MSG_CHECKING_SERVER="Prüfe Ollama Server..."
      MSG_SERVER_START_FAILED="Konnte Ollama Server nicht starten"
      MSG_SERVER_START_HINT="Manuell starten: ollama serve"
      MSG_SERVER_RUNNING="Ollama Server läuft"
      MSG_USING_BREW="Verwende Homebrew (Timeout: 10 Minuten)..."
      MSG_BREW_TIMEOUT="brew install Timeout nach 10 Minuten"
      MSG_BREW_ALT="Alternative: https://ollama.com/download"
      MSG_BREW_FAILED="Homebrew Installation fehlgeschlagen"
      MSG_OLLAMA_PATH_ERROR="Ollama installiert, aber CLI nicht im PATH"
      MSG_PATH_HINT="Terminal neu starten oder PATH prüfen"
      MSG_SERVER_START_WARN="Server-Start fehlgeschlagen - manuell starten: ollama serve"
      MSG_DOWNLOADING_INSTALLER="Lade Ollama-Installer herunter..."
      MSG_INSTALLER_DOWNLOAD_FAILED="Download des Installers fehlgeschlagen"
      MSG_MANUAL_INSTALL="Manuelle Installation: https://ollama.com/download"
      MSG_RUNNING_INSTALLER="Führe Installer aus (Timeout: 5 Minuten)..."
      MSG_INSTALLER_TIMEOUT="Installer-Timeout nach 5 Minuten"
      MSG_INSTALL_FAILED="Ollama Installation fehlgeschlagen"
      MSG_OLLAMA_INSTALLED="Ollama installiert"
      MSG_APT_HINT="Installieren: sudo apt-get install -y curl"
      MSG_OLLAMA_FOUND="Ollama gefunden: %s"
      MSG_OLLAMA_BREW_FOUND="Ollama via Homebrew gefunden: %s"
      MSG_PORT_BUSY="Port 11434 ist belegt, warte auf Ollama API..."
      MSG_PORT_BUSY_WARN="Port 11434 belegt, aber Ollama API antwortet nicht"
      MSG_PORT_CHECK_HINT="Prüfe: lsof -i :11434"
      MSG_VERSION_WARN="Ollama Version %s ist älter als empfohlen (%s)"
      MSG_UPDATE_HINT_BREW="Update: brew upgrade ollama"
      MSG_UPDATE_HINT_APT="Update: sudo apt-get install ollama"
      # Model Download
      MSG_DOWNLOADING_BASE="Lade Basis-Modell herunter..."
      MSG_MODEL_EXISTS="Modell bereits vorhanden: %s"
      MSG_DOWNLOADING_MODEL="Lade %s (%s, dauert mehrere Minuten je nach Verbindung)..."
      MSG_DOWNLOAD_RESUME_TIP="Tipp: Bei Abbruch (Ctrl+C) setzt ein erneuter Start den Download fort"
      MSG_DOWNLOAD_HARD_TIMEOUT="Hard-Timeout nach %s Minuten — Abbruch"
      MSG_DOWNLOAD_STALL="Kein Download-Fortschritt seit %s Minuten — Abbruch"
      MSG_DOWNLOAD_RUNNING="  Download läuft... (%ss)"
      MSG_DOWNLOAD_TIMEOUT_WARN="Download-Timeout nach %s Minuten (Versuch %s/3)"
      MSG_DOWNLOAD_FAILED_WARN="Download fehlgeschlagen (Versuch %s/3)"
      MSG_DOWNLOAD_RETRY="Nächster Versuch in 5s..."
      MSG_DOWNLOAD_FAILED="Modell-Download fehlgeschlagen nach 3 Versuchen"
      MSG_DOWNLOAD_MANUAL="Manuell versuchen: ollama pull %s"
      MSG_DOWNLOAD_DONE="Modell heruntergeladen: %s"
      # Custom Model
      MSG_CREATING_CUSTOM="Erstelle Hablará-Modell..."
      MSG_UPDATING_CUSTOM="Aktualisiere bestehendes Hablará-Modell..."
      MSG_CUSTOM_EXISTS="    • Hablará-Modell %s bereits vorhanden."
      MSG_CUSTOM_SKIP="Überspringen (keine Änderung)"
      MSG_CUSTOM_UPDATE_OPT="Hablará-Modell aktualisieren"
      MSG_CUSTOM_UPDATE_PROMPT="Auswahl [1-2, Enter=1]"
      MSG_CUSTOM_KEPT="Hablará-Modell beibehalten"
      MSG_CUSTOM_PRESENT="Hablará-Modell bereits vorhanden"
      MSG_USING_HABLARA_CONFIG="Verwende Hablará-Konfiguration"
      MSG_USING_DEFAULT_CONFIG="Verwende Standard-Konfiguration"
      MSG_CUSTOM_CREATING="Erstelle Hablará-Modell %s..."
      MSG_CUSTOM_CREATE_TIMEOUT="ollama create Timeout nach 120s — verwende Basis-Modell"
      MSG_CUSTOM_CREATE_FAILED="Hablará-Modell konnte nicht %s werden - verwende Basis-Modell"
      MSG_CUSTOM_DONE="Hablará-Modell %s: %s"
      MSG_VERB_CREATED="erstellt"
      MSG_VERB_UPDATED="aktualisiert"
      # Verify
      MSG_VERIFYING="Überprüfe Installation..."
      MSG_OLLAMA_NOT_FOUND="Ollama nicht gefunden"
      MSG_SERVER_UNREACHABLE="Ollama Server nicht erreichbar"
      MSG_BASE_NOT_FOUND="Basis-Modell nicht gefunden: %s"
      MSG_BASE_OK="Basis-Modell verfügbar: %s"
      MSG_CUSTOM_OK="Hablará-Modell verfügbar: %s"
      MSG_CUSTOM_UNAVAILABLE="Hablará-Modell nicht verfügbar (verwende Basis-Modell)"
      MSG_INFERENCE_FAILED="Modell-Test fehlgeschlagen, teste in der App"
      MSG_SETUP_DONE="Setup abgeschlossen!"
      # Main Summary
      MSG_SETUP_COMPLETE="Hablará Ollama Setup abgeschlossen!"
      MSG_INSTALLED="Installiert:"
      MSG_BASE_MODEL_LABEL="  Basis-Modell:   "
      MSG_HABLARA_MODEL_LABEL="  Hablará-Modell: "
      MSG_OLLAMA_CONFIG="Ollama-Konfiguration:"
      MSG_MODEL_LABEL="  Modell:   "
      MSG_BASE_URL_LABEL="  Base URL: "
      MSG_DOCS="Dokumentation: https://github.com/fidpa/hablara"
      # Status
      MSG_STATUS_TITLE_MAC="Hablará Ollama Status (macOS)"
      MSG_STATUS_TITLE_LINUX="Hablará Ollama Status (Linux)"
      MSG_STATUS_INSTALLED="Ollama installiert (v%s)"
      MSG_STATUS_UPDATE_REC_BREW="  ↳ Update empfohlen (mindestens v%s): brew upgrade ollama"
      MSG_STATUS_UPDATE_REC_APT="  ↳ Update empfohlen (mindestens v%s): sudo apt-get install ollama"
      MSG_STATUS_NOT_FOUND="Ollama nicht gefunden"
      MSG_STATUS_SERVER_OK="Server läuft"
      MSG_STATUS_SERVER_FAIL="Server nicht erreichbar"
      MSG_STATUS_GPU_APPLE="GPU: Apple Silicon (Metal-Beschleunigung)"
      MSG_STATUS_GPU_NVIDIA="GPU: NVIDIA (CUDA-Beschleunigung)"
      MSG_STATUS_NO_GPU="Keine GPU — Verarbeitung ohne GPU-Beschleunigung"
      MSG_STATUS_BASE_MODEL="Basis-Modell: %s"
      MSG_STATUS_BASE_MODELS="Basis-Modelle:"
      MSG_STATUS_NO_BASE="Kein Basis-Modell gefunden"
      MSG_STATUS_HABLARA_MODEL="Hablará-Modell: %s"
      MSG_STATUS_HABLARA_MODELS="Hablará-Modelle:"
      MSG_STATUS_NO_HABLARA="Kein Hablará-Modell gefunden"
      MSG_STATUS_BASE_MISSING="  ↳ Basis-Modell fehlt — Hablará-Modell benötigt es als Grundlage"
      MSG_STATUS_INFERENCE_SKIP="Modell-Test übersprungen (Server nicht erreichbar)"
      MSG_STATUS_MODEL_OK="Modell antwortet"
      MSG_STATUS_MODEL_FAIL="Modell antwortet nicht"
      MSG_STATUS_STORAGE="Speicherverbrauch (Hablará): ~%s GB"
      MSG_STATUS_STORAGE_UNKNOWN="Speicherverbrauch: nicht ermittelbar"
      MSG_STATUS_ALL_OK="Alles in Ordnung."
      MSG_STATUS_PROBLEMS="%s Problem(e) gefunden."
      MSG_STATUS_REPAIR="    Reparieren:"
      # Diagnose
      MSG_DIAGNOSE_TITLE="=== Hablará Ollama Diagnose-Report ==="
      MSG_DIAGNOSE_OS="OS:"
      MSG_DIAGNOSE_RAM="RAM:"
      MSG_DIAGNOSE_RAM_AVAIL="verfügbar"
      MSG_DIAGNOSE_STORAGE_FREE="frei"
      MSG_DIAGNOSE_SHELL="Shell:"
      MSG_DIAGNOSE_VERSION="Version:"
      MSG_DIAGNOSE_SERVER="Server:"
      MSG_DIAGNOSE_API="API-URL:"
      MSG_DIAGNOSE_GPU="GPU:"
      MSG_DIAGNOSE_STORAGE_LABEL="Speicher (Hablará):"
      MSG_DIAGNOSE_LOG_LABEL="Ollama-Log (letzte Fehler):"
      MSG_DIAGNOSE_DISTRIBUTION="Distribution:"
      MSG_DIAGNOSE_CREATED="Erstellt:"
      MSG_DIAGNOSE_SCRIPT="Script:"
      MSG_DIAGNOSE_SAVED="Report gespeichert: %s"
      MSG_DIAGNOSE_SAVE_FAILED="Report konnte nicht gespeichert werden"
      MSG_DIAGNOSE_UNKNOWN="unbekannt"
      MSG_DIAGNOSE_NOT_INSTALLED="nicht installiert"
      MSG_DIAGNOSE_NOT_REACHABLE="nicht erreichbar"
      MSG_DIAGNOSE_RUNNING="läuft"
      MSG_DIAGNOSE_NO_MODELS="    [keine Hablará-Modelle gefunden]"
      MSG_DIAGNOSE_NO_ERRORS="    [keine Fehler gefunden]"
      MSG_DIAGNOSE_NO_LOG="    [Log-Datei nicht gefunden: %s]"
      MSG_DIAGNOSE_GPU_APPLE="Apple Silicon (Metal)"
      MSG_DIAGNOSE_GPU_NVIDIA="NVIDIA (CUDA)"
      MSG_DIAGNOSE_GPU_NONE="Keine"
      MSG_DIAGNOSE_RESPONDS="(antwortet)"
      MSG_DIAGNOSE_SECTION_SYSTEM="System"
      MSG_DIAGNOSE_SECTION_OLLAMA="Ollama"
      MSG_DIAGNOSE_SECTION_MODELS="Hablará-Modelle"
      MSG_DIAGNOSE_STORAGE_DISK="Speicher"
      MSG_DIAGNOSE_GPU_AMD="AMD (ROCm)"
      MSG_DIAGNOSE_GPU_INTEL="Intel (oneAPI)"
      MSG_GPU_STATUS_AMD="GPU: AMD (ROCm-Beschleunigung, experimentell)"
      MSG_GPU_STATUS_INTEL="GPU: Intel (oneAPI-Beschleunigung, experimentell)"
      MSG_HOMEBREW_INSTALLED="Ollama via Homebrew installiert"
      # Cleanup
      MSG_CLEANUP_NEEDS_TTY="--cleanup erfordert eine interaktive Sitzung"
      MSG_CLEANUP_NO_OLLAMA="Ollama nicht gefunden"
      MSG_CLEANUP_NO_SERVER="Ollama Server nicht erreichbar"
      MSG_CLEANUP_START_HINT="Starte Ollama und versuche es erneut"
      MSG_CLEANUP_INSTALLED="Installierte Hablará-Varianten:"
      MSG_CLEANUP_PROMPT="Welche Variante löschen? (Nummer, Enter=abbrechen, Timeout 60s): "
      MSG_CLEANUP_ENTER_CANCEL="Enter=abbrechen"
      MSG_CLEANUP_INVALID="Ungültige Auswahl"
      MSG_CLEANUP_DELETED="%s gelöscht"
      MSG_CLEANUP_FAILED="%s konnte nicht gelöscht werden: %s"
      MSG_CLEANUP_UNKNOWN_ERR="unbekannter Fehler"
      MSG_CLEANUP_NONE_LEFT="Keine Hablará-Modelle mehr installiert. Führe das Setup erneut aus, um ein Modell zu installieren."
      MSG_CLEANUP_NO_MODELS="Keine Hablará-Modelle gefunden."
      # Misc
      MSG_INTERNAL_ERROR="Interner Fehler: MODEL_NAME nicht gesetzt"
      MSG_TEST_MODEL="Teste Modell..."
      MSG_TEST_OK="Modell-Test erfolgreich"
      MSG_TEST_FAIL="Modell-Test fehlgeschlagen"
      MSG_WAIT_SERVER="Warte auf Ollama Server..."
      MSG_SERVER_READY="Ollama Server ist bereit"
      MSG_SERVER_NO_RESPONSE="Ollama Server antwortet nicht nach %ss"
      MSG_SETUP_FAILED="Setup fehlgeschlagen"
      MSG_OLLAMA_LIST_TIMEOUT="ollama list Timeout (15s) bei Modell-Prüfung"
      # Linux-specific service management
      MSG_SYSTEMD_START="Starte Ollama-Dienst..."
      MSG_SYSTEMD_ENABLE="Aktiviere Ollama-Dienst..."
      MSG_SYSTEMD_START_FAIL="Konnte Ollama-Dienst nicht starten"
      MSG_SERVICE_MANUAL="Manuell starten: ollama serve"
      MSG_LINUX_CURL_INSTALL="Installiere curl..."
      MSG_LINUX_INSTALL_HINT="curl installieren: sudo apt-get install -y curl"
      # Server-Verwaltung (start_ollama_server + show_summary)
      MSG_SERVER_ALREADY="Ollama Server läuft bereits"
      MSG_PORT_CHECK_HINT_SS="Prüfe: ss -tlnp | grep 11434"
      MSG_SYSTEMD_SYSTEM_ACTIVE="Ollama System-Service aktiv, warte auf API..."
      MSG_SYSTEMD_SYSTEM_START="Starte Ollama via systemd (System-Service)..."
      MSG_SYSTEMD_STARTED="Ollama Server gestartet (systemd)"
      MSG_SYSTEMD_USER_START="Starte Ollama via systemd (User-Service)..."
      MSG_NOHUP_START="Starte Ollama Server (nohup)..."
      MSG_SERVER_STARTED_PID="Ollama Server gestartet (PID: %s)"
      MSG_PROCESS_FAILED="Ollama Prozess fehlgeschlagen - Log: %s"
      MSG_PROCESS_START_FAIL="Ollama Prozess konnte nicht gestartet werden"
      MSG_SERVICE_MANAGEMENT="Service-Verwaltung:"
      MSG_GPU_AMD="AMD GPU erkannt (experimentell)"
      MSG_GPU_INTEL="Intel GPU erkannt (experimentell)"
      # Help
      MSG_HELP_DESCRIPTION="Installiert Ollama und richtet ein optimiertes Hablará-Modell ein."
      MSG_HELP_USAGE="Verwendung:"
      MSG_HELP_OPTS_LABEL="OPTIONEN"
      MSG_HELP_OPTIONS="Optionen:"
      MSG_HELP_OPT_MODEL="  -m, --model VARIANTE  Modell-Variante wählen: 1.5b, 3b, 7b, qwen3-8b (Standard: 3b)"
      MSG_HELP_OPT_UPDATE="  --update              Hablará-Custom-Modell neu erstellen (Modelfile aktualisieren)"
      MSG_HELP_OPT_STATUS="  --status              Health-Check: 7-Punkte-Prüfung der Ollama-Installation"
      MSG_HELP_OPT_DIAGNOSE="  --diagnose            Support-Report generieren (Plain-Text, kopierfähig)"
      MSG_HELP_OPT_CLEANUP="  --cleanup             Installierte Variante interaktiv löschen (erfordert Terminal)"
      MSG_HELP_OPT_LANG="  --lang CODE           Sprache: da (Dänisch), de (Deutsch), en (Englisch), es (Spanisch), fr (Französisch), it (Italienisch), nl (Niederländisch), pl (Polnisch), pt (Portugiesisch), sv (Schwedisch)"
      MSG_HELP_OPT_HELP="  -h, --help            Diese Hilfe anzeigen"
      MSG_HELP_NO_OPTS="Ohne Optionen startet ein interaktives Menü."
      MSG_HELP_VARIANTS="Modell-Varianten:"
      MSG_HELP_EXAMPLES="Beispiele:"
      MSG_HELP_EX_MODEL="--model 3b                          3b-Variante installieren"
      MSG_HELP_EX_UPDATE="--update                            Custom-Modell aktualisieren"
      MSG_HELP_EX_STATUS="--status                            Installation prüfen"
      MSG_HELP_EX_DIAGNOSE="--diagnose                          Report für Bug-Ticket erstellen"
      MSG_HELP_EX_CLEANUP="--cleanup                           Variante entfernen"
      MSG_HELP_EX_PIPE="  curl -fsSL URL | bash -s -- -m 3b      Via Pipe mit Argument"
      MSG_HELP_EXIT_CODES="Exit Codes:"
      MSG_HELP_EXIT_0="  0  Erfolg"
      MSG_HELP_EXIT_1="  1  Allgemeiner Fehler"
      MSG_HELP_EXIT_2="  2  Nicht genügend Speicherplatz"
      MSG_HELP_EXIT_3="  3  Keine Netzwerkverbindung"
      MSG_HELP_EXIT_4="  4  Falsche Plattform"
      # Hardware Detection
      MSG_HW_DETECTION_HEADER="Hardware-Erkennung:"
      MSG_HW_BANDWIDTH="Speicherbandbreite: ~%s GB/s · %s GB RAM"
      MSG_HW_RECOMMENDATION="Modell-Empfehlung für deine Hardware:"
      MSG_HW_LOCAL_TOO_SLOW="Lokale Modelle werden auf dieser Hardware langsam sein"
      MSG_HW_CLOUD_HINT="Empfehlung: OpenAI oder Anthropic API für beste Erfahrung"
      MSG_HW_PROCEED_LOCAL="Trotzdem lokal installieren? [j/N]"
      MSG_HW_TAG_RECOMMENDED="empfohlen"
      MSG_HW_TAG_SLOW="langsam"
      MSG_HW_TAG_TOO_SLOW="zu langsam"
      MSG_CHOICE_PROMPT_HW="Auswahl [1-4, Enter=%s]"
      MSG_HW_UNKNOWN_CHIP="Unbekannter Prozessor — keine Bandbreiten-Empfehlung möglich"
      MSG_HW_MULTI_CALL_HINT="Hablará führt mehrere Analyse-Schritte pro Aufnahme aus"
      # Benchmark
      MSG_BENCH_RESULT="Benchmark: ~%s tok/s mit %s"
      MSG_BENCH_EXCELLENT="Exzellent — deine Hardware bewältigt dieses Modell mühelos"
      MSG_BENCH_GOOD="Gut — dieses Modell läuft gut auf deiner Hardware"
      MSG_BENCH_MARGINAL="Grenzwertig — ein kleineres Modell sorgt für flüssigere Bedienung"
      MSG_BENCH_TOO_SLOW="Zu langsam — ein kleineres Modell oder Cloud-Anbieter wird empfohlen"
      MSG_BENCH_SKIP="Benchmark übersprungen (Messung fehlgeschlagen)"
      ;;
  esac
}

# Check if an Ollama model is installed (pipefail-safe, 15s timeout)
ollama_model_exists() {
  local model="$1"
  local list_output
  list_output=$(run_with_timeout 15 ollama list 2>/dev/null) || {
    local rc=$?
    [[ $rc -eq 124 ]] && log_warning "${MSG_OLLAMA_LIST_TIMEOUT}" >&2
    return 1
  }
  local found=false
  while IFS= read -r line; do
    # Extract first whitespace-delimited field (model name)
    local name="${line%%[[:space:]]*}"
    if [[ "$name" == "$model" ]]; then
      found=true
      break
    fi
  done <<< "$list_output"
  $found
}

json_escape_string() {
  local str="$1"
  # Order matters: backslashes first
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  str="${str//$'\n'/\\n}"
  str="${str//$'\t'/\\t}"
  str="${str//$'\r'/\\r}"
  printf '%s' "$str"
}

# Returns Ollama data path (respects OLLAMA_MODELS > XDG_DATA_HOME > default)
get_ollama_data_path() {
  if [[ -n "${OLLAMA_MODELS:-}" && "${OLLAMA_MODELS}" == /* ]]; then
    echo "${OLLAMA_MODELS}"
  elif [[ -n "${XDG_DATA_HOME:-}" && "${XDG_DATA_HOME}" == /* ]]; then
    echo "${XDG_DATA_HOME}/ollama"
  else
    echo "${HOME}/.local/share/ollama"
  fi
}

get_free_space_gb() {
  local free_kb check_path
  check_path=$(get_ollama_data_path)

  mkdir -p "${check_path}" 2>/dev/null || check_path="${HOME}"

  if command_exists df; then
    # POSIX df -P: portable across GNU coreutils, busybox, Alpine (unlike df -BG)
    free_kb=$(df -P "${check_path}" 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)
    [[ "$free_kb" =~ ^[0-9]+$ ]] || free_kb=0
    echo $(( free_kb / 1024 / 1024 ))
  else
    echo "0"
  fi
}

version_gte() {
  local v1="${1:-0.0.0}" v2="${2:-0.0.0}"

  # Strip pre-release suffixes (e.g., "0.6.2-rc1" -> "0.6.2")
  v1="${v1%%-*}"
  v2="${v2%%-*}"

  if command_exists gsort; then
    # macOS with Homebrew coreutils
    [[ "$(printf '%s\n%s' "$v2" "$v1" | gsort -V | head -n1)" == "$v2" ]]
  elif sort --version 2>/dev/null | grep "GNU" > /dev/null; then
    [[ "$(printf '%s\n%s' "$v2" "$v1" | sort -V | head -n1)" == "$v2" ]]
  else
    local -a v1_parts v2_parts
    IFS='.' read -ra v1_parts <<< "$v1"
    IFS='.' read -ra v2_parts <<< "$v2"

    local max_len="${#v1_parts[@]}"
    [[ ${#v2_parts[@]} -gt $max_len ]] && max_len="${#v2_parts[@]}"

    for ((i=0; i<max_len; i++)); do
      local p1="${v1_parts[i]:-0}" p2="${v2_parts[i]:-0}"
      p1="${p1//[^0-9]/}"; p1="${p1:-0}"
      p2="${p2//[^0-9]/}"; p2="${p2:-0}"
      ((p1 > p2)) && return 0
      ((p1 < p2)) && return 1
    done
    return 0
  fi
}

# Returns version string (e.g. "0.6.2") or "unknown" (sentinel, not displayed) — no log output
get_ollama_version_string() {
  local version_output
  version_output=$(ollama --version 2>&1 | head -1)
  if [[ $version_output =~ ([0-9]+\.[0-9]+\.?[0-9]*) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "unknown"
  fi
}

check_ollama_version() {
  local current_version
  current_version=$(get_ollama_version_string)

  if [[ "$current_version" != "unknown" ]]; then
    if ! version_gte "$current_version" "$MIN_OLLAMA_VERSION"; then
      log_warning "$(msg "$MSG_VERSION_WARN" "$current_version" "$MIN_OLLAMA_VERSION")"
      log_info "${MSG_UPDATE_HINT_APT}"
      return 1
    fi
  fi
  return 0
}

check_gpu_available() {
  if command_exists nvidia-smi && nvidia-smi &>/dev/null; then
    local gpu_name
    gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    echo "nvidia:${gpu_name:-unknown}"; return 0
  fi

  if command_exists rocm-smi && rocm-smi &>/dev/null; then
    echo "amd_rocm"; return 0
  fi

  if [[ -d /opt/intel/oneapi ]] && command_exists sycl-ls; then
    if sycl-ls 2>/dev/null | grep -i "gpu" > /dev/null; then
      echo "intel_oneapi"; return 0
    fi
  fi

  echo "cpu"; return 1
}

# GPU bandwidth lookup table (dedicated GPU VRAM bandwidth in GB/s)
# SHARED: Must be identical in mac + linux templates
_gpu_bandwidth_lookup() {
  local gpu_name="$1"
  case "$gpu_name" in
    *"4090"*)           echo "1008" ;;
    *"4080"*)           echo "717" ;;
    *"4070 Ti"*)        echo "672" ;;
    *"4070"*)           echo "504" ;;
    *"3090"*)           echo "936" ;;
    *"3080"*)           echo "760" ;;
    *"3070"*)           echo "448" ;;
    *"3060 Ti"*)        echo "448" ;;
    *"3060"*)           echo "360" ;;
    *"2080"*)           echo "448" ;;
    *"2070"*)           echo "448" ;;
    *"7900 XTX"*)       echo "960" ;;
    *"7900 XT"*)        echo "800" ;;
    *"6800 XT"*)        echo "512" ;;
    *)                  echo "0" ;;
  esac
}

# Detect memory bandwidth in GB/s (Linux: GPU lookup or RAM speed estimation)
# PLATFORM-SPECIFIC: Linux uses nvidia-smi GPU name or dmidecode RAM speed
detect_memory_bandwidth_gbps() {
  # Try GPU bandwidth first
  local gpu_info
  gpu_info=$(check_gpu_available 2>/dev/null) || gpu_info="cpu"

  if [[ "$gpu_info" == nvidia:* ]]; then
    local gpu_name="${gpu_info#nvidia:}"
    local gpu_bw
    gpu_bw=$(_gpu_bandwidth_lookup "$gpu_name")
    if [[ "$gpu_bw" -gt 0 ]]; then
      echo "$gpu_bw"
      return 0
    fi
  fi

  # Fallback: RAM speed via dmidecode (requires root)
  local ram_speed
  ram_speed=$(sudo dmidecode -t memory 2>/dev/null | grep -i "speed:" | grep -v "Unknown" | head -1 | grep -oE '[0-9]+' | head -1 || true)

  if [[ -n "$ram_speed" && "$ram_speed" =~ ^[0-9]+$ && "$ram_speed" -gt 0 ]]; then
    # Conservative dual-channel estimate: speed_mhz * 16 bytes (dual-channel 64-bit) / 1000
    echo $(( ram_speed * 16 / 1000 ))
    return 0
  fi

  echo "0"
}

# Recommend model size based on memory bandwidth
# SHARED: Must be identical in mac + linux templates
recommend_model_for_bandwidth() {
  local bw="$1"
  if [[ "$bw" -ge 500 ]]; then
    echo "qwen3-8b"
  elif [[ "$bw" -ge 300 ]]; then
    echo "7b"
  elif [[ "$bw" -ge 150 ]]; then
    echo "3b"
  elif [[ "$bw" -ge 50 ]]; then
    echo "1.5b"
  else
    echo "none"
  fi
}

# Estimate tokens per second: bw * factor / size_gb_x10
# Sizes from ollama list; factors calibrated from M4 Pro benchmarks
# SHARED: Must be identical in mac + linux templates
estimate_toks_per_sec() {
  local bw="$1"
  local model="$2"
  local size_gb_x10 factor
  case "$model" in
    1.5b)       size_gb_x10=10; factor=6 ;;
    3b)         size_gb_x10=19; factor=7 ;;
    7b)         size_gb_x10=47; factor=8 ;;
    qwen3-8b)   size_gb_x10=52; factor=8 ;;
    *)          size_gb_x10=20; factor=6 ;;
  esac
  echo $(( bw * factor / size_gb_x10 ))
}

# Format a single model rating line for the recommendation table
# SHARED: Must be identical in mac + linux templates
_model_rating_line() {
  local model_label="$1"
  local toks="$2"
  local is_recommended="$3"

  local icon tag color
  if [[ "$toks" -ge 50 ]]; then
    icon="✓"; color="${COLOR_GREEN}"
    if [[ "$is_recommended" == "true" ]]; then
      tag="[${MSG_HW_TAG_RECOMMENDED}]"
    else
      tag=""
    fi
  elif [[ "$toks" -ge 25 ]]; then
    icon="⚠"; color="${COLOR_YELLOW}"
    tag="[${MSG_HW_TAG_SLOW}]"
  else
    icon="✗"; color="${COLOR_RED}"
    tag="[${MSG_HW_TAG_TOO_SLOW}]"
  fi

  printf "  %b%s  %-16s ~%3d tok/s  %s%b\n" "$color" "$icon" "$model_label" "$toks" "$tag" "${COLOR_RESET}" >&2
}

# Show hardware-aware model recommendation
# SHARED: Must be identical in mac + linux templates
show_hardware_recommendation() {
  local bw="$1"
  local system_ram
  system_ram=$(get_system_ram_gb)

  echo "" >&2
  echo -e "${COLOR_CYAN}${MSG_HW_DETECTION_HEADER}${COLOR_RESET}" >&2
  log_info "$(msg "$MSG_HW_BANDWIDTH" "$bw" "$system_ram")" >&2

  RECOMMENDED_MODEL=$(recommend_model_for_bandwidth "$bw")

  echo "" >&2
  echo -e "${COLOR_CYAN}${MSG_HW_RECOMMENDATION}${COLOR_RESET}" >&2

  local toks_15b toks_3b toks_7b toks_q3
  toks_15b=$(estimate_toks_per_sec "$bw" "1.5b")
  toks_3b=$(estimate_toks_per_sec "$bw" "3b")
  toks_7b=$(estimate_toks_per_sec "$bw" "7b")
  toks_q3=$(estimate_toks_per_sec "$bw" "qwen3-8b")

  _model_rating_line "qwen2.5:1.5b" "$toks_15b" "$( [[ "$RECOMMENDED_MODEL" == "1.5b" ]] && echo true || echo false )"
  _model_rating_line "qwen2.5:3b" "$toks_3b" "$( [[ "$RECOMMENDED_MODEL" == "3b" ]] && echo true || echo false )"
  _model_rating_line "qwen2.5:7b" "$toks_7b" "$( [[ "$RECOMMENDED_MODEL" == "7b" ]] && echo true || echo false )"
  _model_rating_line "qwen3:8b" "$toks_q3" "$( [[ "$RECOMMENDED_MODEL" == "qwen3-8b" ]] && echo true || echo false )"
  echo "" >&2
  log_info "→ ${MSG_HW_MULTI_CALL_HINT}" >&2

  if [[ "$RECOMMENDED_MODEL" == "none" ]]; then
    echo "" >&2
    log_warning "${MSG_HW_LOCAL_TOO_SLOW}" >&2
    log_info "${MSG_HW_CLOUD_HINT}" >&2
    echo "" >&2

    if [[ -r /dev/tty ]]; then
      echo -n "${MSG_HW_PROCEED_LOCAL} " >&2
      local confirm; read -t 30 -r confirm </dev/tty || confirm=""
      if [[ ! "$confirm" =~ ${MSG_CONFIRM_YES} ]]; then
        log_info "${MSG_ABORTED}"
        exit 0
      fi
    fi
    RECOMMENDED_MODEL="$DEFAULT_MODEL"
  fi

}

# Silent inference check: returns 0 if model responds, 1 otherwise (no log output)
# Usage: _check_model_responds "model_name" [timeout_seconds]
_check_model_responds() {
  local model="$1"
  local timeout="${2:-60}"
  local escaped_model response
  escaped_model=$(json_escape_string "$model")
  response=$(curl -sf --max-time "$timeout" "${OLLAMA_API_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${escaped_model}\", \"prompt\": \"OK\", \"stream\": false, \"options\": {\"num_predict\": 5}}" \
    2>/dev/null) || true

  [[ -n "$response" ]] && printf '%s\n' "$response" | grep '"response"' > /dev/null
}

test_model_inference() {
  local model="${1:-$MODEL_NAME}"
  log_info "${MSG_TEST_MODEL}"

  if _check_model_responds "$model"; then
    log_success "${MSG_TEST_OK}"
    return 0
  fi
  log_warning "${MSG_TEST_FAIL}"
  return 1
}

# Measure actual inference speed: returns "tok.dec" (e.g. "42.7") or fails
# SHARED: Must be identical in mac + linux templates
benchmark_inference() {
  local model="${1:-$CUSTOM_MODEL_NAME}"
  local escaped_model
  escaped_model=$(json_escape_string "$model")
  local response
  response=$(curl -sf --max-time 60 "${OLLAMA_API_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${escaped_model}\", \"prompt\": \"Describe in one sentence what you do.\", \"stream\": false, \"options\": {\"num_predict\": 30}}" \
    2>/dev/null) || return 1

  local eval_count eval_duration
  eval_count=$(printf '%s\n' "$response" | grep -o '"eval_count":[0-9]*' | cut -d: -f2)
  eval_duration=$(printf '%s\n' "$response" | grep -o '"eval_duration":[0-9]*' | cut -d: -f2)

  [[ -z "$eval_count" || "$eval_count" -eq 0 || -z "$eval_duration" || "$eval_duration" -eq 0 ]] && return 1

  local toks_x10=$(( eval_count * 10000000000 / eval_duration ))
  printf '%d.%d' $(( toks_x10 / 10 )) $(( toks_x10 % 10 ))
}

# Display benchmark result and persist to ~/.config/hablara/benchmark.json
# SHARED: Must be identical in mac + linux templates
show_benchmark_result() {
  local model="${1:-$CUSTOM_MODEL_NAME}"
  local toks
  toks=$(benchmark_inference "$model") || {
    log_warning "${MSG_BENCH_SKIP}"
    return 0
  }

  local toks_int="${toks%%.*}"
  echo ""
  if [[ "$toks_int" -ge 80 ]]; then
    log_success "$(msg "$MSG_BENCH_RESULT" "$toks" "$model")"
    log_info "${MSG_BENCH_EXCELLENT}"
  elif [[ "$toks_int" -ge 50 ]]; then
    log_success "$(msg "$MSG_BENCH_RESULT" "$toks" "$model")"
    log_info "${MSG_BENCH_GOOD}"
  elif [[ "$toks_int" -ge 25 ]]; then
    log_warning "$(msg "$MSG_BENCH_RESULT" "$toks" "$model")"
    log_warning "${MSG_BENCH_MARGINAL}"
  else
    log_warning "$(msg "$MSG_BENCH_RESULT" "$toks" "$model")"
    log_warning "${MSG_BENCH_TOO_SLOW}"
    log_info "${MSG_HW_CLOUD_HINT}"
  fi

  # Persist benchmark result as multi-model map (atomic write, graceful fail)
  local config_dir="${HOME}/.config/hablara"
  local bench_file="${config_dir}/benchmark.json"
  local tmp_file="${config_dir}/.benchmark.json.tmp"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  mkdir -p "$config_dir" 2>/dev/null || true

  local escaped_model
  escaped_model=$(json_escape_string "$model")
  local new_entry="\"${escaped_model}\":{\"toks_per_sec\":${toks},\"measured_at\":\"${timestamp}\"}"

  # Collect existing entries excluding current model
  local other_entries=""
  if [[ -f "$bench_file" ]]; then
    local raw
    raw=$(cat "$bench_file" 2>/dev/null) || raw=""
    # Extract individual map entries (each "key":{...} on own line)
    local all_entries
    all_entries=$(printf '%s' "$raw" \
      | grep -oE '"[^"]+":\{"toks_per_sec":[0-9.]+,"measured_at":"[^"]*"\}' || true)
    if [[ -n "$all_entries" ]]; then
      # Filter out current model (fixed-string match)
      local filtered
      filtered=$(printf '%s\n' "$all_entries" | grep -Fv "\"${escaped_model}\":" || true)
      if [[ -n "$filtered" ]]; then
        other_entries=$(printf '%s\n' "$filtered" | tr '\n' ',' | sed 's/,$//')
      fi
    fi
  fi

  # Build final JSON and atomic write
  if [[ -n "$other_entries" ]]; then
    printf '{%s,%s}\n' "$other_entries" "$new_entry" > "$tmp_file" 2>/dev/null \
      && mv -f "$tmp_file" "$bench_file" 2>/dev/null || true
  else
    printf '{%s}\n' "$new_entry" > "$tmp_file" 2>/dev/null \
      && mv -f "$tmp_file" "$bench_file" 2>/dev/null || true
  fi
}

wait_for_ollama() {
  local max_attempts=30 attempt=1
  spinner_start "${MSG_WAIT_SERVER}"

  while [[ $attempt -le $max_attempts ]]; do
    curl -sf --max-time 10 "${OLLAMA_API_URL}/api/version" &> /dev/null && {
      spinner_stop
      log_success "${MSG_SERVER_READY}"; return 0
    }
    sleep 1; attempt=$((attempt + 1))
  done

  spinner_stop
  log_error "$(msg "$MSG_SERVER_NO_RESPONSE" "$max_attempts")"
  return 1
}

cleanup() {
  local exit_code=$?
  spinner_stop
  if [[ $exit_code -ne 0 && "$STATUS_CHECK_MODE" == "false" && "$CLEANUP_MODE" == "false" && "$DIAGNOSE_MODE" == "false" ]]; then
    log_error "${MSG_SETUP_FAILED}"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Runs a command with a timeout (Bash 3.2 compatible, no GNU timeout needed)
# Usage: run_with_timeout SECONDS COMMAND [ARGS...]
# Returns: command exit code, or 124 on timeout (GNU convention)
# Note: stdout/stderr from COMMAND are inherited (pipe/redirect as needed on call site)
run_with_timeout() {
  local timeout_secs="$1"
  shift

  # Run command in background; inherits current stdout/stderr
  "$@" &
  local cmd_pid=$!

  # Watchdog: SIGTERM after timeout, then SIGKILL after 5s grace period
  # Redirect all FDs to /dev/null so the watchdog doesn't hold caller's pipe open
  (
    exec </dev/null >/dev/null 2>/dev/null
    sleep "$timeout_secs"
    kill -TERM "$cmd_pid" 2>/dev/null
    sleep 5
    kill -KILL "$cmd_pid" 2>/dev/null
  ) &
  local watchdog_pid=$!

  # Wait for command; capture exit code without triggering set -e
  local exit_code=0
  wait "$cmd_pid" 2>/dev/null || exit_code=$?

  # Cleanup watchdog
  kill "$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null || true

  # SIGTERM=143 or SIGKILL=137 means killed by watchdog → timeout
  if [[ $exit_code -eq 143 || $exit_code -eq 137 ]]; then
    return 124
  fi
  return $exit_code
}

# Downloads a model with heartbeat and stall detection
# Usage: _pull_with_heartbeat MODEL_NAME HARD_TIMEOUT_SECS
# Returns: 0 on success, 1 on stall/error, 124 on hard timeout
_pull_with_heartbeat() {
  local model="$1"
  local hard_timeout="$2"
  local stall_timeout=300    # 5 minutes without file-size growth
  local heartbeat_interval=30
  local first_heartbeat=true

  local pull_log
  pull_log=$(mktemp "${TMPDIR:-/tmp}/hablara-pull.XXXXXX")

  # Run ollama pull in background; capture all output to log file
  ollama pull "$model" > "$pull_log" 2>&1 &
  local pull_pid=$!

  local start_time=$SECONDS
  local last_size=0
  local last_progress_time=$SECONDS
  local last_heartbeat_time=0

  while kill -0 "$pull_pid" 2>/dev/null; do
    sleep 5
    local elapsed=$(( SECONDS - start_time ))

    # Hard timeout
    if [[ $elapsed -ge $hard_timeout ]]; then
      log_warning "$(msg "$MSG_DOWNLOAD_HARD_TIMEOUT" "$(( hard_timeout / 60 ))")"
      kill -TERM "$pull_pid" 2>/dev/null
      sleep 5
      kill -KILL "$pull_pid" 2>/dev/null
      wait "$pull_pid" 2>/dev/null || true
      rm -f "$pull_log"
      return 124
    fi

    # Stall detection: abort if file size hasn't grown in stall_timeout seconds
    local current_size
    current_size=$(wc -c < "$pull_log" 2>/dev/null || echo "0")
    current_size="${current_size##* }"  # trim leading whitespace (macOS wc)
    if [[ "${current_size:-0}" -gt "${last_size:-0}" ]]; then
      last_size="$current_size"
      last_progress_time=$SECONDS
    else
      local stall_secs=$(( SECONDS - last_progress_time ))
      if [[ $stall_secs -ge $stall_timeout ]]; then
        log_warning "$(msg "$MSG_DOWNLOAD_STALL" "$(( stall_timeout / 60 ))")"
        kill -TERM "$pull_pid" 2>/dev/null
        sleep 5
        kill -KILL "$pull_pid" 2>/dev/null
        wait "$pull_pid" 2>/dev/null || true
        rm -f "$pull_log"
        return 1
      fi
    fi

    # Heartbeat: first after 1s, then every 30 seconds
    if [[ "$first_heartbeat" == "true" && $elapsed -ge 1 ]] || \
       [[ "$first_heartbeat" == "false" && $(( elapsed - last_heartbeat_time )) -ge $heartbeat_interval ]]; then
      first_heartbeat=false
      last_heartbeat_time=$elapsed
      local last_line
      last_line=$(tail -1 "$pull_log" 2>/dev/null | tr '\r' '\n' | tail -1 || echo "")
      if [[ -n "$last_line" ]]; then
        log_info "  ${last_line}"
      else
        log_info "$(msg "$MSG_DOWNLOAD_RUNNING" "$elapsed")"
      fi
    fi
  done

  local exit_code=0
  wait "$pull_pid" 2>/dev/null || exit_code=$?
  rm -f "$pull_log"
  return $exit_code
}

# ============================================================================
# Status Check
# ============================================================================

run_status_check() {
  STATUS_CHECK_MODE=true
  local errors=0

  # Lokale Status-Hilfsfunktionen (stdout-only, kein stderr-Interleaving)
  status_ok()   { echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $1"; }
  status_warn() { echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} $1"; }
  status_fail() { echo -e "  ${COLOR_RED}✗${COLOR_RESET} $1"; }
  status_info() { echo -e "  ${COLOR_YELLOW}•${COLOR_RESET} $1"; }

  echo ""
  echo -e "${COLOR_CYAN}${MSG_STATUS_TITLE_LINUX}${COLOR_RESET}"
  echo ""

  # 1. Ollama installed?
  if command_exists ollama; then
    local current_version
    current_version=$(get_ollama_version_string)
    status_ok "$(msg "$MSG_STATUS_INSTALLED" "$current_version")"
    if [[ "$current_version" != "unknown" ]] && ! version_gte "$current_version" "$MIN_OLLAMA_VERSION"; then
      echo -e "    ${COLOR_YELLOW}$(msg "$MSG_STATUS_UPDATE_REC_APT" "$MIN_OLLAMA_VERSION")${COLOR_RESET}"
    fi
  else
    status_fail "${MSG_STATUS_NOT_FOUND}"
    errors=$((errors + 1))
  fi

  # 2. Server reachable?
  local server_reachable=false
  if curl -sf --max-time 5 "${OLLAMA_API_URL}/api/version" &> /dev/null; then
    server_reachable=true
    status_ok "${MSG_STATUS_SERVER_OK}"
  else
    status_fail "${MSG_STATUS_SERVER_FAIL}"
    errors=$((errors + 1))
  fi

  # 3. GPU detected?
  local gpu_info
  gpu_info=$(check_gpu_available) || true
  case "$gpu_info" in
    nvidia:*)    status_ok "${MSG_STATUS_GPU_NVIDIA} ${gpu_info#nvidia:}" ;;
    amd_rocm)    status_ok "${MSG_GPU_STATUS_AMD}" ;;
    intel_oneapi) status_ok "${MSG_GPU_STATUS_INTEL}" ;;
    *)           status_info "${MSG_STATUS_NO_GPU}" ;;
  esac

  # 4. Base models present? (scan all variants, largest first)
  local base_models_found=()
  local variant
  for variant in qwen3-8b 7b 3b 1.5b; do
    local config_line
    config_line=$(get_model_config "$variant") || continue
    local model_name="${config_line%%|*}"
    if ollama_model_exists "$model_name"; then
      base_models_found+=("$model_name")
    fi
  done

  if [[ ${#base_models_found[@]} -eq 1 ]]; then
    status_ok "$(msg "$MSG_STATUS_BASE_MODEL" "${base_models_found[0]}")"
  elif [[ ${#base_models_found[@]} -gt 1 ]]; then
    status_ok "${MSG_STATUS_BASE_MODELS}"
    for model in "${base_models_found[@]}"; do
      echo -e "    ${COLOR_GREEN}✓${COLOR_RESET} ${model}"
    done
  else
    status_fail "${MSG_STATUS_NO_BASE}"
    errors=$((errors + 1))
  fi

  # 5. Custom models present? (scan all variants, largest first)
  local custom_models_found=()
  for variant in qwen3-8b 7b 3b 1.5b; do
    local config_line
    config_line=$(get_model_config "$variant") || continue
    local model_name="${config_line%%|*}"
    if ollama_model_exists "${model_name}-custom"; then
      custom_models_found+=("${model_name}-custom")
    fi
  done

  if [[ ${#custom_models_found[@]} -eq 1 ]]; then
    status_ok "$(msg "$MSG_STATUS_HABLARA_MODEL" "${custom_models_found[0]}")"
    if [[ ${#base_models_found[@]} -eq 0 ]]; then
      echo -e "    ${COLOR_YELLOW}${MSG_STATUS_BASE_MISSING}${COLOR_RESET}"
    fi
  elif [[ ${#custom_models_found[@]} -gt 1 ]]; then
    status_ok "${MSG_STATUS_HABLARA_MODELS}"
    for model in "${custom_models_found[@]}"; do
      echo -e "    ${COLOR_GREEN}✓${COLOR_RESET} ${model}"
    done
    if [[ ${#base_models_found[@]} -eq 0 ]]; then
      echo -e "    ${COLOR_YELLOW}${MSG_STATUS_BASE_MISSING}${COLOR_RESET}"
    fi
  else
    status_fail "${MSG_STATUS_NO_HABLARA}"
    errors=$((errors + 1))
  fi

  # 6. Model inference works? (use smallest model for fastest check)
  # Explicit priority: 3b > 7b > qwen3-8b (smallest = fastest)
  local model_priority=(1.5b 3b 7b qwen3-8b)
  local test_model=""

  # Try custom models first
  for prio in "${model_priority[@]}"; do
    local config_line
    config_line=$(get_model_config "$prio") || continue
    local candidate="${config_line%%|*}-custom"
    for found in "${custom_models_found[@]}"; do
      if [[ "$found" == "$candidate" ]]; then
        test_model="$found"
        break 2
      fi
    done
  done

  # Fallback to base models
  if [[ -z "$test_model" ]]; then
    for prio in "${model_priority[@]}"; do
      local config_line
      config_line=$(get_model_config "$prio") || continue
      local candidate="${config_line%%|*}"
      for found in "${base_models_found[@]}"; do
        if [[ "$found" == "$candidate" ]]; then
          test_model="$found"
          break 2
        fi
      done
    done
  fi
  if [[ "$server_reachable" != "true" ]]; then
    status_warn "${MSG_STATUS_INFERENCE_SKIP}"
  elif [[ -n "$test_model" ]]; then
    if _check_model_responds "$test_model" 15; then
      status_ok "${MSG_STATUS_MODEL_OK}"
    else
      status_fail "${MSG_STATUS_MODEL_FAIL}"
      errors=$((errors + 1))
    fi
  else
    status_fail "${MSG_STATUS_MODEL_FAIL}"
    errors=$((errors + 1))
  fi

  # 7. Storage usage (only Hablará-relevant qwen2.5 models, parsed from ollama list)
  local all_models=("${base_models_found[@]}" "${custom_models_found[@]}")
  if [[ ${#all_models[@]} -gt 0 ]] && command_exists ollama; then
    local total_gb=0 ollama_list
    ollama_list=$(run_with_timeout 15 ollama list 2>/dev/null) || ollama_list=""
    for model in "${all_models[@]}"; do
      local size_str
      size_str=$(echo "$ollama_list" | awk -v m="$model" '$1 == m {print $3, $4}')
      if [[ "$size_str" =~ ([0-9.]+)[[:space:]]*([KMGT]?B) ]]; then
        local val="${BASH_REMATCH[1]}" unit="${BASH_REMATCH[2]}"
        case "$unit" in
          GB) total_gb=$(awk "BEGIN {printf \"%.1f\", $total_gb + $val}") ;;
          MB) total_gb=$(awk "BEGIN {printf \"%.1f\", $total_gb + $val / 1024}") ;;
          KB) total_gb=$(awk "BEGIN {printf \"%.1f\", $total_gb + $val / 1048576}") ;;
        esac
      fi
    done
    status_info "$(msg "$MSG_STATUS_STORAGE" "$total_gb")"
  else
    status_info "${MSG_STATUS_STORAGE_UNKNOWN}"
  fi

  echo ""
  if [[ $errors -eq 0 ]]; then
    echo -e "${COLOR_GREEN}${MSG_STATUS_ALL_OK}${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}$(msg "$MSG_STATUS_PROBLEMS" "$errors")${COLOR_RESET}"
    echo -e "${MSG_STATUS_REPAIR} $(script_name)"
  fi
  echo ""

  [[ $errors -eq 0 ]]
}

# ============================================================================
# Diagnose Report
# ============================================================================

run_diagnose_report() {
  DIAGNOSE_MODE=true
  STATUS_CHECK_MODE=true  # Suppress EXIT trap error message

  # --- System ---
  local os_version arch ram_total_gb ram_free_gb free_disk_gb shell_version

  if [[ -f /etc/os-release ]]; then
    os_version=$(grep -E "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || true)
    [[ -z "$os_version" ]] && os_version=$(grep -E "^ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "Linux")
  else
    os_version="Linux"
  fi
  arch=$(uname -m 2>/dev/null || echo "${MSG_DIAGNOSE_UNKNOWN}")

  # RAM via /proc/meminfo
  local mem_total_kb mem_avail_kb
  mem_total_kb=$(grep -E '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
  mem_avail_kb=$(grep -E '^MemAvailable:' /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
  if [[ "$mem_total_kb" =~ ^[0-9]+$ && "$mem_total_kb" -gt 0 ]]; then
    ram_total_gb=$(( mem_total_kb / 1024 / 1024 ))
  else
    ram_total_gb="${MSG_DIAGNOSE_UNKNOWN}"
  fi
  if [[ "$mem_avail_kb" =~ ^[0-9]+$ && "$mem_avail_kb" -gt 0 ]]; then
    ram_free_gb=$(( mem_avail_kb / 1024 / 1024 ))
  else
    ram_free_gb="${MSG_DIAGNOSE_UNKNOWN}"
  fi

  # Free disk space on Ollama data path
  local check_path
  check_path=$(get_ollama_data_path)
  [[ ! -d "$check_path" ]] && check_path="${HOME}"
  free_disk_gb=$(get_free_space_gb)
  [[ "$free_disk_gb" -eq 0 ]] 2>/dev/null && free_disk_gb="${MSG_DIAGNOSE_UNKNOWN}"

  shell_version="${BASH_VERSION:-${MSG_DIAGNOSE_UNKNOWN}}"

  # --- Ollama ---
  local ollama_version="${MSG_DIAGNOSE_NOT_INSTALLED}"
  local server_status="${MSG_DIAGNOSE_NOT_REACHABLE}"
  local gpu_label="${MSG_DIAGNOSE_UNKNOWN}"

  if command_exists ollama; then
    ollama_version=$(get_ollama_version_string)
  fi

  if curl -sf --max-time 5 "${OLLAMA_API_URL}/api/version" &> /dev/null; then
    server_status="${MSG_DIAGNOSE_RUNNING}"
  fi

  local gpu_info
  gpu_info=$(check_gpu_available) || true
  case "$gpu_info" in
    nvidia:*)    gpu_label="${MSG_DIAGNOSE_GPU_NVIDIA} ${gpu_info#nvidia:}" ;;
    amd_rocm)    gpu_label="${MSG_DIAGNOSE_GPU_AMD}" ;;
    intel_oneapi) gpu_label="${MSG_DIAGNOSE_GPU_INTEL}" ;;
    *)           gpu_label="${MSG_DIAGNOSE_GPU_NONE}" ;;
  esac

  # --- Models ---
  local models_output=""
  local total_storage_gb=0
  local ollama_list=""
  if command_exists ollama; then
    ollama_list=$(run_with_timeout 15 ollama list 2>/dev/null) || ollama_list=""
  fi
  if [[ -n "$ollama_list" ]]; then
    local variant
    for variant in qwen3-8b 7b 3b 1.5b; do
      local config_line
      config_line=$(get_model_config "$variant") || continue
      local model_name="${config_line%%|*}"

      # Check base model
      if ollama_model_exists "$model_name"; then
        local size_str
        size_str=$(echo "$ollama_list" | awk -v m="$model_name" '$1 == m {print $3, $4}')
        local size_display="${size_str:-${MSG_DIAGNOSE_UNKNOWN}}"
        local pad=$(( 20 - ${#model_name} )); [[ $pad -lt 1 ]] && pad=1
        models_output="${models_output}    ${model_name}$(printf '%*s' "$pad" '')${size_display}  ✓"$'\n'
        if [[ "$size_str" =~ ([0-9.]+)[[:space:]]*([KMGT]?B) ]]; then
          local val="${BASH_REMATCH[1]}" unit="${BASH_REMATCH[2]}"
          case "$unit" in
            GB) total_storage_gb=$(awk "BEGIN {printf \"%.1f\", $total_storage_gb + $val}") ;;
            MB) total_storage_gb=$(awk "BEGIN {printf \"%.1f\", $total_storage_gb + $val / 1024}") ;;
          esac
        fi
      fi

      # Check custom model
      local custom_name="${model_name}-custom"
      if ollama_model_exists "$custom_name"; then
        local size_str
        size_str=$(echo "$ollama_list" | awk -v m="$custom_name" '$1 == m {print $3, $4}')
        local size_display="${size_str:-${MSG_DIAGNOSE_UNKNOWN}}"
        local responds_label=""
        if [[ "$server_status" == "${MSG_DIAGNOSE_RUNNING}" ]] && _check_model_responds "$custom_name" 15; then
          responds_label=" ${MSG_DIAGNOSE_RESPONDS}"
        fi
        local pad=$(( 20 - ${#custom_name} )); [[ $pad -lt 1 ]] && pad=1
        models_output="${models_output}    ${custom_name}$(printf '%*s' "$pad" '')${size_display}  ✓${responds_label}"$'\n'
        if [[ "$size_str" =~ ([0-9.]+)[[:space:]]*([KMGT]?B) ]]; then
          local val="${BASH_REMATCH[1]}" unit="${BASH_REMATCH[2]}"
          case "$unit" in
            GB) total_storage_gb=$(awk "BEGIN {printf \"%.1f\", $total_storage_gb + $val}") ;;
            MB) total_storage_gb=$(awk "BEGIN {printf \"%.1f\", $total_storage_gb + $val / 1024}") ;;
          esac
        fi
      fi
    done
  fi

  if [[ -z "$models_output" ]]; then
    models_output="${MSG_DIAGNOSE_NO_MODELS}"$'\n'
  fi

  # --- Ollama Log (journalctl for systemd, fallback to file) ---
  local log_output=""
  if command_exists journalctl; then
    local journal_lines
    journal_lines=$(journalctl -u ollama --no-pager -n 200 2>/dev/null | grep -iE 'ERROR|WARN|fatal' | tail -10 || true)
    if [[ -n "$journal_lines" ]]; then
      log_output="$journal_lines"
    else
      log_output="${MSG_DIAGNOSE_NO_ERRORS}"
    fi
  elif [[ -r "${HOME}/.ollama/logs/server.log" ]]; then
    local error_lines
    error_lines=$(tail -200 "${HOME}/.ollama/logs/server.log" 2>/dev/null | grep -iE 'ERROR|WARN|fatal' | tail -10 || true)
    if [[ -n "$error_lines" ]]; then
      log_output="$error_lines"
    else
      log_output="${MSG_DIAGNOSE_NO_ERRORS}"
    fi
  else
    log_output="$(msg "$MSG_DIAGNOSE_NO_LOG" "${HOME}/.ollama/logs/server.log")"
  fi

  # --- Output (plain text, no ANSI colors) ---
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  local report_content
  report_content=$(cat <<EOF

${MSG_DIAGNOSE_TITLE}

${MSG_DIAGNOSE_SECTION_SYSTEM}:
  ${MSG_DIAGNOSE_OS}           ${os_version} (${arch})
  ${MSG_DIAGNOSE_RAM}          ${ram_total_gb} GB (${ram_free_gb} GB ${MSG_DIAGNOSE_RAM_AVAIL})
  ${MSG_DIAGNOSE_STORAGE_DISK}:     ${free_disk_gb} GB ${MSG_DIAGNOSE_STORAGE_FREE}
  ${MSG_DIAGNOSE_SHELL}        bash ${shell_version}

${MSG_DIAGNOSE_SECTION_OLLAMA}:
  ${MSG_DIAGNOSE_VERSION}      ${ollama_version}
  ${MSG_DIAGNOSE_SERVER}       ${server_status}
  ${MSG_DIAGNOSE_API}      ${OLLAMA_API_URL}
  ${MSG_DIAGNOSE_GPU}          ${gpu_label}

${MSG_DIAGNOSE_SECTION_MODELS}:
${models_output}
${MSG_DIAGNOSE_STORAGE_LABEL}  ~${total_storage_gb} GB

${MSG_DIAGNOSE_LOG_LABEL}
${log_output}

---
${MSG_DIAGNOSE_CREATED} ${timestamp}
${MSG_DIAGNOSE_SCRIPT}   setup-ollama-linux.sh v${SCRIPT_VERSION}
EOF
)
  printf '%s\n' "$report_content"

  # Save to Desktop (graceful skip on headless systems without Desktop)
  # XDG env vars must be absolute paths (§6.4) — fall back to ~/Desktop if relative
  local desktop_dir
  if [[ -n "${XDG_DESKTOP_DIR:-}" && "${XDG_DESKTOP_DIR}" == /* ]]; then
    desktop_dir="${XDG_DESKTOP_DIR}"
  else
    desktop_dir="${HOME}/Desktop"
  fi
  if [[ -d "$desktop_dir" ]]; then
    local report_file
    report_file="${desktop_dir}/hablara-diagnose-$(date '+%Y-%m-%d_%H-%M-%S').txt"
    if printf '%s\n' "$report_content" > "$report_file" 2>/dev/null; then
      log_success "$(msg "${MSG_DIAGNOSE_SAVED}" "${report_file}")"
    else
      log_warning "${MSG_DIAGNOSE_SAVE_FAILED}"
    fi
  fi
  return 0
}

# ============================================================================
# Cleanup
# ============================================================================

run_cleanup() {
  CLEANUP_MODE=true
  STATUS_CHECK_MODE=true  # Suppress EXIT trap error message

  if [[ ! -r /dev/tty ]]; then
    log_error "${MSG_CLEANUP_NEEDS_TTY}"
    exit 1
  fi

  if ! command_exists ollama; then
    log_error "${MSG_CLEANUP_NO_OLLAMA}"
    exit 1
  fi

  if ! ollama list &>/dev/null; then
    log_error "${MSG_CLEANUP_NO_SERVER}"
    log_info "${MSG_CLEANUP_START_HINT}"
    exit 1
  fi

  # Discover installed Hablará variants
  local variants=() variant_labels=()
  local variant
  for variant in 1.5b 3b 7b qwen3-8b; do
    local config_line
    config_line=$(get_model_config "$variant") || continue
    local model_name="${config_line%%|*}"
    local custom_name="${model_name}-custom"
    local has_base=false has_custom=false

    ollama_model_exists "$model_name" && has_base=true
    ollama_model_exists "$custom_name" && has_custom=true

    if $has_base && $has_custom; then
      variants+=("${variant}|${model_name}|${custom_name}|both")
      variant_labels+=("${variant}  (${model_name} + ${custom_name})")
    elif $has_base; then
      variants+=("${variant}|${model_name}||base")
      variant_labels+=("${variant}  (${model_name})")
    elif $has_custom; then
      variants+=("${variant}||${custom_name}|custom")
      variant_labels+=("${variant}  (${custom_name})")
    fi
  done

  if [[ ${#variants[@]} -eq 0 ]]; then
    echo ""
    log_info "${MSG_CLEANUP_NO_MODELS}"
    echo ""
    return 0
  fi

  echo ""
  echo -e "${COLOR_CYAN}${MSG_CLEANUP_INSTALLED}${COLOR_RESET}"
  echo ""
  local i
  for i in "${!variant_labels[@]}"; do
    echo "  $((i + 1))) ${variant_labels[$i]}"
  done
  echo ""
  echo -n "${MSG_CLEANUP_PROMPT}"

  local choice
  read -t 60 -r choice </dev/tty || choice=""

  # Empty = abort
  if [[ -z "$choice" ]]; then
    return 0
  fi

  # Validate choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 || "$choice" -gt ${#variants[@]} ]]; then
    log_error "${MSG_CLEANUP_INVALID}"
    return 1
  fi

  local selected="${variants[$((choice - 1))]}"
  local _sel_variant sel_base sel_custom _sel_type
  IFS='|' read -r _sel_variant sel_base sel_custom _sel_type <<< "$selected"

  echo ""

  # Delete custom first (depends on base)
  local rm_err
  if [[ -n "$sel_custom" ]]; then
    if rm_err=$(run_with_timeout 30 ollama rm "$sel_custom" 2>&1); then
      log_success "$(msg "$MSG_CLEANUP_DELETED" "$sel_custom")"
    else
      log_warning "$(msg "$MSG_CLEANUP_FAILED" "$sel_custom" "${rm_err:-$MSG_CLEANUP_UNKNOWN_ERR}")"
    fi
  fi

  if [[ -n "$sel_base" ]]; then
    if rm_err=$(run_with_timeout 30 ollama rm "$sel_base" 2>&1); then
      log_success "$(msg "$MSG_CLEANUP_DELETED" "$sel_base")"
    else
      log_warning "$(msg "$MSG_CLEANUP_FAILED" "$sel_base" "${rm_err:-$MSG_CLEANUP_UNKNOWN_ERR}")"
    fi
  fi

  # Check if any Hablará models remain
  local remaining=false
  for variant in 1.5b 3b 7b qwen3-8b; do
    local config_line
    config_line=$(get_model_config "$variant") || continue
    local model_name="${config_line%%|*}"
    if ollama_model_exists "$model_name" || ollama_model_exists "${model_name}-custom"; then
      remaining=true
      break
    fi
  done

  if ! $remaining; then
    echo ""
    log_warning "${MSG_CLEANUP_NONE_LEFT}"
  fi

  echo ""
  return 0
}

# ============================================================================
# Model Selection
# ============================================================================

show_help() {
  echo ""
  echo -e "${COLOR_CYAN}Hablará Ollama Setup v${SCRIPT_VERSION} (Linux)${COLOR_RESET}"
  echo ""
  echo "  ${MSG_HELP_DESCRIPTION}"
  echo ""
  echo -e "${COLOR_GREEN}${MSG_HELP_USAGE}${COLOR_RESET}"
  echo "  $(script_name) [${MSG_HELP_OPTS_LABEL}]"
  echo ""
  echo -e "${COLOR_GREEN}${MSG_HELP_OPTIONS}${COLOR_RESET}"
  echo "${MSG_HELP_OPT_MODEL}"
  echo "${MSG_HELP_OPT_UPDATE}"
  echo "${MSG_HELP_OPT_STATUS}"
  echo "${MSG_HELP_OPT_DIAGNOSE}"
  echo "${MSG_HELP_OPT_CLEANUP}"
  echo "${MSG_HELP_OPT_LANG}"
  echo "${MSG_HELP_OPT_HELP}"
  echo ""
  echo "  ${MSG_HELP_NO_OPTS}"
  echo ""
  echo -e "${COLOR_GREEN}${MSG_HELP_VARIANTS}${COLOR_RESET}"
  echo "  qwen2.5-1.5b  ~1 GB     ${MSG_MODEL_1_5B}"
  echo "  qwen2.5-3b    ~2 GB     ${MSG_MODEL_3B}"
  echo "  qwen2.5-7b    ~4.7 GB   ${MSG_MODEL_7B}"
  echo "  qwen3-8b      ~5.2 GB   ${MSG_MODEL_QWEN3}"
  echo ""
  echo -e "${COLOR_GREEN}${MSG_HELP_EXAMPLES}${COLOR_RESET}"
  echo "  $(script_name) ${MSG_HELP_EX_MODEL}"
  echo "  $(script_name) ${MSG_HELP_EX_UPDATE}"
  echo "  $(script_name) ${MSG_HELP_EX_STATUS}"
  echo "  $(script_name) ${MSG_HELP_EX_DIAGNOSE}"
  echo "  $(script_name) ${MSG_HELP_EX_CLEANUP}"
  echo "${MSG_HELP_EX_PIPE}"
  echo ""
  echo -e "${COLOR_GREEN}${MSG_HELP_EXIT_CODES}${COLOR_RESET}"
  echo "${MSG_HELP_EXIT_0}"
  echo "${MSG_HELP_EXIT_1}"
  echo "${MSG_HELP_EXIT_2}"
  echo "${MSG_HELP_EXIT_3}"
  echo "${MSG_HELP_EXIT_4}"
  echo ""
}

get_system_ram_gb() {
  local mem_kb
  mem_kb=$(grep -E '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}' || true)
  [[ -n "$mem_kb" && "$mem_kb" =~ ^[0-9]+$ ]] && echo $(( mem_kb / 1024 / 1024 )) || echo "0"
}

show_model_menu() {
  local rec="${RECOMMENDED_MODEL:-$DEFAULT_MODEL}"
  local s1="" s2="" s3="" s4=""
  case "$rec" in
    1.5b)      s1=" ★" ;;
    3b)        s2=" ★" ;;
    7b)        s3=" ★" ;;
    qwen3-8b)  s4=" ★" ;;
  esac

  # Map recommended model to menu number for dynamic default
  local default_num="2"
  case "$rec" in
    1.5b)      default_num="1" ;;
    3b)        default_num="2" ;;
    7b)        default_num="3" ;;
    qwen3-8b)  default_num="4" ;;
  esac

  echo "" >&2
  echo -e "${COLOR_CYAN}${MSG_CHOOSE_MODEL}${COLOR_RESET}" >&2
  echo "" >&2
  echo "  1) qwen2.5-1.5b - ${MSG_MODEL_1_5B}${s1}" >&2
  echo "  2) qwen2.5-3b   - ${MSG_MODEL_3B}${s2}" >&2
  echo "  3) qwen2.5-7b   - ${MSG_MODEL_7B}${s3}" >&2
  echo "  4) qwen3-8b     - ${MSG_MODEL_QWEN3}${s4}" >&2
  echo "" >&2

  local prompt
  if [[ -n "${RECOMMENDED_MODEL:-}" ]]; then
    prompt="$(msg "$MSG_CHOICE_PROMPT_HW" "$default_num")"
  else
    prompt="${MSG_CHOICE_PROMPT}"
  fi
  echo -n "${prompt}: " >&2

  local choice
  read -t 60 -r choice </dev/tty || choice=""
  case "$choice" in
    1) echo "1.5b" ;; 2) echo "3b" ;; 3) echo "7b" ;; 4) echo "qwen3-8b" ;; *) echo "$rec" ;;
  esac
}

# IMPORTANT: Must run in parent shell (not subshell) - sets global variables
parse_model_config() {
  local variant="$1"
  local config
  config=$(get_model_config "$variant") || return 1

  IFS='|' read -r MODEL_NAME MODEL_SIZE REQUIRED_DISK_SPACE_GB RAM_WARNING <<< "$config"
  CUSTOM_MODEL_NAME="${MODEL_NAME}-custom"
  return 0
}

show_main_menu() {
  echo "" >&2
  echo -e "${COLOR_CYAN}${MSG_CHOOSE_ACTION}${COLOR_RESET}" >&2
  echo "" >&2
  echo "  1) ${MSG_ACTION_SETUP}" >&2
  echo "  2) ${MSG_ACTION_STATUS}" >&2
  echo "  3) ${MSG_ACTION_DIAGNOSE}" >&2
  echo "  4) ${MSG_ACTION_CLEANUP}" >&2
  echo "" >&2
  echo -n "${MSG_ACTION_PROMPT}: " >&2

  local choice
  read -t 60 -r choice </dev/tty || choice=""
  case "$choice" in
    2) echo "status" ;;
    3) echo "diagnose" ;;
    4) echo "cleanup" ;;
    *) echo "setup" ;;
  esac
}

select_model() {
  local requested_model=""
  local has_explicit_flags=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--model)
        [[ -z "${2:-}" ]] && { log_error "$(msg "$MSG_OPT_NEEDS_ARG" "$1")"; exit 1; }
        requested_model="$2"; has_explicit_flags=true; shift 2 ;;
      --update) FORCE_UPDATE=true; has_explicit_flags=true; shift ;;
      --status) local _rc=0; run_status_check || _rc=$?; exit $_rc ;;
      --diagnose) local _rc=0; run_diagnose_report || _rc=$?; exit $_rc ;;
      --cleanup) local _rc=0; run_cleanup || _rc=$?; exit $_rc ;;
      --lang) shift 2 ;;  # Already processed by parse_lang_flag
      -h|--help) show_help; exit 0 ;;
      *) log_error "$(msg "$MSG_UNKNOWN_OPTION" "$1")"; exit 1 ;;
    esac
  done

  # Interactive main menu (only when no explicit flags and TTY available)
  if [[ "$has_explicit_flags" == "false" && -z "$requested_model" && -r /dev/tty ]]; then
    local action
    action=$(show_main_menu) || action="setup"
    if [[ "$action" == "status" ]]; then
      local _rc=0; run_status_check || _rc=$?; exit $_rc
    elif [[ "$action" == "diagnose" ]]; then
      local _rc=0; run_diagnose_report || _rc=$?; exit $_rc
    elif [[ "$action" == "cleanup" ]]; then
      local _rc=0; run_cleanup || _rc=$?; exit $_rc
    fi
  fi

  # Hardware-aware recommendation (before model menu)
  local detected_bw=0
  detected_bw=$(detect_memory_bandwidth_gbps) || detected_bw=0
  if [[ "$detected_bw" -gt 0 && -z "$requested_model" && -r /dev/tty ]]; then
    show_hardware_recommendation "$detected_bw"
  elif [[ "$detected_bw" -eq 0 && -z "$requested_model" && -r /dev/tty ]]; then
    log_info "${MSG_HW_UNKNOWN_CHIP}" >&2
  fi

  if [[ -z "$requested_model" ]]; then
    # /dev/tty allows interactive input even when piped via curl | bash
    if [[ -r /dev/tty ]]; then
      requested_model=$(show_model_menu) || requested_model="$DEFAULT_MODEL"
    else
      requested_model="$DEFAULT_MODEL"
    fi
  fi

  if ! parse_model_config "$requested_model"; then
    log_error "$(msg "$MSG_INVALID_MODEL" "$requested_model")"
    echo "${MSG_VALID_VARIANTS}"
    exit 1
  fi

  # RAM warning for large models
  if [[ -n "${RAM_WARNING:-}" ]]; then
    local system_ram
    system_ram=$(get_system_ram_gb)

    if [[ "$system_ram" -gt 0 && "$system_ram" -lt "${RAM_WARNING}" ]]; then
      echo ""
      log_warning "$(msg "$MSG_RAM_WARN_MODEL" "$RAM_WARNING")"
      log_warning "$(msg "$MSG_RAM_WARN_SYS" "$system_ram")"
      echo ""

      if [[ -r /dev/tty ]]; then
        echo -n "${MSG_CONTINUE_ANYWAY} ${MSG_CONFIRM_PROMPT}: "
        local confirm; read -t 30 -r confirm </dev/tty || confirm=""
        [[ ! "$confirm" =~ ${MSG_CONFIRM_YES} ]] && { log_info "${MSG_ABORTED}"; exit 0; }
      else
        log_warning "${MSG_PROCEED_NONINTERACTIVE}"
      fi
    fi
  fi

  [[ -z "${MODEL_NAME}" ]] && { log_error "${MSG_INTERNAL_ERROR}"; exit 1; }
  log_info "$(msg "$MSG_SELECTED_MODEL" "$MODEL_NAME")"
  return 0
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

preflight_checks() {
  echo ""
  echo -e "${COLOR_GREEN}========================================${COLOR_RESET}"
  echo -e "${COLOR_GREEN}  Hablará Ollama Setup v${SCRIPT_VERSION} (Linux)${COLOR_RESET}"
  echo -e "${COLOR_GREEN}========================================${COLOR_RESET}"
  echo ""

  log_step "${MSG_PREFLIGHT}"

  if [[ "$(uname)" != "Linux" ]]; then
    log_error "${MSG_PLATFORM_ERROR_LINUX}"
    log_info "${MSG_PLATFORM_MAC_HINT}"
    exit 4
  fi

  # Required tools check
  for tool in curl awk; do
    command_exists "$tool" || { log_error "$(msg "$MSG_TOOL_MISSING" "$tool")"; exit 1; }
  done

  local distro="unknown"
  if [[ -f /etc/os-release ]]; then
    # Parse instead of source for security (|| true prevents pipefail abort when key is missing)
    distro=$(grep -E "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || true)
    [[ -z "$distro" ]] && distro=$(grep -E "^ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "unknown")
  fi
  log_info "${MSG_DIAGNOSE_DISTRIBUTION} ${distro}"

  local free_space
  free_space=$(get_free_space_gb)
  if [[ $free_space -lt $REQUIRED_DISK_SPACE_GB ]]; then
    log_error "$(msg "$MSG_DISK_INSUFFICIENT" "$free_space" "$REQUIRED_DISK_SPACE_GB")"
    exit 2
  fi
  log_success "$(msg "$MSG_DISK_OK" "$free_space")"

  if ! curl -sf --connect-timeout 5 --max-time 10 "https://ollama.com" &> /dev/null; then
    log_error "${MSG_NETWORK_ERROR}"
    log_info "${MSG_NETWORK_HINT}"
    exit 3
  fi
  log_success "${MSG_NETWORK_OK}"

  local gpu_info
  gpu_info=$(check_gpu_available) || true
  case "$gpu_info" in
    nvidia:*) log_success "${MSG_GPU_NVIDIA}: ${gpu_info#nvidia:}" ;;
    amd_rocm) log_success "${MSG_GPU_AMD}" ;;
    intel_oneapi) log_success "${MSG_GPU_INTEL}" ;;
    cpu) log_warning "${MSG_GPU_NONE}" ;;
  esac

  echo ""
  return 0
}

# ============================================================================
# Ollama Installation
# ============================================================================

port_in_use() {
  local port="${1:-11434}"

  # Multiple detection methods for compatibility (no grep -q to avoid SIGPIPE with pipefail)
  if command_exists ss; then
    ss -tlnp 2>/dev/null | grep ":${port}" > /dev/null
  elif command_exists lsof; then
    # -sTCP:LISTEN filters out ESTABLISHED/TIME_WAIT false positives
    lsof -nP -iTCP:"${port}" -sTCP:LISTEN &>/dev/null
  elif command_exists nc; then
    nc -z 127.0.0.1 "${port}" &>/dev/null
  elif [[ "$BASH_VERSION" ]]; then
    # Bash built-in /dev/tcp
    (echo >/dev/tcp/127.0.0.1/"${port}") 2>/dev/null
  else
    return 1
  fi
}

start_ollama_server() {
  curl -sf --max-time 10 "${OLLAMA_API_URL}/api/version" &> /dev/null && {
    log_success "${MSG_SERVER_ALREADY}"; return 0
  }

  # Port might be in use by starting server - delegate to wait_for_ollama (30s)
  if port_in_use 11434; then
    log_info "${MSG_PORT_BUSY}"
    wait_for_ollama && return 0
    log_warning "${MSG_PORT_BUSY_WARN}"
    log_info "${MSG_PORT_CHECK_HINT_SS}"
    return 1
  fi

  # Try systemd first (preferred) - check system service (official installer) then user service
  if command_exists systemctl; then
    # System service (created by official curl | sh installer)
    if systemctl is-active --quiet ollama 2>/dev/null; then
      # Service active but API not responding (already checked above) - wait for it
      log_info "${MSG_SYSTEMD_SYSTEM_ACTIVE}"
      wait_for_ollama && return 0
    fi
    if systemctl list-unit-files ollama.service 2>/dev/null | grep 'ollama.service' > /dev/null; then
      log_info "${MSG_SYSTEMD_SYSTEM_START}"
      # sudo only if available without password (non-interactive safe)
      if sudo -n true 2>/dev/null; then
        sudo systemctl start ollama 2>/dev/null || true
      else
        systemctl start ollama 2>/dev/null || true
      fi
      spinner_start "${MSG_WAIT_SERVER}"
      sleep 2
      spinner_stop
      curl -sf --max-time 10 "${OLLAMA_API_URL}/api/version" &> /dev/null && {
        log_success "${MSG_SYSTEMD_STARTED}"; return 0
      }
    fi
    # User service (manual setup)
    if systemctl --user list-unit-files ollama.service 2>/dev/null | grep 'ollama.service' > /dev/null; then
      log_info "${MSG_SYSTEMD_USER_START}"
      systemctl --user start ollama 2>/dev/null || true
      spinner_start "${MSG_WAIT_SERVER}"
      sleep 2
      spinner_stop
      curl -sf --max-time 10 "${OLLAMA_API_URL}/api/version" &> /dev/null && {
        log_success "${MSG_SYSTEMD_STARTED}"; return 0
      }
    fi
  fi

  # Fallback: nohup background process
  if command_exists ollama; then
    log_info "${MSG_NOHUP_START}"
    local log_file="${XDG_RUNTIME_DIR:-/tmp}/ollama-server-${UID}.log"
    install -m 600 /dev/null "$log_file" 2>/dev/null || true
    nohup ollama serve &>"$log_file" &
    local ollama_pid=$!
    spinner_start "${MSG_WAIT_SERVER}"
    sleep 2
    spinner_stop

    if kill -0 "$ollama_pid" 2>/dev/null; then
      log_success "$(msg "${MSG_SERVER_STARTED_PID}" "${ollama_pid}")"
      return 0
    fi
    log_warning "$(msg "${MSG_PROCESS_FAILED}" "${log_file}")"
    return 1
  fi

  return 1
}

# Detects Ollama in non-standard locations and extends PATH if found
detect_ollama_installation() {
  command_exists ollama && return 0

  # Check common Linux installation paths
  local paths=(
    "/usr/local/bin/ollama"
    "/usr/bin/ollama"
    "${HOME}/.local/bin/ollama"
    "/snap/bin/ollama"
  )
  local p
  for p in "${paths[@]}"; do
    if [[ -x "$p" ]]; then
      log_info "$(msg "$MSG_OLLAMA_FOUND" "$p")"
      export PATH="${p%/*}:${PATH}"
      return 0
    fi
  done

  return 1
}

install_ollama() {
  log_step "${MSG_INSTALLING_OLLAMA}"

  # Try to detect Ollama even if not in standard PATH
  detect_ollama_installation || true

  if command_exists ollama; then
    log_success "${MSG_OLLAMA_ALREADY}"
    local version
    version=$(ollama --version 2>/dev/null | head -1 || echo "unknown")
    log_info "$(msg "$MSG_OLLAMA_VERSION" "$version")"
    check_ollama_version || true

    if ! curl -sf --max-time 10 "${OLLAMA_API_URL}/api/version" &> /dev/null; then
      log_info "${MSG_CHECKING_SERVER}"
      if ! start_ollama_server; then
        log_error "${MSG_SERVER_START_FAILED}"
        log_info "${MSG_SERVER_START_HINT}"
        exit 1
      fi
      wait_for_ollama || exit 1
    else
      log_success "${MSG_SERVER_RUNNING}"
    fi
    return 0
  fi

  log_info "${MSG_DOWNLOADING_INSTALLER}"
  local install_script
  install_script=$(mktemp "${TMPDIR:-/tmp}/hablara-ollama-install.XXXXXX")
  if ! curl -fsSL --max-time 120 "${OLLAMA_INSTALL_URL}" -o "$install_script"; then
    rm -f "$install_script"
    log_error "${MSG_INSTALLER_DOWNLOAD_FAILED}"
    log_info "${MSG_MANUAL_INSTALL}"
    exit 1
  fi
  chmod +x "$install_script"
  log_info "${MSG_RUNNING_INSTALLER}"
  local install_result=0
  run_with_timeout 300 sh "$install_script" || install_result=$?
  rm -f "$install_script"
  if [[ $install_result -eq 124 ]]; then
    log_error "${MSG_INSTALLER_TIMEOUT}"
    log_info "${MSG_MANUAL_INSTALL}"
    exit 1
  elif [[ $install_result -ne 0 ]]; then
    log_error "${MSG_INSTALL_FAILED}"
    log_info "${MSG_MANUAL_INSTALL}"
    exit 1
  fi
  log_success "${MSG_OLLAMA_INSTALLED}"

  # Verify ollama CLI is now accessible
  if ! command_exists ollama; then
    log_error "${MSG_OLLAMA_PATH_ERROR}"
    log_info "${MSG_PATH_HINT}"
    exit 1
  fi

  start_ollama_server || log_warning "${MSG_SERVER_START_WARN}"
  wait_for_ollama || exit 1
}

# ============================================================================
# Model Management
# ============================================================================

pull_base_model() {
  log_step "${MSG_DOWNLOADING_BASE}"

  if ollama_model_exists "${MODEL_NAME}"; then
    log_success "$(msg "$MSG_MODEL_EXISTS" "$MODEL_NAME")"
    return 0
  fi

  log_info "$(msg "$MSG_DOWNLOADING_MODEL" "$MODEL_NAME" "$MODEL_SIZE")"
  log_info "${MSG_DOWNLOAD_RESUME_TIP}"

  # Hard timeout per attempt: 20 min for all models
  local pull_timeout=1200

  local pull_success=false
  for attempt in 1 2 3; do
    local result=0
    _pull_with_heartbeat "${MODEL_NAME}" "$pull_timeout" || result=$?
    if [[ $result -eq 0 ]]; then
      pull_success=true
      break
    fi
    if [[ $result -eq 124 ]]; then
      log_warning "$(msg "$MSG_DOWNLOAD_TIMEOUT_WARN" "$(( pull_timeout / 60 ))" "$attempt")"
    else
      log_warning "$(msg "$MSG_DOWNLOAD_FAILED_WARN" "$attempt")"
    fi
    if [[ $attempt -lt 3 ]]; then
      log_info "${MSG_DOWNLOAD_RETRY}"
      sleep 5
    fi
  done

  if ! $pull_success; then
    log_error "${MSG_DOWNLOAD_FAILED}"
    log_info "$(msg "$MSG_DOWNLOAD_MANUAL" "$MODEL_NAME")"
    exit 1
  fi
  log_success "$(msg "$MSG_DOWNLOAD_DONE" "$MODEL_NAME")"
  return 0
}

# Subshell function: isolates EXIT trap for temp file cleanup (no RETURN trap leak)
create_custom_model() (
  set -euo pipefail
  log_step "${MSG_CREATING_CUSTOM}"

  local action_verb="${MSG_VERB_CREATED}"

  if ollama_model_exists "${CUSTOM_MODEL_NAME}"; then
    # FORCE_UPDATE from parent scope (subshell copy; changes don't propagate back)
    if [[ "$FORCE_UPDATE" == "true" ]]; then
      log_info "${MSG_UPDATING_CUSTOM}"
      action_verb="${MSG_VERB_UPDATED}"
    elif exec 3<>/dev/tty; then
      # Interaktiv: Menü über FD3 (TTY), damit stderr-Redirect den Prompt nicht versteckt
      printf "\n" >&3
      printf "${MSG_CUSTOM_EXISTS}\n" "${CUSTOM_MODEL_NAME}" >&3
      printf "\n" >&3
      printf "  1) ${MSG_CUSTOM_SKIP}\n" >&3
      printf "  2) ${MSG_CUSTOM_UPDATE_OPT}\n" >&3
      printf "\n" >&3
      printf "${MSG_CUSTOM_UPDATE_PROMPT}: " >&3
      local update_choice
      IFS= read -r -t 30 update_choice <&3 || update_choice=""
      exec 3>&- 3<&-
      if [[ "$update_choice" != "2" ]]; then
        log_success "${MSG_CUSTOM_KEPT}"
        return 0
      fi
      log_info "${MSG_UPDATING_CUSTOM}"
      action_verb="${MSG_VERB_UPDATED}"
    else
      # Kein nutzbares TTY → wie non-interaktiv behandeln (Skip)
      log_success "${MSG_CUSTOM_PRESENT}"
      return 0
    fi
  fi

  # Dynamic modelfile path based on selected model variant (e.g. qwen2.5:7b → qwen2.5-7b-custom.modelfile)
  local script_dir="" external_modelfile=""
  if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || script_dir=""
  fi
  local modelfile_name="${MODEL_NAME/:/-}-custom.modelfile"
  [[ -n "$script_dir" && -f "${script_dir}/ollama/${modelfile_name}" ]] && \
    external_modelfile="${script_dir}/ollama/${modelfile_name}"

  local modelfile
  modelfile=$(mktemp "${TMPDIR:-/tmp}/hablara-modelfile.XXXXXX")
  chmod 600 "$modelfile"
  # Cleanup on subshell exit (EXIT trap is subshell-scoped, no leak to parent)
  trap 'rm -f -- "$modelfile"' EXIT

  if [[ -n "$external_modelfile" ]]; then
    log_info "${MSG_USING_HABLARA_CONFIG}"
    cp "$external_modelfile" "$modelfile"
  else
    log_info "${MSG_USING_DEFAULT_CONFIG}"
    # KEIN SYSTEM-Prompt: Ollama 0.18.0 Constrained-Decoding-Bug bei qwen3-Modellen —
    # SYSTEM + format:"json" korrumpiert JSON-Output (Token-Alignment-Verschiebung).
    # Alle Instruktionen kommen via Per-Request-Prompts.
    # Referenz: docs/reference/benchmarks/JSON_DE.md
    cat > "${modelfile}" <<EOF
FROM ${MODEL_NAME}

PARAMETER num_ctx 8192
PARAMETER temperature 0.3
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
EOF
  fi

  local create_result=0
  spinner_start "$(msg "$MSG_CUSTOM_CREATING" "$CUSTOM_MODEL_NAME")"
  run_with_timeout 120 ollama create "${CUSTOM_MODEL_NAME}" -f "${modelfile}" || create_result=$?
  spinner_stop

  if [[ $create_result -eq 124 ]]; then
    log_warning "${MSG_CUSTOM_CREATE_TIMEOUT}"
    return 0
  fi
  if [[ $create_result -ne 0 ]]; then
    log_warning "$(msg "$MSG_CUSTOM_CREATE_FAILED" "$action_verb")"
    return 0
  fi

  log_success "$(msg "$MSG_CUSTOM_DONE" "$action_verb" "$CUSTOM_MODEL_NAME")"
  return 0
)

# ============================================================================
# Verification
# ============================================================================

verify_installation() {
  echo ""
  log_step "${MSG_VERIFYING}"

  command_exists ollama || { log_error "${MSG_OLLAMA_NOT_FOUND}"; return 1; }
  curl -sf --max-time 10 "${OLLAMA_API_URL}/api/version" &> /dev/null || {
    log_error "${MSG_SERVER_UNREACHABLE}"
    return 1
  }

  ollama_model_exists "${MODEL_NAME}" || {
    log_error "$(msg "$MSG_BASE_NOT_FOUND" "$MODEL_NAME")"; return 1
  }
  log_success "$(msg "$MSG_BASE_OK" "$MODEL_NAME")"

  local test_model="$MODEL_NAME"
  if ollama_model_exists "${CUSTOM_MODEL_NAME}"; then
    log_success "$(msg "$MSG_CUSTOM_OK" "$CUSTOM_MODEL_NAME")"
    test_model="$CUSTOM_MODEL_NAME"
  else
    log_warning "${MSG_CUSTOM_UNAVAILABLE}"
  fi

  test_model_inference "$test_model" || log_warning "${MSG_INFERENCE_FAILED}"

  show_benchmark_result "$test_model"

  echo ""
  log_success "${MSG_SETUP_DONE}"
  return 0
}

# ============================================================================
# Main
# ============================================================================

main() {
  parse_lang_flag "$@"
  select_language
  setup_messages
  select_model "$@"
  preflight_checks
  install_ollama
  pull_base_model
  create_custom_model
  verify_installation || exit 1

  echo ""
  echo -e "${COLOR_GREEN}========================================${COLOR_RESET}"
  echo -e "${COLOR_GREEN}  ${MSG_SETUP_COMPLETE}${COLOR_RESET}"
  echo -e "${COLOR_GREEN}========================================${COLOR_RESET}"
  echo ""

  local final_model="${MODEL_NAME}"
  ollama_model_exists "${CUSTOM_MODEL_NAME}" && final_model="${CUSTOM_MODEL_NAME}"

  echo "${MSG_INSTALLED}"
  echo "${MSG_BASE_MODEL_LABEL}${MODEL_NAME}"
  if ollama_model_exists "${CUSTOM_MODEL_NAME}"; then
    echo "${MSG_HABLARA_MODEL_LABEL}${CUSTOM_MODEL_NAME}"
  fi
  echo ""
  echo -e "${COLOR_BLUE}${MSG_OLLAMA_CONFIG}${COLOR_RESET}"
  echo "${MSG_MODEL_LABEL}${final_model}"
  echo "${MSG_BASE_URL_LABEL}http://localhost:11434"
  echo ""
  if command_exists systemctl; then
    echo "${MSG_SERVICE_MANAGEMENT}"
    echo "  systemctl {status|start|stop} ollama"
    echo ""
  fi
  echo -e "${COLOR_CYAN}${MSG_DOCS}${COLOR_RESET}"
  echo ""
  return 0
}

main "$@"
