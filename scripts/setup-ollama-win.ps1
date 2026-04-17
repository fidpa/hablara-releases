#Requires -Version 5.1
# AUTO-GENERATED — Do not edit. Edit scripts/i18n/ then run: pnpm run build:setup-scripts
<#
.SYNOPSIS
    Hablará - Ollama Setup Script (Windows)

.DESCRIPTION
    Installs Ollama and configures an optimized model for Hablará.

.EXAMPLE
    .\setup-ollama-win.ps1
    .\setup-ollama-win.ps1 -Model 3b
    .\setup-ollama-win.ps1 -Update
    .\setup-ollama-win.ps1 -Status
    .\setup-ollama-win.ps1 -Diagnose
    .\setup-ollama-win.ps1 -Cleanup

.NOTES
    Exit Codes: 0=Success, 1=Error, 2=Disk space, 3=Network, 4=Platform
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('1.5b', '3b', '7b', 'qwen3-8b')]
    [string]$Model,

    [switch]$Update,

    [switch]$Status,

    [switch]$Diagnose,

    [switch]$Cleanup,

    [switch]$Help,

    [ValidateSet('da', 'de', 'en', 'es', 'fr', 'it', 'nl', 'pt', 'pl', 'sv', 'DA', 'DE', 'EN', 'ES', 'FR', 'IT', 'NL', 'PT', 'PL', 'SV')]
    [string]$Lang
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# TLS 1.2 for PS 5.1 (ollama.com network check requires TLS 1.2+)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Pre-initialize $script:Msg so trap can use it before Initialize-Messages is called
$script:Msg = @{ ErrorPrefix = 'Fehler'; SetupFailed = 'Setup fehlgeschlagen' }

trap {
    if (-not $Status -and -not $Diagnose -and -not $Cleanup) {
        Write-Host "$([char]0x2717) $($script:Msg.ErrorPrefix): $($script:Msg.SetupFailed): $_" -ForegroundColor Red
    }
    exit 1
}

# ============================================================================
# Configuration
# ============================================================================

$ScriptVersion = '1.7.2'
$OllamaApiUrl = 'http://localhost:11434'
$MinOllamaVersion = '0.3.0'

$script:ModelName = ''
$script:CustomModelName = ''
$script:ModelSize = ''
$script:RequiredDiskSpaceGB = 0
# Set-StrictMode erfordert Vorinitialisierung. Show-HardwareRecommendation
# wird übersprungen wenn Get-MemoryBandwidthGbps 0 zurückgibt (unbekannter
# Prozessor) → Show-ModelMenu/Get-PromptText würden sonst auf eine
# nicht-gesetzte Variable zugreifen und strict-mode failen.
$script:RecommendedModel = ''

$ModelConfigs = @{
    '1.5b'    = @{ Name = 'qwen2.5:1.5b'; Size = '~1GB';   DiskGB = 3;  RAMWarn = $false; MinRAM = 0 }
    '3b'      = @{ Name = 'qwen2.5:3b';   Size = '~2GB';   DiskGB = 5;  RAMWarn = $false; MinRAM = 0 }
    '7b'      = @{ Name = 'qwen2.5:7b';   Size = '~4.7GB'; DiskGB = 10; RAMWarn = $false; MinRAM = 0 }
    'qwen3-8b' = @{ Name = 'qwen3:8b';   Size = '~5.2GB'; DiskGB = 8;  RAMWarn = $false; MinRAM = 0 }
}
$DefaultModel = '3b'

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Step { param([string]$Message); Write-Host "`n==> " -ForegroundColor Blue -NoNewline; Write-Host $Message -ForegroundColor Green }
function Write-Info { param([string]$Message); Write-Host "    $([char]0x2022) " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
function Write-Success { param([string]$Message); Write-Host "    $([char]0x2713) " -ForegroundColor Green -NoNewline; Write-Host $Message }
function Write-Warning { param([string]$Message); Write-Host "    $([char]0x26A0) " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
function Write-Err { param([string]$Message); Write-Host "$([char]0x2717) $($script:Msg.ErrorPrefix): $Message" -ForegroundColor Red }

# ============================================================================
# Language Selection
# ============================================================================

function Get-SystemLanguage {
    try {
        $culture = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName
        if ($culture -eq 'en') { return 'en' }
        if ($culture -eq 'es') { return 'es' }
        if ($culture -eq 'fr') { return 'fr' }
        if ($culture -eq 'it') { return 'it' }
        if ($culture -eq 'nl') { return 'nl' }
        if ($culture -eq 'pt') { return 'pt' }
        if ($culture -eq 'pl') { return 'pl' }
        if ($culture -eq 'sv') { return 'sv' }
        if ($culture -eq 'da') { return 'da' }
    } catch {}
    return 'de'
}

function Select-Language {
    # --Lang flag takes precedence
    if (-not [string]::IsNullOrEmpty($Lang)) { return $Lang.ToLower() }

    # Non-interactive: fall back to system locale
    if (-not (Test-InteractiveSession)) { return (Get-SystemLanguage) }

    Write-Host ""
    Write-Host "  1) Deutsch"
    Write-Host "  2) English"
    Write-Host "  3) Español"
    Write-Host "  4) Français"
    Write-Host "  5) Italiano"
    Write-Host "  6) Nederlands"
    Write-Host "  7) Português"
    Write-Host "  8) Polski"
    Write-Host "  9) Svenska"
    Write-Host " 10) Dansk"
    Write-Host ""
    $choice = Read-Host "Sprache / Language / Idioma / Langue / Lingua / Taal / Idioma / Język / Sprog [1-10, Enter=1]"
    if ($choice -eq '2')  { return 'en' }
    if ($choice -eq '3')  { return 'es' }
    if ($choice -eq '4')  { return 'fr' }
    if ($choice -eq '5')  { return 'it' }
    if ($choice -eq '6')  { return 'nl' }
    if ($choice -eq '7')  { return 'pt' }
    if ($choice -eq '8')  { return 'pl' }
    if ($choice -eq '9')  { return 'sv' }
    if ($choice -eq '10') { return 'da' }
    return 'de'
}

function Initialize-Messages {
    param([string]$LangCode)
    $script:Msg = @{}
    switch ($LangCode) {
        'en' {
            $script:Msg.ErrorPrefix        = 'Error'
            # Model Menu
            $script:Msg.ChooseModel        = 'Choose a model:'
            $script:Msg.ChoicePrompt       = 'Choice [1-4, Enter=1]'
            $script:Msg.Model3B            = 'Optimal overall performance [Default]'
            $script:Msg.Model1_5B          = 'Fast, limited accuracy [Entry-level]'
            $script:Msg.Model7B            = 'Requires high-performance hardware'
            $script:Msg.ModelQwen3         = 'Best argumentation analysis [Premium]'
            # Main Menu
            $script:Msg.ChooseAction       = 'Choose an action:'
            $script:Msg.ActionSetup        = 'Set up or update Ollama'
            $script:Msg.ActionStatus       = 'Check status'
            $script:Msg.ActionDiagnose     = 'Diagnostics (support report)'
            $script:Msg.ActionCleanup      = 'Clean up models'
            $script:Msg.ActionPrompt       = 'Choice [1-4, Enter=1]'
            # Select Model
            $script:Msg.InvalidModel       = 'Invalid model variant: {0}'
            $script:Msg.ValidVariants      = 'Valid variants: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b'
            $script:Msg.RamWarnModel       = 'This model recommends at least {0}GB RAM'
            $script:Msg.RamWarnSys         = 'Your system has {0}GB RAM'
            $script:Msg.ContinueAnyway     = 'Continue anyway?'
            $script:Msg.ConfirmPrompt      = '[y/N]'
            $script:Msg.ConfirmPattern     = '^[yY]$'
            $script:Msg.Aborted            = 'Aborted.'
            $script:Msg.SelectedModel      = 'Selected model: {0}'
            $script:Msg.ProceedNonInteract = 'Proceeding...'
            $script:Msg.InternalError      = 'Internal error: ModelName not set'
            # Preflight
            $script:Msg.Preflight          = 'Running pre-checks...'
            $script:Msg.PlatformError      = 'This script is for Windows only'
            $script:Msg.PlatformMacHint    = 'For macOS: scripts/setup-ollama-mac.sh'
            $script:Msg.PlatformLinuxHint  = 'For Linux: scripts/setup-ollama-linux.sh'
            $script:Msg.DiskInsufficient   = 'Not enough space: {0}GB available, {1}GB required'
            $script:Msg.DiskOk             = 'Disk space: {0}GB available'
            $script:Msg.NetworkError       = 'No network connection to ollama.com'
            $script:Msg.NetworkHint        = 'Check: Invoke-WebRequest -Uri https://ollama.com'
            $script:Msg.NetworkOk          = 'Network connection OK'
            $script:Msg.GpuDetected        = 'GPU detected: {0}'
            $script:Msg.GpuNone            = 'No GPU detected - processing without GPU acceleration'
            # Status
            $script:Msg.StatusTitle        = 'Hablará Ollama Status (Windows)'
            $script:Msg.StatusInstalled    = 'Ollama installed (v{0})'
            $script:Msg.StatusUpdateRec    = '    {0} Update recommended (minimum v{1}): winget upgrade Ollama.Ollama'
            $script:Msg.StatusNotFound     = 'Ollama not found'
            $script:Msg.StatusServerOk     = 'Server running'
            $script:Msg.StatusServerFail   = 'Server not reachable'
            $script:Msg.StatusGpuNvidia    = 'NVIDIA (CUDA acceleration)'
            $script:Msg.StatusGpuAmd       = 'AMD (ROCm acceleration, experimental)'
            $script:Msg.StatusNoGpu        = 'No GPU — processing without GPU acceleration'
            $script:Msg.StatusBaseModel    = 'Base model: {0}'
            $script:Msg.StatusBaseModels   = 'Base models:'
            $script:Msg.StatusNoBase       = 'No base model found'
            $script:Msg.StatusHablaraModel = 'Hablará model: {0}'
            $script:Msg.StatusHablaraModels= 'Hablará models:'
            $script:Msg.StatusNoHablara    = 'No Hablará model found'
            $script:Msg.StatusBaseMissing  = '    {0} Base model missing — Hablará model requires it as a foundation'
            $script:Msg.StatusInfSkip      = 'Model test skipped (server not reachable)'
            $script:Msg.StatusModelOk      = 'Model responding'
            $script:Msg.StatusModelFail    = 'Model not responding'
            $script:Msg.StatusStorage      = 'Storage usage (Hablará): ~{0} GB'
            $script:Msg.StatusStorageUnk   = 'Storage usage: not determinable'
            $script:Msg.StatusAllOk        = 'Everything is fine.'
            $script:Msg.StatusProblems     = '{0} problem(s) found.'
            $script:Msg.StatusRepair       = '    Repair: .\setup-ollama-win.ps1'
            # Diagnose
            $script:Msg.DiagnoseTitle      = '=== Hablará Ollama Diagnostics Report ==='
            $script:Msg.DiagnoseSystem     = 'System:'
            $script:Msg.DiagnoseOllama     = 'Ollama:'
            $script:Msg.DiagnoseModels     = 'Hablará Models:'
            $script:Msg.DiagnoseStorage    = 'Storage (Hablará):'
            $script:Msg.DiagnoseLog        = 'Ollama Log (recent errors):'
            $script:Msg.DiagnoseCreated    = 'Created:'
            $script:Msg.DiagnoseScript     = 'Script:'
            $script:Msg.DiagnoseSaved      = 'Report saved: {0}'
            $script:Msg.DiagnoseSaveFailed = 'Could not save report'
            $script:Msg.DiagnoseRamAvail   = 'available'
            $script:Msg.DiagnoseStorFree   = 'free'
            $script:Msg.DiagnoseStorDisk   = 'Storage:'
            $script:Msg.DiagnoseUnknown    = 'unknown'
            $script:Msg.DiagnoseNotInst    = 'not installed'
            $script:Msg.DiagnoseNotReach   = 'not reachable'
            $script:Msg.DiagnoseRunning    = 'running'
            $script:Msg.DiagnoseNoModels   = '    [no Hablará models found]'
            $script:Msg.DiagnoseNoErrors   = '    [no errors found]'
            $script:Msg.DiagnoseNoLog      = '    [log file not found: {0}]'
            $script:Msg.DiagnoseLogUnread  = '    [log file not readable: {0}]'
            $script:Msg.DiagnoseGpuNone    = 'None'
            $script:Msg.DiagnoseResponds   = '(responding)'
            # Install
            $script:Msg.Installing         = 'Installing Ollama...'
            $script:Msg.OllamaAlready      = 'Ollama already installed'
            $script:Msg.OllamaVersion      = 'Version: {0}'
            $script:Msg.ServerStartFailed  = 'Could not start Ollama server'
            $script:Msg.ServerStartHint    = 'Start manually: ollama serve'
            $script:Msg.UsingWinget        = 'Using winget (timeout: 10 minutes)...'
            $script:Msg.WingetTimeout      = 'winget install timeout after 10 minutes'
            $script:Msg.WingetFailed       = 'winget installation failed: {0}'
            $script:Msg.OllamaInstalled    = 'Ollama installed via winget'
            $script:Msg.WaitForAutoStart   = 'Waiting for Ollama app auto-start...'
            $script:Msg.RebootRequired     = 'A computer restart may be required'
            $script:Msg.OllamaPathError    = 'Ollama installed but CLI not in PATH. Open a new terminal or check PATH.'
            $script:Msg.ServerStartWarn    = 'Server start failed - start manually: ollama serve'
            $script:Msg.ManualInstall      = 'Please install Ollama manually: https://ollama.com/download'
            $script:Msg.ManualRerun        = 'Then run this script again.'
            $script:Msg.OllamaFound        = 'Ollama found: {0}'
            $script:Msg.OllamaAppStart     = 'Starting Ollama App...'
            $script:Msg.OllamaServeStart   = 'Starting Ollama server (ollama serve)...'
            $script:Msg.OllamaProcessExit  = 'Ollama process exited (code: {0})'
            $script:Msg.PortBusy           = 'Port 11434 is busy, waiting for Ollama API...'
            $script:Msg.PortBusyWarn       = 'Port 11434 busy but Ollama API not responding'
            $script:Msg.VersionWarn        = 'Ollama version {0} is older than recommended ({1})'
            $script:Msg.UpdateHint         = 'Update: winget upgrade Ollama.Ollama'
            # Model Download
            $script:Msg.DownloadingBase    = 'Downloading base model...'
            $script:Msg.ModelExists        = 'Model already present: {0}'
            $script:Msg.DownloadingModel   = 'Downloading {0} ({1}, takes several minutes depending on connection)...'
            $script:Msg.DownloadResumeTip  = 'Tip: If interrupted (Ctrl+C), restarting continues the download'
            $script:Msg.DownloadHardTimeout= 'Hard timeout after {0} minutes — aborting'
            $script:Msg.DownloadStall      = 'No download progress for {0} minutes — aborting'
            $script:Msg.DownloadRunning    = '  Download running... ({0}m {1}s)'
            $script:Msg.DownloadTimeoutW   = 'Download timeout after {0} minutes (attempt {1}/3)'
            $script:Msg.DownloadFailedW    = 'Download failed (attempt {0}/3)'
            $script:Msg.DownloadRetry      = 'Next attempt in 5s...'
            $script:Msg.DownloadFailed     = 'Model download failed after 3 attempts'
            $script:Msg.DownloadManual     = 'Try manually: ollama pull {0}'
            $script:Msg.DownloadDone       = 'Model downloaded: {0}'
            # Custom Model
            $script:Msg.CreatingCustom     = 'Creating Hablará model...'
            $script:Msg.UpdatingCustom     = 'Updating existing Hablará model...'
            $script:Msg.CustomExists       = 'Hablará model {0} already present.'
            $script:Msg.CustomSkip         = 'Skip (no changes)'
            $script:Msg.CustomUpdateOpt    = 'Update Hablará model'
            $script:Msg.CustomUpdatePrompt = 'Choice [1-2, Enter=1]'
            $script:Msg.CustomKept         = 'Hablará model kept'
            $script:Msg.CustomPresent      = 'Hablará model already present'
            $script:Msg.UsingHablaraConf   = 'Using Hablará configuration'
            $script:Msg.UsingDefaultConf   = 'Using default configuration'
            $script:Msg.ConfigReadError    = 'Could not read configuration: {0}'
            $script:Msg.CustomCreating      = 'Creating Hablará model {0}...'
            $script:Msg.CustomCreateTO     = 'ollama create timeout after 120s — using base model'
            $script:Msg.CustomCreateFail   = 'Hablará model could not be {0} - using base model'
            $script:Msg.CustomDone         = 'Hablará model {0}: {1}'
            $script:Msg.ConfigError        = 'Configuration error'
            $script:Msg.PermsWarn          = 'Could not set restrictive permissions: {0}'
            $script:Msg.VerbCreated        = 'created'
            $script:Msg.VerbUpdated        = 'updated'
            # Verify
            $script:Msg.Verifying          = 'Verifying installation...'
            $script:Msg.OllamaNotFound     = 'Ollama not found'
            $script:Msg.ServerUnreachable  = 'Ollama server not reachable'
            $script:Msg.BaseNotFound       = 'Base model not found: {0}'
            $script:Msg.BaseOk             = 'Base model available: {0}'
            $script:Msg.CustomOk           = 'Hablará model available: {0}'
            $script:Msg.CustomUnavail      = 'Hablará model unavailable (using base model)'
            $script:Msg.InferenceFailed    = 'Model test failed, test in the app'
            $script:Msg.SetupDone          = 'Setup complete!'
            # Main Summary
            $script:Msg.SetupComplete      = 'Hablará Ollama Setup complete!'
            $script:Msg.Installed          = 'Installed:'
            $script:Msg.BaseModelLabel     = '  Base model:    '
            $script:Msg.HablaraModelLabel  = '  Hablará model: '
            $script:Msg.OllamaConfig       = 'Ollama configuration:'
            $script:Msg.ModelLabel         = '  Model:    '
            $script:Msg.BaseUrlLabel       = '  Base URL: '
            $script:Msg.Docs               = 'Documentation: https://github.com/fidpa/hablara'
            # Misc
            $script:Msg.TestModel          = 'Testing model...'
            $script:Msg.TestOk             = 'Model test successful'
            $script:Msg.TestFail           = 'Model test failed'
            $script:Msg.WaitServer         = 'Waiting for Ollama server...'
            $script:Msg.ServerReady        = 'Ollama server is ready'
            $script:Msg.ServerAlready      = 'Ollama server is already running'
            $script:Msg.ServerNoResponse   = 'Ollama server not responding after {0}s'
            $script:Msg.SetupFailed        = 'Setup failed'
            $script:Msg.OllamaListTimeout  = 'ollama list timeout (15s) during model check'
            # Cleanup
            $script:Msg.CleanupNeedsTTY    = '-Cleanup requires an interactive session'
            $script:Msg.CleanupNoOllama    = 'Ollama not found'
            $script:Msg.CleanupNoServer    = 'Ollama server not reachable'
            $script:Msg.CleanupStartHint   = 'Start Ollama and try again'
            $script:Msg.CleanupInstalled   = 'Installed Hablará variants:'
            $script:Msg.CleanupPrompt      = 'Which variant to delete? (number, Enter=cancel)'
            $script:Msg.CleanupInvalid     = 'Invalid selection'
            $script:Msg.CleanupDeleted     = '{0} deleted'
            $script:Msg.CleanupTimeout     = '{0} could not be deleted: Timeout (30s)'
            $script:Msg.CleanupFailed      = '{0} could not be deleted: {1}'
            $script:Msg.CleanupUnknownErr  = 'unknown error'
            $script:Msg.CleanupNoneLeft    = 'No Hablará models installed anymore. Run setup again to install a model.'
            $script:Msg.CleanupNoModels    = 'No Hablará models found.'
            # Help
            $script:Msg.HelpTitle          = 'Hablará Ollama Setup v{0} (Windows)'
            $script:Msg.HelpDescription    = '  Installs Ollama and configures an optimized Hablará model.'
            $script:Msg.HelpUsage          = 'Usage:'
            $script:Msg.HelpUsageLine      = '  .\setup-ollama-win.ps1 [OPTIONS]'
            $script:Msg.HelpOptions        = 'Options:'
            $script:Msg.HelpOptModel       = '  -Model VARIANT        Choose model variant: 1.5b, 3b, 7b, qwen3-8b (default: 3b)'
            $script:Msg.HelpOptUpdate      = '  -Update               Recreate Hablará custom model (update Modelfile)'
            $script:Msg.HelpOptStatus      = '  -Status               Health check: 7-point Ollama installation check'
            $script:Msg.HelpOptDiagnose    = '  -Diagnose             Generate support report (plain text, copyable)'
            $script:Msg.HelpOptCleanup     = '  -Cleanup              Interactively delete installed variant'
            $script:Msg.HelpOptLang        = '  -Lang da|de|en|es|fr|it|nl|pl|pt|sv  Language (da=Danish, de=German, en=English, es=Spanish, fr=French, it=Italian, nl=Dutch, pl=Polish, pt=Portuguese, sv=Swedish)'
            $script:Msg.HelpOptHelp        = '  -Help                 Show this help'
            $script:Msg.HelpNoOpts         = '  Without options, an interactive menu starts.'
            $script:Msg.HelpVariants       = 'Model variants:'
            $script:Msg.HelpExamples       = 'Examples:'
            $script:Msg.HelpExModel        = '  .\setup-ollama-win.ps1 -Model 3b       Install 3b variant'
            $script:Msg.HelpExUpdate       = '  .\setup-ollama-win.ps1 -Update         Update custom model'
            $script:Msg.HelpExStatus       = '  .\setup-ollama-win.ps1 -Status         Check installation'
            $script:Msg.HelpExDiagnose     = '  .\setup-ollama-win.ps1 -Diagnose       Create bug report'
            $script:Msg.HelpExCleanup      = '  .\setup-ollama-win.ps1 -Cleanup        Remove variant'
            $script:Msg.HelpExitCodes      = 'Exit Codes:'
            $script:Msg.HelpExit0          = '  0  Success'
            $script:Msg.HelpExit1          = '  1  General error'
            $script:Msg.HelpExit2          = '  2  Not enough disk space'
            $script:Msg.HelpExit3          = '  3  No network connection'
            $script:Msg.HelpExit4          = '  4  Wrong platform'
            $script:Msg.AutoInstallFailed  = 'Ollama could not be installed automatically'
            # Hardware Detection
            $script:Msg.HwDetectionHeader  = 'Hardware detection:'
            $script:Msg.HwBandwidth        = 'Memory bandwidth: ~{0} GB/s · {1} GB RAM'
            $script:Msg.HwRecommendation   = 'Model recommendation for your hardware:'
            $script:Msg.HwLocalTooSlow     = 'Local models will be slow on this hardware'
            $script:Msg.HwCloudHint        = 'Recommendation: OpenAI or Anthropic API for best experience'
            $script:Msg.HwProceedLocal     = 'Install locally anyway? [y/N]'
            $script:Msg.HwTagRecommended   = 'recommended'
            $script:Msg.HwTagSlow          = 'slow'
            $script:Msg.HwTagTooSlow       = 'too slow'
            $script:Msg.ChoicePromptHw     = 'Choice [1-4, Enter={0}]'
            $script:Msg.HwUnknownChip      = 'Unknown processor — no bandwidth recommendation available'
            $script:Msg.HwMultiCallHint   = 'Hablará runs multiple analysis steps per recording'
            # Benchmark
            $script:Msg.BenchResult        = 'Benchmark: ~{0} tok/s with {1}'
            $script:Msg.BenchExcellent     = 'Excellent — your hardware handles this model with ease'
            $script:Msg.BenchGood          = 'Good — this model runs well on your hardware'
            $script:Msg.BenchMarginal      = 'Marginal — consider a smaller model for smoother experience'
            $script:Msg.BenchTooSlow       = 'Too slow — a smaller model or cloud provider is recommended'
            $script:Msg.BenchSkip          = 'Benchmark skipped (measurement failed)'
        }
        'es' {
            $script:Msg.ErrorPrefix        = 'Error'
            # Model Menu
            $script:Msg.ChooseModel        = 'Elige un modelo:'
            $script:Msg.ChoicePrompt       = 'Selección [1-4, Enter=1]'
            $script:Msg.Model3B            = 'Rendimiento general óptimo [Por defecto]'
            $script:Msg.Model1_5B          = 'Rápido, precisión limitada [Básico]'
            $script:Msg.Model7B            = 'Requiere hardware de alto rendimiento'
            $script:Msg.ModelQwen3         = 'Mejor análisis de argumentación [Premium]'
            # Main Menu
            $script:Msg.ChooseAction       = 'Elige una acción:'
            $script:Msg.ActionSetup        = 'Instalar o actualizar Ollama'
            $script:Msg.ActionStatus       = 'Comprobar estado'
            $script:Msg.ActionDiagnose     = 'Diagnóstico (informe de soporte)'
            $script:Msg.ActionCleanup      = 'Limpiar modelos'
            $script:Msg.ActionPrompt       = 'Selección [1-4, Enter=1]'
            # Select Model
            $script:Msg.InvalidModel       = 'Variante de modelo no válida: {0}'
            $script:Msg.ValidVariants      = 'Variantes válidas: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b'
            $script:Msg.RamWarnModel       = 'Este modelo recomienda al menos {0}GB de RAM'
            $script:Msg.RamWarnSys         = 'Tu sistema tiene {0}GB de RAM'
            $script:Msg.ContinueAnyway     = '¿Continuar de todas formas?'
            $script:Msg.ConfirmPrompt      = '[s/N]'
            $script:Msg.ConfirmPattern     = '^[sS]$'
            $script:Msg.Aborted            = 'Cancelado.'
            $script:Msg.SelectedModel      = 'Modelo seleccionado: {0}'
            $script:Msg.ProceedNonInteract = 'Continuando...'
            $script:Msg.InternalError      = 'Error interno: ModelName no establecido'
            # Preflight
            $script:Msg.Preflight          = 'Ejecutando comprobaciones previas...'
            $script:Msg.PlatformError      = 'Este script es solo para Windows'
            $script:Msg.PlatformMacHint    = 'Para macOS: scripts/setup-ollama-mac.sh'
            $script:Msg.PlatformLinuxHint  = 'Para Linux: scripts/setup-ollama-linux.sh'
            $script:Msg.DiskInsufficient   = 'Espacio insuficiente: {0}GB disponibles, {1}GB requeridos'
            $script:Msg.DiskOk             = 'Espacio en disco: {0}GB disponibles'
            $script:Msg.NetworkError       = 'Sin conexión de red a ollama.com'
            $script:Msg.NetworkHint        = 'Comprueba: Invoke-WebRequest -Uri https://ollama.com'
            $script:Msg.NetworkOk          = 'Conexión de red OK'
            $script:Msg.GpuDetected        = 'GPU detectada: {0}'
            $script:Msg.GpuNone            = 'Sin GPU detectada - procesamiento sin aceleración GPU'
            # Status
            $script:Msg.StatusTitle        = 'Estado Ollama de Hablará (Windows)'
            $script:Msg.StatusInstalled    = 'Ollama instalado (v{0})'
            $script:Msg.StatusUpdateRec    = '    {0} Actualización recomendada (mínimo v{1}): winget upgrade Ollama.Ollama'
            $script:Msg.StatusNotFound     = 'Ollama no encontrado'
            $script:Msg.StatusServerOk     = 'Servidor en ejecución'
            $script:Msg.StatusServerFail   = 'Servidor no accesible'
            $script:Msg.StatusGpuNvidia    = 'NVIDIA (aceleración CUDA)'
            $script:Msg.StatusGpuAmd       = 'AMD (aceleración ROCm, experimental)'
            $script:Msg.StatusNoGpu        = 'Sin GPU — procesamiento sin aceleración GPU'
            $script:Msg.StatusBaseModel    = 'Modelo base: {0}'
            $script:Msg.StatusBaseModels   = 'Modelos base:'
            $script:Msg.StatusNoBase       = 'Sin modelo base encontrado'
            $script:Msg.StatusHablaraModel = 'Modelo Hablará: {0}'
            $script:Msg.StatusHablaraModels= 'Modelos Hablará:'
            $script:Msg.StatusNoHablara    = 'Sin modelo Hablará encontrado'
            $script:Msg.StatusBaseMissing  = '    {0} Modelo base ausente — el modelo Hablará lo requiere como base'
            $script:Msg.StatusInfSkip      = 'Prueba del modelo omitida (servidor no accesible)'
            $script:Msg.StatusModelOk      = 'Modelo respondiendo'
            $script:Msg.StatusModelFail    = 'Modelo no responde'
            $script:Msg.StatusStorage      = 'Uso de almacenamiento (Hablará): ~{0} GB'
            $script:Msg.StatusStorageUnk   = 'Uso de almacenamiento: no determinable'
            $script:Msg.StatusAllOk        = 'Todo está bien.'
            $script:Msg.StatusProblems     = '{0} problema(s) encontrado(s).'
            $script:Msg.StatusRepair       = '    Reparar: .\setup-ollama-win.ps1'
            # Diagnose
            $script:Msg.DiagnoseTitle      = '=== Informe de Diagnóstico Ollama de Hablará ==='
            $script:Msg.DiagnoseSystem     = 'Sistema:'
            $script:Msg.DiagnoseOllama     = 'Ollama:'
            $script:Msg.DiagnoseModels     = 'Modelos Hablará:'
            $script:Msg.DiagnoseStorage    = 'Almacenamiento (Hablará):'
            $script:Msg.DiagnoseLog        = 'Log de Ollama (errores recientes):'
            $script:Msg.DiagnoseCreated    = 'Creado:'
            $script:Msg.DiagnoseScript     = 'Script:'
            $script:Msg.DiagnoseSaved      = 'Informe guardado: {0}'
            $script:Msg.DiagnoseSaveFailed = 'No se pudo guardar el informe'
            $script:Msg.DiagnoseRamAvail   = 'disponible'
            $script:Msg.DiagnoseStorFree   = 'libre'
            $script:Msg.DiagnoseStorDisk   = 'Almacenamiento:'
            $script:Msg.DiagnoseUnknown    = 'desconocido'
            $script:Msg.DiagnoseNotInst    = 'no instalado'
            $script:Msg.DiagnoseNotReach   = 'no accesible'
            $script:Msg.DiagnoseRunning    = 'en ejecución'
            $script:Msg.DiagnoseNoModels   = '    [sin modelos Hablará encontrados]'
            $script:Msg.DiagnoseNoErrors   = '    [sin errores encontrados]'
            $script:Msg.DiagnoseNoLog      = '    [archivo de log no encontrado: {0}]'
            $script:Msg.DiagnoseLogUnread  = '    [archivo de log no legible: {0}]'
            $script:Msg.DiagnoseGpuNone    = 'Ninguna'
            $script:Msg.DiagnoseResponds   = '(respondiendo)'
            # Install
            $script:Msg.Installing         = 'Instalando Ollama...'
            $script:Msg.OllamaAlready      = 'Ollama ya está instalado'
            $script:Msg.OllamaVersion      = 'Versión: {0}'
            $script:Msg.ServerStartFailed  = 'No se pudo iniciar el servidor Ollama'
            $script:Msg.ServerStartHint    = 'Iniciar manualmente: ollama serve'
            $script:Msg.UsingWinget        = 'Usando winget (tiempo límite: 10 minutos)...'
            $script:Msg.WingetTimeout      = 'winget install superó el tiempo límite de 10 minutos'
            $script:Msg.WingetFailed       = 'Instalación con winget fallida: {0}'
            $script:Msg.OllamaInstalled    = 'Ollama instalado vía winget'
            $script:Msg.WaitForAutoStart   = 'Esperando el inicio automático de la app Ollama...'
            $script:Msg.RebootRequired     = 'Es posible que se requiera reiniciar el equipo'
            $script:Msg.OllamaPathError    = 'Ollama instalado, pero CLI no está en PATH. Abre un nuevo terminal o comprueba PATH.'
            $script:Msg.ServerStartWarn    = 'Inicio del servidor fallido - inicia manualmente: ollama serve'
            $script:Msg.ManualInstall      = 'Instala Ollama manualmente: https://ollama.com/download'
            $script:Msg.ManualRerun        = 'Luego ejecuta este script de nuevo.'
            $script:Msg.OllamaFound        = 'Ollama encontrado: {0}'
            $script:Msg.OllamaAppStart     = 'Iniciando aplicación Ollama...'
            $script:Msg.OllamaServeStart   = 'Iniciando servidor Ollama (ollama serve)...'
            $script:Msg.OllamaProcessExit  = 'Proceso Ollama terminado (código: {0})'
            $script:Msg.PortBusy           = 'Puerto 11434 ocupado, esperando API de Ollama...'
            $script:Msg.PortBusyWarn       = 'Puerto 11434 ocupado pero la API de Ollama no responde'
            $script:Msg.VersionWarn        = 'La versión de Ollama {0} es anterior a la recomendada ({1})'
            $script:Msg.UpdateHint         = 'Actualizar: winget upgrade Ollama.Ollama'
            # Model Download
            $script:Msg.DownloadingBase    = 'Descargando modelo base...'
            $script:Msg.ModelExists        = 'Modelo ya presente: {0}'
            $script:Msg.DownloadingModel   = 'Descargando {0} ({1}, tarda varios minutos según la conexión)...'
            $script:Msg.DownloadResumeTip  = 'Consejo: Si se interrumpe (Ctrl+C), reiniciar continúa la descarga'
            $script:Msg.DownloadHardTimeout= 'Tiempo límite absoluto tras {0} minutos — cancelando'
            $script:Msg.DownloadStall      = 'Sin progreso en la descarga durante {0} minutos — cancelando'
            $script:Msg.DownloadRunning    = '  Descargando... ({0}m {1}s)'
            $script:Msg.DownloadTimeoutW   = 'Tiempo límite de descarga tras {0} minutos (intento {1}/3)'
            $script:Msg.DownloadFailedW    = 'Descarga fallida (intento {0}/3)'
            $script:Msg.DownloadRetry      = 'Próximo intento en 5s...'
            $script:Msg.DownloadFailed     = 'Descarga del modelo fallida tras 3 intentos'
            $script:Msg.DownloadManual     = 'Intenta manualmente: ollama pull {0}'
            $script:Msg.DownloadDone       = 'Modelo descargado: {0}'
            # Custom Model
            $script:Msg.CreatingCustom     = 'Creando modelo Hablará...'
            $script:Msg.UpdatingCustom     = 'Actualizando modelo Hablará existente...'
            $script:Msg.CustomExists       = 'El modelo Hablará {0} ya está presente.'
            $script:Msg.CustomSkip         = 'Omitir (sin cambios)'
            $script:Msg.CustomUpdateOpt    = 'Actualizar modelo Hablará'
            $script:Msg.CustomUpdatePrompt = 'Selección [1-2, Enter=1]'
            $script:Msg.CustomKept         = 'Modelo Hablará conservado'
            $script:Msg.CustomPresent      = 'Modelo Hablará ya presente'
            $script:Msg.UsingHablaraConf   = 'Usando configuración de Hablará'
            $script:Msg.UsingDefaultConf   = 'Usando configuración por defecto'
            $script:Msg.ConfigReadError    = 'No se pudo leer la configuración: {0}'
            $script:Msg.CustomCreating      = 'Creando modelo Hablará {0}...'
            $script:Msg.CustomCreateTO     = 'ollama create superó el tiempo límite de 120s — usando modelo base'
            $script:Msg.CustomCreateFail   = 'El modelo Hablará no pudo ser {0} - usando modelo base'
            $script:Msg.CustomDone         = 'Modelo Hablará {0}: {1}'
            $script:Msg.ConfigError        = 'Error de configuración'
            $script:Msg.PermsWarn          = 'No se pudieron establecer permisos restrictivos: {0}'
            $script:Msg.VerbCreated        = 'creado'
            $script:Msg.VerbUpdated        = 'actualizado'
            # Verify
            $script:Msg.Verifying          = 'Verificando instalación...'
            $script:Msg.OllamaNotFound     = 'Ollama no encontrado'
            $script:Msg.ServerUnreachable  = 'Servidor Ollama no accesible'
            $script:Msg.BaseNotFound       = 'Modelo base no encontrado: {0}'
            $script:Msg.BaseOk             = 'Modelo base disponible: {0}'
            $script:Msg.CustomOk           = 'Modelo Hablará disponible: {0}'
            $script:Msg.CustomUnavail      = 'Modelo Hablará no disponible (usando modelo base)'
            $script:Msg.InferenceFailed    = 'Prueba del modelo fallida, prueba en la app'
            $script:Msg.SetupDone          = '¡Configuración completada!'
            # Main Summary
            $script:Msg.SetupComplete      = '¡Configuración Ollama de Hablará completada!'
            $script:Msg.Installed          = 'Instalado:'
            $script:Msg.BaseModelLabel     = '  Modelo base:    '
            $script:Msg.HablaraModelLabel  = '  Modelo Hablará: '
            $script:Msg.OllamaConfig       = 'Configuración de Ollama:'
            $script:Msg.ModelLabel         = '  Modelo:   '
            $script:Msg.BaseUrlLabel       = '  Base URL: '
            $script:Msg.Docs               = 'Documentación: https://github.com/fidpa/hablara'
            # Misc
            $script:Msg.TestModel          = 'Probando modelo...'
            $script:Msg.TestOk             = 'Prueba del modelo exitosa'
            $script:Msg.TestFail           = 'Prueba del modelo fallida'
            $script:Msg.WaitServer         = 'Esperando servidor Ollama...'
            $script:Msg.ServerReady        = 'El servidor Ollama está listo'
            $script:Msg.ServerAlready      = 'El servidor Ollama ya está en ejecución'
            $script:Msg.ServerNoResponse   = 'El servidor Ollama no responde tras {0}s'
            $script:Msg.SetupFailed        = 'Configuración fallida'
            $script:Msg.OllamaListTimeout  = 'ollama list superó el tiempo límite (15s) durante la comprobación del modelo'
            # Cleanup
            $script:Msg.CleanupNeedsTTY    = '-Cleanup requiere una sesión interactiva'
            $script:Msg.CleanupNoOllama    = 'Ollama no encontrado'
            $script:Msg.CleanupNoServer    = 'Servidor Ollama no accesible'
            $script:Msg.CleanupStartHint   = 'Inicia Ollama e inténtalo de nuevo'
            $script:Msg.CleanupInstalled   = 'Variantes Hablará instaladas:'
            $script:Msg.CleanupPrompt      = '¿Qué variante eliminar? (número, Enter=cancelar)'
            $script:Msg.CleanupInvalid     = 'Selección no válida'
            $script:Msg.CleanupDeleted     = '{0} eliminado'
            $script:Msg.CleanupTimeout     = '{0} no se pudo eliminar: Tiempo límite (30s)'
            $script:Msg.CleanupFailed      = '{0} no se pudo eliminar: {1}'
            $script:Msg.CleanupUnknownErr  = 'error desconocido'
            $script:Msg.CleanupNoneLeft    = 'No quedan modelos Hablará instalados. Ejecuta el setup de nuevo para instalar un modelo.'
            $script:Msg.CleanupNoModels    = 'No se encontraron modelos Hablará.'
            # Help
            $script:Msg.HelpTitle          = 'Hablará Ollama Setup v{0} (Windows)'
            $script:Msg.HelpDescription    = '  Instala Ollama y configura un modelo Hablará optimizado.'
            $script:Msg.HelpUsage          = 'Uso:'
            $script:Msg.HelpUsageLine      = '  .\setup-ollama-win.ps1 [OPCIONES]'
            $script:Msg.HelpOptions        = 'Opciones:'
            $script:Msg.HelpOptModel       = '  -Model VARIANTE       Elegir variante de modelo: 1.5b, 3b, 7b, qwen3-8b (por defecto: 3b)'
            $script:Msg.HelpOptUpdate      = '  -Update               Recrear modelo personalizado Hablará (actualizar Modelfile)'
            $script:Msg.HelpOptStatus      = '  -Status               Health check: comprobación de 7 puntos de la instalación de Ollama'
            $script:Msg.HelpOptDiagnose    = '  -Diagnose             Generar informe de soporte (texto plano, copiable)'
            $script:Msg.HelpOptCleanup     = '  -Cleanup              Eliminar variante instalada de forma interactiva'
            $script:Msg.HelpOptLang        = '  -Lang da|de|en|es|fr|it|nl|pl|pt|sv  Idioma (da=Danés, de=Alemán, en=Inglés, es=Español, fr=Francés, it=Italiano, nl=Neerlandés, pl=Polaco, pt=Portugués, sv=Sueco)'
            $script:Msg.HelpOptHelp        = '  -Help                 Mostrar esta ayuda'
            $script:Msg.HelpNoOpts         = '  Sin opciones, se inicia un menú interactivo.'
            $script:Msg.HelpVariants       = 'Variantes de modelo:'
            $script:Msg.HelpExamples       = 'Ejemplos:'
            $script:Msg.HelpExModel        = '  .\setup-ollama-win.ps1 -Model 3b       Instalar variante 3b'
            $script:Msg.HelpExUpdate       = '  .\setup-ollama-win.ps1 -Update         Actualizar modelo personalizado'
            $script:Msg.HelpExStatus       = '  .\setup-ollama-win.ps1 -Status         Comprobar instalación'
            $script:Msg.HelpExDiagnose     = '  .\setup-ollama-win.ps1 -Diagnose       Crear informe de error'
            $script:Msg.HelpExCleanup      = '  .\setup-ollama-win.ps1 -Cleanup        Eliminar variante'
            $script:Msg.HelpExitCodes      = 'Códigos de salida:'
            $script:Msg.HelpExit0          = '  0  Éxito'
            $script:Msg.HelpExit1          = '  1  Error general'
            $script:Msg.HelpExit2          = '  2  Espacio en disco insuficiente'
            $script:Msg.HelpExit3          = '  3  Sin conexión de red'
            $script:Msg.HelpExit4          = '  4  Plataforma incorrecta'
            $script:Msg.AutoInstallFailed  = 'Ollama no se pudo instalar automáticamente'
            # Hardware Detection
            $script:Msg.HwDetectionHeader  = 'Detección de hardware:'
            $script:Msg.HwBandwidth        = 'Ancho de banda de memoria: ~{0} GB/s · {1} GB RAM'
            $script:Msg.HwRecommendation   = 'Recomendación de modelo para tu hardware:'
            $script:Msg.HwLocalTooSlow     = 'Los modelos locales serán lentos en este hardware'
            $script:Msg.HwCloudHint        = 'Recomendación: API de OpenAI o Anthropic para mejor experiencia'
            $script:Msg.HwProceedLocal     = '¿Instalar localmente de todos modos? [s/N]'
            $script:Msg.HwTagRecommended   = 'recomendado'
            $script:Msg.HwTagSlow          = 'lento'
            $script:Msg.HwTagTooSlow       = 'demasiado lento'
            $script:Msg.ChoicePromptHw     = 'Selección [1-4, Enter={0}]'
            $script:Msg.HwUnknownChip      = 'Procesador desconocido — no se puede recomendar ancho de banda'
            $script:Msg.HwMultiCallHint   = 'Hablará ejecuta múltiples pasos de análisis por grabación'
            # Benchmark
            $script:Msg.BenchResult        = 'Benchmark: ~{0} tok/s con {1}'
            $script:Msg.BenchExcellent     = 'Excelente — tu hardware maneja este modelo con facilidad'
            $script:Msg.BenchGood          = 'Bien — este modelo funciona bien en tu hardware'
            $script:Msg.BenchMarginal      = 'Límite — considera un modelo más pequeño para mayor fluidez'
            $script:Msg.BenchTooSlow       = 'Demasiado lento — se recomienda un modelo más pequeño o proveedor en la nube'
            $script:Msg.BenchSkip          = 'Benchmark omitido (medición fallida)'
        }
        'fr' {
            $script:Msg.ErrorPrefix        = 'Erreur'
            # Model Menu
            $script:Msg.ChooseModel        = 'Choisissez un modèle :'
            $script:Msg.ChoicePrompt       = 'Sélection [1-4, Entrée=1]'
            $script:Msg.Model3B            = 'Performance optimale [Par défaut]'
            $script:Msg.Model1_5B          = 'Rapide, précision limitée [Entrée de gamme]'
            $script:Msg.Model7B            = 'Nécessite du matériel haute performance'
            $script:Msg.ModelQwen3         = 'Meilleure analyse d''argumentation [Premium]'
            # Main Menu
            $script:Msg.ChooseAction       = 'Choisissez une action :'
            $script:Msg.ActionSetup        = 'Installer ou mettre à jour Ollama'
            $script:Msg.ActionStatus       = "Vérifier l'état"
            $script:Msg.ActionDiagnose     = "Diagnostic (rapport d'assistance)"
            $script:Msg.ActionCleanup      = 'Nettoyer les modèles'
            $script:Msg.ActionPrompt       = 'Sélection [1-4, Entrée=1]'
            # Select Model
            $script:Msg.InvalidModel       = 'Variante de modèle invalide : {0}'
            $script:Msg.ValidVariants      = 'Variantes valides : qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b'
            $script:Msg.RamWarnModel       = 'Ce modèle recommande au moins {0} Go de RAM'
            $script:Msg.RamWarnSys         = 'Votre système dispose de {0} Go de RAM'
            $script:Msg.ContinueAnyway     = 'Continuer quand même ?'
            $script:Msg.ConfirmPrompt      = '[o/N]'
            $script:Msg.ConfirmPattern     = '^[oO]$'
            $script:Msg.Aborted            = 'Annulé.'
            $script:Msg.SelectedModel      = 'Modèle sélectionné : {0}'
            $script:Msg.ProceedNonInteract = 'Continuation...'
            $script:Msg.InternalError      = 'Erreur interne : ModelName non défini'
            # Preflight
            $script:Msg.Preflight          = 'Exécution des vérifications préalables...'
            $script:Msg.PlatformError      = 'Ce script est uniquement pour Windows'
            $script:Msg.PlatformMacHint    = 'Pour macOS : scripts/setup-ollama-mac.sh'
            $script:Msg.PlatformLinuxHint  = 'Pour Linux : scripts/setup-ollama-linux.sh'
            $script:Msg.DiskInsufficient   = 'Espace insuffisant : {0} Go disponibles, {1} Go requis'
            $script:Msg.DiskOk             = 'Espace disque : {0} Go disponibles'
            $script:Msg.NetworkError       = 'Pas de connexion réseau à ollama.com'
            $script:Msg.NetworkHint        = 'Vérifiez : Invoke-WebRequest -Uri https://ollama.com'
            $script:Msg.NetworkOk          = 'Connexion réseau OK'
            $script:Msg.GpuDetected        = 'GPU détecté : {0}'
            $script:Msg.GpuNone            = 'Aucun GPU détecté - traitement sans accélération GPU'
            # Status
            $script:Msg.StatusTitle        = 'État Ollama Hablará (Windows)'
            $script:Msg.StatusInstalled    = 'Ollama installé (v{0})'
            $script:Msg.StatusUpdateRec    = '    {0} Mise à jour recommandée (minimum v{1}) : winget upgrade Ollama.Ollama'
            $script:Msg.StatusNotFound     = 'Ollama introuvable'
            $script:Msg.StatusServerOk     = 'Serveur en cours d''exécution'
            $script:Msg.StatusServerFail   = 'Serveur inaccessible'
            $script:Msg.StatusGpuNvidia    = 'NVIDIA (accélération CUDA)'
            $script:Msg.StatusGpuAmd       = 'AMD (accélération ROCm, expérimental)'
            $script:Msg.StatusNoGpu        = 'Aucun GPU — traitement sans accélération GPU'
            $script:Msg.StatusBaseModel    = 'Modèle de base : {0}'
            $script:Msg.StatusBaseModels   = 'Modèles de base :'
            $script:Msg.StatusNoBase       = 'Aucun modèle de base trouvé'
            $script:Msg.StatusHablaraModel = 'Modèle Hablará : {0}'
            $script:Msg.StatusHablaraModels= 'Modèles Hablará :'
            $script:Msg.StatusNoHablara    = 'Aucun modèle Hablará trouvé'
            $script:Msg.StatusBaseMissing  = '    {0} Modèle de base manquant — le modèle Hablará en a besoin comme base'
            $script:Msg.StatusInfSkip      = 'Test du modèle ignoré (serveur inaccessible)'
            $script:Msg.StatusModelOk      = 'Modèle répond'
            $script:Msg.StatusModelFail    = 'Modèle ne répond pas'
            $script:Msg.StatusStorage      = 'Utilisation du stockage (Hablará) : ~{0} Go'
            $script:Msg.StatusStorageUnk   = 'Utilisation du stockage : indéterminable'
            $script:Msg.StatusAllOk        = 'Tout est en ordre.'
            $script:Msg.StatusProblems     = '{0} problème(s) trouvé(s).'
            $script:Msg.StatusRepair       = '    Réparer : .\setup-ollama-win.ps1'
            # Diagnose
            $script:Msg.DiagnoseTitle      = '=== Rapport de Diagnostic Ollama Hablará ==='
            $script:Msg.DiagnoseSystem     = 'Système :'
            $script:Msg.DiagnoseOllama     = 'Ollama :'
            $script:Msg.DiagnoseModels     = 'Modèles Hablará :'
            $script:Msg.DiagnoseStorage    = 'Stockage (Hablará) :'
            $script:Msg.DiagnoseLog        = 'Journal Ollama (erreurs récentes) :'
            $script:Msg.DiagnoseCreated    = 'Créé :'
            $script:Msg.DiagnoseScript     = 'Script :'
            $script:Msg.DiagnoseSaved      = 'Rapport enregistré : {0}'
            $script:Msg.DiagnoseSaveFailed = 'Impossible d''enregistrer le rapport'
            $script:Msg.DiagnoseRamAvail   = 'disponible'
            $script:Msg.DiagnoseStorFree   = 'libre'
            $script:Msg.DiagnoseStorDisk   = 'Stockage :'
            $script:Msg.DiagnoseUnknown    = 'inconnu'
            $script:Msg.DiagnoseNotInst    = 'non installé'
            $script:Msg.DiagnoseNotReach   = 'inaccessible'
            $script:Msg.DiagnoseRunning    = "en cours d'exécution"
            $script:Msg.DiagnoseNoModels   = '    [aucun modèle Hablará trouvé]'
            $script:Msg.DiagnoseNoErrors   = '    [aucune erreur trouvée]'
            $script:Msg.DiagnoseNoLog      = '    [fichier journal introuvable : {0}]'
            $script:Msg.DiagnoseLogUnread  = '    [fichier journal illisible : {0}]'
            $script:Msg.DiagnoseGpuNone    = 'Aucun'
            $script:Msg.DiagnoseResponds   = '(répond)'
            # Install
            $script:Msg.Installing         = "Installation d'Ollama..."
            $script:Msg.OllamaAlready      = 'Ollama est déjà installé'
            $script:Msg.OllamaVersion      = 'Version : {0}'
            $script:Msg.ServerStartFailed  = 'Impossible de démarrer le serveur Ollama'
            $script:Msg.ServerStartHint    = 'Démarrer manuellement : ollama serve'
            $script:Msg.UsingWinget        = 'Utilisation de winget (délai : 10 minutes)...'
            $script:Msg.WingetTimeout      = 'winget install a dépassé le délai de 10 minutes'
            $script:Msg.WingetFailed       = "Échec de l'installation via winget : {0}"
            $script:Msg.OllamaInstalled    = 'Ollama installé via winget'
            $script:Msg.WaitForAutoStart   = "Attente du démarrage automatique de l'app Ollama..."
            $script:Msg.RebootRequired     = "Un redémarrage de l'ordinateur peut être nécessaire"
            $script:Msg.OllamaPathError    = 'Ollama installé, mais CLI introuvable dans le PATH. Ouvrez un nouveau terminal ou vérifiez le PATH.'
            $script:Msg.ServerStartWarn    = 'Échec du démarrage du serveur - démarrer manuellement : ollama serve'
            $script:Msg.ManualInstall      = 'Installez Ollama manuellement : https://ollama.com/download'
            $script:Msg.ManualRerun        = 'Relancez ensuite ce script.'
            $script:Msg.OllamaFound        = 'Ollama trouvé : {0}'
            $script:Msg.OllamaAppStart     = "Démarrage de l'application Ollama..."
            $script:Msg.OllamaServeStart   = 'Démarrage du serveur Ollama (ollama serve)...'
            $script:Msg.OllamaProcessExit  = 'Processus Ollama terminé (code : {0})'
            $script:Msg.PortBusy           = "Le port 11434 est occupé, en attente de l'API Ollama..."
            $script:Msg.PortBusyWarn       = "Port 11434 occupé mais l'API Ollama ne répond pas"
            $script:Msg.VersionWarn        = 'La version Ollama {0} est plus ancienne que recommandé ({1})'
            $script:Msg.UpdateHint         = 'Mise à jour : winget upgrade Ollama.Ollama'
            # Model Download
            $script:Msg.DownloadingBase    = 'Téléchargement du modèle de base...'
            $script:Msg.ModelExists        = 'Modèle déjà présent : {0}'
            $script:Msg.DownloadingModel   = 'Téléchargement de {0} ({1}, prend plusieurs minutes selon la connexion)...'
            $script:Msg.DownloadResumeTip  = 'Astuce : En cas d''interruption (Ctrl+C), relancer reprend le téléchargement'
            $script:Msg.DownloadHardTimeout= 'Délai maximal atteint après {0} minutes — annulation'
            $script:Msg.DownloadStall      = 'Aucune progression du téléchargement depuis {0} minutes — annulation'
            $script:Msg.DownloadRunning    = '  Téléchargement en cours... ({0}m {1}s)'
            $script:Msg.DownloadTimeoutW   = 'Délai de téléchargement dépassé après {0} minutes (tentative {1}/3)'
            $script:Msg.DownloadFailedW    = 'Téléchargement échoué (tentative {0}/3)'
            $script:Msg.DownloadRetry      = 'Prochaine tentative dans 5s...'
            $script:Msg.DownloadFailed     = 'Échec du téléchargement du modèle après 3 tentatives'
            $script:Msg.DownloadManual     = 'Essayez manuellement : ollama pull {0}'
            $script:Msg.DownloadDone       = 'Modèle téléchargé : {0}'
            # Custom Model
            $script:Msg.CreatingCustom     = 'Création du modèle Hablará...'
            $script:Msg.UpdatingCustom     = 'Mise à jour du modèle Hablará existant...'
            $script:Msg.CustomExists       = 'Le modèle Hablará {0} est déjà présent.'
            $script:Msg.CustomSkip         = 'Ignorer (aucune modification)'
            $script:Msg.CustomUpdateOpt    = 'Mettre à jour le modèle Hablará'
            $script:Msg.CustomUpdatePrompt = 'Sélection [1-2, Entrée=1]'
            $script:Msg.CustomKept         = 'Modèle Hablará conservé'
            $script:Msg.CustomPresent      = 'Modèle Hablará déjà présent'
            $script:Msg.UsingHablaraConf   = 'Utilisation de la configuration Hablará'
            $script:Msg.UsingDefaultConf   = 'Utilisation de la configuration par défaut'
            $script:Msg.ConfigReadError    = 'Impossible de lire la configuration : {0}'
            $script:Msg.CustomCreating      = 'Création du modèle Hablará {0}...'
            $script:Msg.CustomCreateTO     = 'ollama create a dépassé le délai de 120s — utilisation du modèle de base'
            $script:Msg.CustomCreateFail   = 'Le modèle Hablará n''a pas pu être {0} - utilisation du modèle de base'
            $script:Msg.CustomDone         = 'Modèle Hablará {0} : {1}'
            $script:Msg.ConfigError        = 'Erreur de configuration'
            $script:Msg.PermsWarn          = 'Impossible de définir des autorisations restrictives : {0}'
            $script:Msg.VerbCreated        = 'créé'
            $script:Msg.VerbUpdated        = 'mis à jour'
            # Verify
            $script:Msg.Verifying          = "Vérification de l'installation..."
            $script:Msg.OllamaNotFound     = 'Ollama introuvable'
            $script:Msg.ServerUnreachable  = 'Serveur Ollama inaccessible'
            $script:Msg.BaseNotFound       = 'Modèle de base introuvable : {0}'
            $script:Msg.BaseOk             = 'Modèle de base disponible : {0}'
            $script:Msg.CustomOk           = 'Modèle Hablará disponible : {0}'
            $script:Msg.CustomUnavail      = 'Modèle Hablará indisponible (utilisation du modèle de base)'
            $script:Msg.InferenceFailed    = "Test du modèle échoué, testez dans l'application"
            $script:Msg.SetupDone          = 'Configuration terminée !'
            # Main Summary
            $script:Msg.SetupComplete      = 'Configuration Ollama Hablará terminée !'
            $script:Msg.Installed          = 'Installé :'
            $script:Msg.BaseModelLabel     = '  Modèle de base :  '
            $script:Msg.HablaraModelLabel  = '  Modèle Hablará :  '
            $script:Msg.OllamaConfig       = 'Configuration Ollama :'
            $script:Msg.ModelLabel         = '  Modèle :   '
            $script:Msg.BaseUrlLabel       = '  Base URL : '
            $script:Msg.Docs               = 'Documentation : https://github.com/fidpa/hablara'
            # Misc
            $script:Msg.TestModel          = 'Test du modèle...'
            $script:Msg.TestOk             = 'Test du modèle réussi'
            $script:Msg.TestFail           = 'Test du modèle échoué'
            $script:Msg.WaitServer         = 'En attente du serveur Ollama...'
            $script:Msg.ServerReady        = 'Le serveur Ollama est prêt'
            $script:Msg.ServerAlready      = 'Le serveur Ollama est déjà en cours d''exécution'
            $script:Msg.ServerNoResponse   = 'Le serveur Ollama ne répond pas après {0}s'
            $script:Msg.SetupFailed        = 'Échec de la configuration'
            $script:Msg.OllamaListTimeout  = 'ollama list a dépassé le délai (15s) lors de la vérification du modèle'
            # Cleanup
            $script:Msg.CleanupNeedsTTY    = '-Cleanup nécessite une session interactive'
            $script:Msg.CleanupNoOllama    = 'Ollama introuvable'
            $script:Msg.CleanupNoServer    = 'Serveur Ollama inaccessible'
            $script:Msg.CleanupStartHint   = 'Démarrez Ollama et réessayez'
            $script:Msg.CleanupInstalled   = 'Variantes Hablará installées :'
            $script:Msg.CleanupPrompt      = 'Quelle variante supprimer ? (numéro, Entrée=annuler)'
            $script:Msg.CleanupInvalid     = 'Sélection invalide'
            $script:Msg.CleanupDeleted     = '{0} supprimé'
            $script:Msg.CleanupTimeout     = '{0} n''a pas pu être supprimé : Délai dépassé (30s)'
            $script:Msg.CleanupFailed      = '{0} n''a pas pu être supprimé : {1}'
            $script:Msg.CleanupUnknownErr  = 'erreur inconnue'
            $script:Msg.CleanupNoneLeft    = 'Aucun modèle Hablará installé. Relancez le setup pour installer un modèle.'
            $script:Msg.CleanupNoModels    = 'Aucun modèle Hablará trouvé.'
            # Help
            $script:Msg.HelpTitle          = 'Hablará Ollama Setup v{0} (Windows)'
            $script:Msg.HelpDescription    = '  Installe Ollama et configure un modèle Hablará optimisé.'
            $script:Msg.HelpUsage          = 'Utilisation :'
            $script:Msg.HelpUsageLine      = '  .\setup-ollama-win.ps1 [OPTIONS]'
            $script:Msg.HelpOptions        = 'Options :'
            $script:Msg.HelpOptModel       = '  -Model VARIANTE       Choisir la variante : 1.5b, 3b, 7b, qwen3-8b (par défaut : 3b)'
            $script:Msg.HelpOptUpdate      = '  -Update               Recréer le modèle Hablará (mettre à jour le Modelfile)'
            $script:Msg.HelpOptStatus      = '  -Status               Vérification : contrôle en 7 points de l''installation Ollama'
            $script:Msg.HelpOptDiagnose    = '  -Diagnose             Générer un rapport d''assistance (texte brut, copiable)'
            $script:Msg.HelpOptCleanup     = '  -Cleanup              Supprimer interactivement une variante installée'
            $script:Msg.HelpOptLang        = '  -Lang da|de|en|es|fr|it|nl|pl|pt|sv  Langue (da=Danois, de=Allemand, en=Anglais, es=Espagnol, fr=Français, it=Italien, nl=Néerlandais, pl=Polonais, pt=Portugais, sv=Suédois)'
            $script:Msg.HelpOptHelp        = '  -Help                 Afficher cette aide'
            $script:Msg.HelpNoOpts         = '  Sans options, un menu interactif démarre.'
            $script:Msg.HelpVariants       = 'Variantes de modèle :'
            $script:Msg.HelpExamples       = 'Exemples :'
            $script:Msg.HelpExModel        = '  .\setup-ollama-win.ps1 -Model 3b       Installer la variante 3b'
            $script:Msg.HelpExUpdate       = '  .\setup-ollama-win.ps1 -Update         Mettre à jour le modèle personnalisé'
            $script:Msg.HelpExStatus       = '  .\setup-ollama-win.ps1 -Status         Vérifier l''installation'
            $script:Msg.HelpExDiagnose     = '  .\setup-ollama-win.ps1 -Diagnose       Créer un rapport de bug'
            $script:Msg.HelpExCleanup      = '  .\setup-ollama-win.ps1 -Cleanup        Supprimer une variante'
            $script:Msg.HelpExitCodes      = 'Codes de sortie :'
            $script:Msg.HelpExit0          = '  0  Succès'
            $script:Msg.HelpExit1          = '  1  Erreur générale'
            $script:Msg.HelpExit2          = '  2  Espace disque insuffisant'
            $script:Msg.HelpExit3          = '  3  Pas de connexion réseau'
            $script:Msg.HelpExit4          = '  4  Mauvaise plateforme'
            $script:Msg.AutoInstallFailed  = "Ollama n'a pas pu être installé automatiquement"
            # Hardware Detection
            $script:Msg.HwDetectionHeader  = 'Détection matérielle :'
            $script:Msg.HwBandwidth        = 'Bande passante mémoire : ~{0} Go/s · {1} Go RAM'
            $script:Msg.HwRecommendation   = 'Recommandation de modèle pour votre matériel :'
            $script:Msg.HwLocalTooSlow     = 'Les modèles locaux seront lents sur ce matériel'
            $script:Msg.HwCloudHint        = 'Recommandation : API OpenAI ou Anthropic pour la meilleure expérience'
            $script:Msg.HwProceedLocal     = 'Installer localement quand même ? [o/N]'
            $script:Msg.HwTagRecommended   = 'recommandé'
            $script:Msg.HwTagSlow          = 'lent'
            $script:Msg.HwTagTooSlow       = 'trop lent'
            $script:Msg.ChoicePromptHw     = 'Choix [1-4, Entrée={0}]'
            $script:Msg.HwUnknownChip      = 'Processeur inconnu — pas de recommandation de bande passante possible'
            $script:Msg.HwMultiCallHint   = 'Hablará exécute plusieurs étapes d''analyse par enregistrement'
            # Benchmark
            $script:Msg.BenchResult        = 'Benchmark : ~{0} tok/s avec {1}'
            $script:Msg.BenchExcellent     = 'Excellent — votre matériel gère ce modèle sans effort'
            $script:Msg.BenchGood          = 'Bon — ce modèle fonctionne bien sur votre matériel'
            $script:Msg.BenchMarginal      = 'Marginal — un modèle plus petit offre une meilleure fluidité'
            $script:Msg.BenchTooSlow       = 'Trop lent — un modèle plus petit ou un fournisseur cloud est recommandé'
            $script:Msg.BenchSkip          = 'Benchmark ignoré (mesure échouée)'
        }
        'it' {
            $script:Msg.ErrorPrefix        = 'Errore'
            # Model Menu
            $script:Msg.ChooseModel        = 'Scegli un modello:'
            $script:Msg.ChoicePrompt       = 'Selezione [1-4, Invio=1]'
            $script:Msg.Model3B            = 'Prestazioni generali ottimali [Predefinito]'
            $script:Msg.Model1_5B          = 'Veloce, precisione limitata [Base]'
            $script:Msg.Model7B            = 'Richiede hardware ad alte prestazioni'
            $script:Msg.ModelQwen3         = "Migliore analisi dell'argomentazione [Premium]"
            # Main Menu
            $script:Msg.ChooseAction       = "Scegli un'azione:"
            $script:Msg.ActionSetup        = 'Installare o aggiornare Ollama'
            $script:Msg.ActionStatus       = 'Controlla lo stato'
            $script:Msg.ActionDiagnose     = 'Diagnostica (rapporto di supporto)'
            $script:Msg.ActionCleanup      = 'Pulisci i modelli'
            $script:Msg.ActionPrompt       = 'Selezione [1-4, Invio=1]'
            # Select Model
            $script:Msg.InvalidModel       = 'Variante di modello non valida: {0}'
            $script:Msg.ValidVariants      = 'Varianti valide: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b'
            $script:Msg.RamWarnModel       = 'Questo modello richiede almeno {0}GB di RAM'
            $script:Msg.RamWarnSys         = 'Il tuo sistema ha {0}GB di RAM'
            $script:Msg.ContinueAnyway     = 'Continuare comunque?'
            $script:Msg.ConfirmPrompt      = '[s/N]'
            $script:Msg.ConfirmPattern     = '^[sS]$'
            $script:Msg.Aborted            = 'Annullato.'
            $script:Msg.SelectedModel      = 'Modello selezionato: {0}'
            $script:Msg.ProceedNonInteract = 'Continuo...'
            $script:Msg.InternalError      = 'Errore interno: ModelName non impostato'
            # Preflight
            $script:Msg.Preflight          = 'Esecuzione dei controlli preliminari...'
            $script:Msg.PlatformError      = 'Questo script è solo per Windows'
            $script:Msg.PlatformMacHint    = 'Per macOS: scripts/setup-ollama-mac.sh'
            $script:Msg.PlatformLinuxHint  = 'Per Linux: scripts/setup-ollama-linux.sh'
            $script:Msg.DiskInsufficient   = 'Spazio insufficiente: {0}GB disponibili, {1}GB richiesti'
            $script:Msg.DiskOk             = 'Spazio su disco: {0}GB disponibili'
            $script:Msg.NetworkError       = 'Nessuna connessione di rete a ollama.com'
            $script:Msg.NetworkHint        = 'Verifica: Invoke-WebRequest -Uri https://ollama.com'
            $script:Msg.NetworkOk          = 'Connessione di rete OK'
            $script:Msg.GpuDetected        = 'GPU rilevata: {0}'
            $script:Msg.GpuNone            = 'Nessuna GPU rilevata - elaborazione senza accelerazione GPU'
            # Status
            $script:Msg.StatusTitle        = 'Stato Ollama Hablará (Windows)'
            $script:Msg.StatusInstalled    = 'Ollama installato (v{0})'
            $script:Msg.StatusUpdateRec    = '    {0} Aggiornamento raccomandato (minimo v{1}): winget upgrade Ollama.Ollama'
            $script:Msg.StatusNotFound     = 'Ollama non trovato'
            $script:Msg.StatusServerOk     = 'Server in esecuzione'
            $script:Msg.StatusServerFail   = 'Server non raggiungibile'
            $script:Msg.StatusGpuNvidia    = 'NVIDIA (accelerazione CUDA)'
            $script:Msg.StatusGpuAmd       = 'AMD (accelerazione ROCm, sperimentale)'
            $script:Msg.StatusNoGpu        = 'Nessuna GPU — elaborazione senza accelerazione GPU'
            $script:Msg.StatusBaseModel    = 'Modello base: {0}'
            $script:Msg.StatusBaseModels   = 'Modelli base:'
            $script:Msg.StatusNoBase       = 'Nessun modello base trovato'
            $script:Msg.StatusHablaraModel = 'Modello Hablará: {0}'
            $script:Msg.StatusHablaraModels= 'Modelli Hablará:'
            $script:Msg.StatusNoHablara    = 'Nessun modello Hablará trovato'
            $script:Msg.StatusBaseMissing  = '    {0} Modello base mancante — il modello Hablará lo richiede come base'
            $script:Msg.StatusInfSkip      = 'Test del modello saltato (server non raggiungibile)'
            $script:Msg.StatusModelOk      = 'Modello risponde'
            $script:Msg.StatusModelFail    = 'Modello non risponde'
            $script:Msg.StatusStorage      = "Utilizzo dell'archiviazione (Hablará): ~{0} GB"
            $script:Msg.StatusStorageUnk   = "Utilizzo dell'archiviazione: non determinabile"
            $script:Msg.StatusAllOk        = 'Tutto è in ordine.'
            $script:Msg.StatusProblems     = '{0} problema/i trovato/i.'
            $script:Msg.StatusRepair       = '    Riparare: .\setup-ollama-win.ps1'
            # Diagnose
            $script:Msg.DiagnoseTitle      = '=== Rapporto di Diagnostica Ollama Hablará ==='
            $script:Msg.DiagnoseSystem     = 'Sistema:'
            $script:Msg.DiagnoseOllama     = 'Ollama:'
            $script:Msg.DiagnoseModels     = 'Modelli Hablará:'
            $script:Msg.DiagnoseStorage    = 'Archiviazione (Hablará):'
            $script:Msg.DiagnoseLog        = 'Log Ollama (errori recenti):'
            $script:Msg.DiagnoseCreated    = 'Creato:'
            $script:Msg.DiagnoseScript     = 'Script:'
            $script:Msg.DiagnoseSaved      = 'Report salvato: {0}'
            $script:Msg.DiagnoseSaveFailed = 'Impossibile salvare il report'
            $script:Msg.DiagnoseRamAvail   = 'disponibile'
            $script:Msg.DiagnoseStorFree   = 'libero'
            $script:Msg.DiagnoseStorDisk   = 'Archiviazione:'
            $script:Msg.DiagnoseUnknown    = 'sconosciuto'
            $script:Msg.DiagnoseNotInst    = 'non installato'
            $script:Msg.DiagnoseNotReach   = 'non raggiungibile'
            $script:Msg.DiagnoseRunning    = 'in esecuzione'
            $script:Msg.DiagnoseNoModels   = '    [nessun modello Hablará trovato]'
            $script:Msg.DiagnoseNoErrors   = '    [nessun errore trovato]'
            $script:Msg.DiagnoseNoLog      = '    [file di log non trovato: {0}]'
            $script:Msg.DiagnoseLogUnread  = '    [file di log non leggibile: {0}]'
            $script:Msg.DiagnoseGpuNone    = 'Nessuna'
            $script:Msg.DiagnoseResponds   = '(risponde)'
            # Install
            $script:Msg.Installing         = 'Installazione di Ollama...'
            $script:Msg.OllamaAlready      = 'Ollama è già installato'
            $script:Msg.OllamaVersion      = 'Versione: {0}'
            $script:Msg.ServerStartFailed  = 'Impossibile avviare il server Ollama'
            $script:Msg.ServerStartHint    = 'Avviare manualmente: ollama serve'
            $script:Msg.UsingWinget        = 'Utilizzo di winget (tempo massimo: 10 minuti)...'
            $script:Msg.WingetTimeout      = 'winget install ha superato il tempo massimo di 10 minuti'
            $script:Msg.WingetFailed       = 'Installazione con winget fallita: {0}'
            $script:Msg.OllamaInstalled    = 'Ollama installato via winget'
            $script:Msg.WaitForAutoStart   = "Attesa dell'avvio automatico dell'app Ollama..."
            $script:Msg.RebootRequired     = 'Potrebbe essere necessario riavviare il computer'
            $script:Msg.OllamaPathError    = 'Ollama installato, ma CLI non è nel PATH. Aprire un nuovo terminale o verificare il PATH.'
            $script:Msg.ServerStartWarn    = 'Avvio del server fallito - avviare manualmente: ollama serve'
            $script:Msg.ManualInstall      = 'Installare Ollama manualmente: https://ollama.com/download'
            $script:Msg.ManualRerun        = 'Poi eseguire di nuovo questo script.'
            $script:Msg.OllamaFound        = 'Ollama trovato: {0}'
            $script:Msg.OllamaAppStart     = "Avvio dell'applicazione Ollama..."
            $script:Msg.OllamaServeStart   = 'Avvio del server Ollama (ollama serve)...'
            $script:Msg.OllamaProcessExit  = 'Processo Ollama terminato (codice: {0})'
            $script:Msg.PortBusy           = "La porta 11434 è occupata, in attesa dell'API Ollama..."
            $script:Msg.PortBusyWarn       = "Porta 11434 occupata ma l'API Ollama non risponde"
            $script:Msg.VersionWarn        = 'La versione Ollama {0} è precedente a quella raccomandata ({1})'
            $script:Msg.UpdateHint         = 'Aggiornare: winget upgrade Ollama.Ollama'
            # Model Download
            $script:Msg.DownloadingBase    = 'Scaricamento del modello base...'
            $script:Msg.ModelExists        = 'Modello già presente: {0}'
            $script:Msg.DownloadingModel   = 'Scaricamento di {0} ({1}, richiede diversi minuti a seconda della connessione)...'
            $script:Msg.DownloadResumeTip  = 'Suggerimento: Se interrotto (Ctrl+C), riavviare continua lo scaricamento'
            $script:Msg.DownloadHardTimeout= 'Tempo massimo superato dopo {0} minuti — interruzione'
            $script:Msg.DownloadStall      = 'Nessun progresso nello scaricamento per {0} minuti — interruzione'
            $script:Msg.DownloadRunning    = '  Scaricamento in corso... ({0}m {1}s)'
            $script:Msg.DownloadTimeoutW   = 'Tempo massimo di scaricamento superato dopo {0} minuti (tentativo {1}/3)'
            $script:Msg.DownloadFailedW    = 'Scaricamento fallito (tentativo {0}/3)'
            $script:Msg.DownloadRetry      = 'Prossimo tentativo tra 5s...'
            $script:Msg.DownloadFailed     = 'Scaricamento del modello fallito dopo 3 tentativi'
            $script:Msg.DownloadManual     = 'Provare manualmente: ollama pull {0}'
            $script:Msg.DownloadDone       = 'Modello scaricato: {0}'
            # Custom Model
            $script:Msg.CreatingCustom     = 'Creazione del modello Hablará...'
            $script:Msg.UpdatingCustom     = 'Aggiornamento del modello Hablará esistente...'
            $script:Msg.CustomExists       = 'Il modello Hablará {0} è già presente.'
            $script:Msg.CustomSkip         = 'Salta (nessuna modifica)'
            $script:Msg.CustomUpdateOpt    = 'Aggiorna il modello Hablará'
            $script:Msg.CustomUpdatePrompt = 'Selezione [1-2, Invio=1]'
            $script:Msg.CustomKept         = 'Modello Hablará conservato'
            $script:Msg.CustomPresent      = 'Modello Hablará già presente'
            $script:Msg.UsingHablaraConf   = 'Utilizzo della configurazione Hablará'
            $script:Msg.UsingDefaultConf   = 'Utilizzo della configurazione predefinita'
            $script:Msg.ConfigReadError    = 'Impossibile leggere la configurazione: {0}'
            $script:Msg.CustomCreating      = 'Creazione del modello Hablará {0}...'
            $script:Msg.CustomCreateTO     = 'ollama create ha superato il tempo massimo di 120s — utilizzo del modello base'
            $script:Msg.CustomCreateFail   = 'Il modello Hablará non ha potuto essere {0} - utilizzo del modello base'
            $script:Msg.CustomDone         = 'Modello Hablará {0}: {1}'
            $script:Msg.ConfigError        = 'Errore di configurazione'
            $script:Msg.PermsWarn          = 'Impossibile impostare autorizzazioni restrittive: {0}'
            $script:Msg.VerbCreated        = 'creato'
            $script:Msg.VerbUpdated        = 'aggiornato'
            # Verify
            $script:Msg.Verifying          = "Verifica dell'installazione..."
            $script:Msg.OllamaNotFound     = 'Ollama non trovato'
            $script:Msg.ServerUnreachable  = 'Server Ollama non raggiungibile'
            $script:Msg.BaseNotFound       = 'Modello base non trovato: {0}'
            $script:Msg.BaseOk             = 'Modello base disponibile: {0}'
            $script:Msg.CustomOk           = 'Modello Hablará disponibile: {0}'
            $script:Msg.CustomUnavail      = 'Modello Hablará non disponibile (utilizzo del modello base)'
            $script:Msg.InferenceFailed    = "Test del modello fallito, testare nell'app"
            $script:Msg.SetupDone          = 'Configurazione completata!'
            # Main Summary
            $script:Msg.SetupComplete      = 'Configurazione Ollama Hablará completata!'
            $script:Msg.Installed          = 'Installato:'
            $script:Msg.BaseModelLabel     = '  Modello base:    '
            $script:Msg.HablaraModelLabel  = '  Modello Hablará: '
            $script:Msg.OllamaConfig       = 'Configurazione Ollama:'
            $script:Msg.ModelLabel         = '  Modello:   '
            $script:Msg.BaseUrlLabel       = '  Base URL: '
            $script:Msg.Docs               = 'Documentazione: https://github.com/fidpa/hablara'
            # Misc
            $script:Msg.TestModel          = 'Test del modello...'
            $script:Msg.TestOk             = 'Test del modello riuscito'
            $script:Msg.TestFail           = 'Test del modello fallito'
            $script:Msg.WaitServer         = 'In attesa del server Ollama...'
            $script:Msg.ServerReady        = 'Il server Ollama è pronto'
            $script:Msg.ServerAlready      = 'Il server Ollama è già in esecuzione'
            $script:Msg.ServerNoResponse   = 'Il server Ollama non risponde dopo {0}s'
            $script:Msg.SetupFailed        = 'Configurazione fallita'
            $script:Msg.OllamaListTimeout  = 'ollama list ha superato il tempo massimo (15s) durante il controllo del modello'
            # Cleanup
            $script:Msg.CleanupNeedsTTY    = '-Cleanup richiede una sessione interattiva'
            $script:Msg.CleanupNoOllama    = 'Ollama non trovato'
            $script:Msg.CleanupNoServer    = 'Server Ollama non raggiungibile'
            $script:Msg.CleanupStartHint   = 'Avvia Ollama e riprova'
            $script:Msg.CleanupInstalled   = 'Varianti Hablará installate:'
            $script:Msg.CleanupPrompt      = 'Quale variante eliminare? (numero, Invio=annulla)'
            $script:Msg.CleanupInvalid     = 'Selezione non valida'
            $script:Msg.CleanupDeleted     = '{0} eliminato'
            $script:Msg.CleanupTimeout     = '{0} non ha potuto essere eliminato: tempo massimo superato (30s)'
            $script:Msg.CleanupFailed      = '{0} non ha potuto essere eliminato: {1}'
            $script:Msg.CleanupUnknownErr  = 'errore sconosciuto'
            $script:Msg.CleanupNoneLeft    = 'Nessun modello Hablará più installato. Esegui di nuovo il setup per installare un modello.'
            $script:Msg.CleanupNoModels    = 'Nessun modello Hablará trovato.'
            # Help
            $script:Msg.HelpTitle          = 'Hablará Ollama Setup v{0} (Windows)'
            $script:Msg.HelpDescription    = '  Installa Ollama e configura un modello Hablará ottimizzato.'
            $script:Msg.HelpUsage          = 'Utilizzo:'
            $script:Msg.HelpUsageLine      = '  .\setup-ollama-win.ps1 [OPZIONI]'
            $script:Msg.HelpOptions        = 'Opzioni:'
            $script:Msg.HelpOptModel       = '  -Model VARIANTE       Scegli la variante: 1.5b, 3b, 7b, qwen3-8b (predefinito: 3b)'
            $script:Msg.HelpOptUpdate      = '  -Update               Ricreare il modello Hablará (aggiornare il Modelfile)'
            $script:Msg.HelpOptStatus      = "  -Status               Verifica: controllo in 7 punti dell'installazione Ollama"
            $script:Msg.HelpOptDiagnose    = '  -Diagnose             Generare rapporto di supporto (testo normale, copiabile)'
            $script:Msg.HelpOptCleanup     = '  -Cleanup              Eliminare interattivamente la variante installata'
            $script:Msg.HelpOptLang        = '  -Lang da|de|en|es|fr|it|nl|pl|pt|sv  Lingua (da=Danese, de=Tedesco, en=Inglese, es=Spagnolo, fr=Francese, it=Italiano, nl=Olandese, pl=Polacco, pt=Portoghese, sv=Svedese)'
            $script:Msg.HelpOptHelp        = '  -Help                 Mostrare questa guida'
            $script:Msg.HelpNoOpts         = '  Senza opzioni, viene avviato un menu interattivo.'
            $script:Msg.HelpVariants       = 'Varianti del modello:'
            $script:Msg.HelpExamples       = 'Esempi:'
            $script:Msg.HelpExModel        = '  .\setup-ollama-win.ps1 -Model 3b       Installare la variante 3b'
            $script:Msg.HelpExUpdate       = '  .\setup-ollama-win.ps1 -Update         Aggiornare il modello personalizzato'
            $script:Msg.HelpExStatus       = "  .\setup-ollama-win.ps1 -Status         Verificare l'installazione"
            $script:Msg.HelpExDiagnose     = '  .\setup-ollama-win.ps1 -Diagnose       Creare rapporto di bug'
            $script:Msg.HelpExCleanup      = '  .\setup-ollama-win.ps1 -Cleanup        Rimuovere la variante'
            $script:Msg.HelpExitCodes      = 'Codici di uscita:'
            $script:Msg.HelpExit0          = '  0  Successo'
            $script:Msg.HelpExit1          = '  1  Errore generale'
            $script:Msg.HelpExit2          = '  2  Spazio su disco insufficiente'
            $script:Msg.HelpExit3          = '  3  Nessuna connessione di rete'
            $script:Msg.HelpExit4          = '  4  Piattaforma errata'
            $script:Msg.AutoInstallFailed  = 'Ollama non ha potuto essere installato automaticamente'
            # Hardware Detection
            $script:Msg.HwDetectionHeader  = 'Rilevamento hardware:'
            $script:Msg.HwBandwidth        = 'Larghezza di banda memoria: ~{0} GB/s · {1} GB RAM'
            $script:Msg.HwRecommendation   = 'Raccomandazione modello per il tuo hardware:'
            $script:Msg.HwLocalTooSlow     = 'I modelli locali saranno lenti su questo hardware'
            $script:Msg.HwCloudHint        = 'Raccomandazione: API OpenAI o Anthropic per la migliore esperienza'
            $script:Msg.HwProceedLocal     = 'Installare localmente comunque? [s/N]'
            $script:Msg.HwTagRecommended   = 'raccomandato'
            $script:Msg.HwTagSlow          = 'lento'
            $script:Msg.HwTagTooSlow       = 'troppo lento'
            $script:Msg.ChoicePromptHw     = 'Scelta [1-4, Invio={0}]'
            $script:Msg.HwUnknownChip      = 'Processore sconosciuto — nessuna raccomandazione di banda possibile'
            $script:Msg.HwMultiCallHint   = 'Hablará esegue più fasi di analisi per registrazione'
            # Benchmark
            $script:Msg.BenchResult        = 'Benchmark: ~{0} tok/s con {1}'
            $script:Msg.BenchExcellent     = 'Eccellente — il tuo hardware gestisce questo modello con facilità'
            $script:Msg.BenchGood          = 'Buono — questo modello funziona bene sul tuo hardware'
            $script:Msg.BenchMarginal      = 'Marginale — un modello più piccolo offre un''esperienza più fluida'
            $script:Msg.BenchTooSlow       = 'Troppo lento — si consiglia un modello più piccolo o un provider cloud'
            $script:Msg.BenchSkip          = 'Benchmark saltato (misurazione fallita)'
        }
        'nl' {
            $script:Msg.ErrorPrefix        = 'Fout'
            # Model Menu
            $script:Msg.ChooseModel        = 'Kies een model:'
            $script:Msg.ChoicePrompt       = 'Keuze [1-4, Enter=1]'
            $script:Msg.Model3B            = 'Optimale algehele prestaties [Standaard]'
            $script:Msg.Model1_5B          = 'Snel, beperkte nauwkeurigheid [Instap]'
            $script:Msg.Model7B            = 'Vereist krachtige hardware'
            $script:Msg.ModelQwen3         = 'Beste argumentatieanalyse [Premium]'
            # Main Menu
            $script:Msg.ChooseAction       = 'Kies een actie:'
            $script:Msg.ActionSetup        = 'Ollama instellen of bijwerken'
            $script:Msg.ActionStatus       = 'Status controleren'
            $script:Msg.ActionDiagnose     = 'Diagnose (ondersteuningsrapport)'
            $script:Msg.ActionCleanup      = 'Modellen opruimen'
            $script:Msg.ActionPrompt       = 'Keuze [1-4, Enter=1]'
            # Select Model
            $script:Msg.InvalidModel       = 'Ongeldige modelvariante: {0}'
            $script:Msg.ValidVariants      = 'Geldige varianten: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b'
            $script:Msg.RamWarnModel       = 'Dit model vereist minimaal {0}GB RAM'
            $script:Msg.RamWarnSys         = 'Uw systeem heeft {0}GB RAM'
            $script:Msg.ContinueAnyway     = 'Toch doorgaan?'
            $script:Msg.ConfirmPrompt      = '[j/N]'
            $script:Msg.ConfirmPattern     = '^[jJyY]$'
            $script:Msg.Aborted            = 'Afgebroken.'
            $script:Msg.SelectedModel      = 'Geselecteerd model: {0}'
            $script:Msg.ProceedNonInteract = 'Doorgaan...'
            $script:Msg.InternalError      = 'Interne fout: ModelName niet ingesteld'
            # Preflight
            $script:Msg.Preflight          = 'Voorafgaande controles uitvoeren...'
            $script:Msg.PlatformError      = 'Dit script is alleen voor Windows'
            $script:Msg.PlatformMacHint    = 'Voor macOS: scripts/setup-ollama-mac.sh'
            $script:Msg.PlatformLinuxHint  = 'Voor Linux: scripts/setup-ollama-linux.sh'
            $script:Msg.DiskInsufficient   = 'Onvoldoende schijfruimte: {0}GB beschikbaar, {1}GB vereist'
            $script:Msg.DiskOk             = 'Schijfruimte: {0}GB beschikbaar'
            $script:Msg.NetworkError       = 'Geen netwerkverbinding met ollama.com'
            $script:Msg.NetworkHint        = 'Controleer: Invoke-WebRequest -Uri https://ollama.com'
            $script:Msg.NetworkOk          = 'Netwerkverbinding OK'
            $script:Msg.GpuDetected        = 'GPU gedetecteerd: {0}'
            $script:Msg.GpuNone            = 'Geen GPU gedetecteerd - verwerking zonder GPU-versnelling'
            # Status
            $script:Msg.StatusTitle        = 'Hablará Ollama Status (Windows)'
            $script:Msg.StatusInstalled    = 'Ollama geïnstalleerd (v{0})'
            $script:Msg.StatusUpdateRec    = '    {0} Update aanbevolen (minimaal v{1}): winget upgrade Ollama.Ollama'
            $script:Msg.StatusNotFound     = 'Ollama niet gevonden'
            $script:Msg.StatusServerOk     = 'Server actief'
            $script:Msg.StatusServerFail   = 'Server niet bereikbaar'
            $script:Msg.StatusGpuNvidia    = 'NVIDIA (CUDA-versnelling)'
            $script:Msg.StatusGpuAmd       = 'AMD (ROCm-versnelling, experimenteel)'
            $script:Msg.StatusNoGpu        = 'Geen GPU — verwerking zonder GPU-versnelling'
            $script:Msg.StatusBaseModel    = 'Basismodel: {0}'
            $script:Msg.StatusBaseModels   = 'Basismodellen:'
            $script:Msg.StatusNoBase       = 'Geen basismodel gevonden'
            $script:Msg.StatusHablaraModel = 'Hablará-model: {0}'
            $script:Msg.StatusHablaraModels= 'Hablará-modellen:'
            $script:Msg.StatusNoHablara    = 'Geen Hablará-model gevonden'
            $script:Msg.StatusBaseMissing  = '    {0} Basismodel ontbreekt — Hablará-model heeft dit als basis nodig'
            $script:Msg.StatusInfSkip      = 'Modeltest overgeslagen (server niet bereikbaar)'
            $script:Msg.StatusModelOk      = 'Model reageert'
            $script:Msg.StatusModelFail    = 'Model reageert niet'
            $script:Msg.StatusStorage      = 'Opslaggebruik (Hablará): ~{0} GB'
            $script:Msg.StatusStorageUnk   = 'Opslaggebruik: niet te bepalen'
            $script:Msg.StatusAllOk        = 'Alles is in orde.'
            $script:Msg.StatusProblems     = '{0} probleem/problemen gevonden.'
            $script:Msg.StatusRepair       = '    Repareren: .\setup-ollama-win.ps1'
            # Diagnose
            $script:Msg.DiagnoseTitle      = '=== Hablará Ollama Diagnoserapport ==='
            $script:Msg.DiagnoseSystem     = 'Systeem:'
            $script:Msg.DiagnoseOllama     = 'Ollama:'
            $script:Msg.DiagnoseModels     = 'Hablará-modellen:'
            $script:Msg.DiagnoseStorage    = 'Opslag (Hablará):'
            $script:Msg.DiagnoseLog        = 'Ollama-log (recente fouten):'
            $script:Msg.DiagnoseCreated    = 'Aangemaakt:'
            $script:Msg.DiagnoseScript     = 'Script:'
            $script:Msg.DiagnoseSaved      = 'Rapport opgeslagen: {0}'
            $script:Msg.DiagnoseSaveFailed = 'Rapport kon niet worden opgeslagen'
            $script:Msg.DiagnoseRamAvail   = 'beschikbaar'
            $script:Msg.DiagnoseStorFree   = 'vrij'
            $script:Msg.DiagnoseStorDisk   = 'Opslag:'
            $script:Msg.DiagnoseUnknown    = 'onbekend'
            $script:Msg.DiagnoseNotInst    = 'niet geïnstalleerd'
            $script:Msg.DiagnoseNotReach   = 'niet bereikbaar'
            $script:Msg.DiagnoseRunning    = 'actief'
            $script:Msg.DiagnoseNoModels   = '    [geen Hablará-modellen gevonden]'
            $script:Msg.DiagnoseNoErrors   = '    [geen fouten gevonden]'
            $script:Msg.DiagnoseNoLog      = '    [logbestand niet gevonden: {0}]'
            $script:Msg.DiagnoseLogUnread  = '    [logbestand niet leesbaar: {0}]'
            $script:Msg.DiagnoseGpuNone    = 'Geen'
            $script:Msg.DiagnoseResponds   = '(reageert)'
            # Install
            $script:Msg.Installing         = 'Ollama installeren...'
            $script:Msg.OllamaAlready      = 'Ollama is al geïnstalleerd'
            $script:Msg.OllamaVersion      = 'Versie: {0}'
            $script:Msg.ServerStartFailed  = 'Kon de Ollama-server niet starten'
            $script:Msg.ServerStartHint    = 'Handmatig starten: ollama serve'
            $script:Msg.UsingWinget        = 'winget gebruiken (time-out: 10 minuten)...'
            $script:Msg.WingetTimeout      = 'winget install time-out na 10 minuten'
            $script:Msg.WingetFailed       = 'winget-installatie mislukt: {0}'
            $script:Msg.OllamaInstalled    = 'Ollama geïnstalleerd via winget'
            $script:Msg.WaitForAutoStart   = 'Wachten op automatische start van de Ollama-app...'
            $script:Msg.RebootRequired     = 'Mogelijk is een herstart van de computer vereist'
            $script:Msg.OllamaPathError    = 'Ollama geïnstalleerd maar CLI niet in PATH. Open een nieuwe terminal of controleer PATH.'
            $script:Msg.ServerStartWarn    = 'Server starten mislukt - handmatig starten: ollama serve'
            $script:Msg.ManualInstall      = 'Installeer Ollama handmatig: https://ollama.com/download'
            $script:Msg.ManualRerun        = 'Voer dit script daarna opnieuw uit.'
            $script:Msg.OllamaFound        = 'Ollama gevonden: {0}'
            $script:Msg.OllamaAppStart     = 'Ollama-app starten...'
            $script:Msg.OllamaServeStart   = 'Ollama-server starten (ollama serve)...'
            $script:Msg.OllamaProcessExit  = 'Ollama-proces afgesloten (code: {0})'
            $script:Msg.PortBusy           = 'Poort 11434 is bezet, wachten op Ollama API...'
            $script:Msg.PortBusyWarn       = 'Poort 11434 bezet maar Ollama API reageert niet'
            $script:Msg.VersionWarn        = 'Ollama versie {0} is ouder dan aanbevolen ({1})'
            $script:Msg.UpdateHint         = 'Bijwerken: winget upgrade Ollama.Ollama'
            # Model Download
            $script:Msg.DownloadingBase    = 'Basismodel downloaden...'
            $script:Msg.ModelExists        = 'Model al aanwezig: {0}'
            $script:Msg.DownloadingModel   = '{0} downloaden ({1}, duurt enkele minuten afhankelijk van de verbinding)...'
            $script:Msg.DownloadResumeTip  = 'Tip: Bij onderbreking (Ctrl+C) wordt de download hervat bij opnieuw starten'
            $script:Msg.DownloadHardTimeout= 'Harde time-out na {0} minuten — afbreken'
            $script:Msg.DownloadStall      = 'Geen downloadvoortgang in {0} minuten — afbreken'
            $script:Msg.DownloadRunning    = '  Download actief... ({0}m {1}s)'
            $script:Msg.DownloadTimeoutW   = 'Download time-out na {0} minuten (poging {1}/3)'
            $script:Msg.DownloadFailedW    = 'Download mislukt (poging {0}/3)'
            $script:Msg.DownloadRetry      = 'Volgende poging in 5s...'
            $script:Msg.DownloadFailed     = 'Modeldownload mislukt na 3 pogingen'
            $script:Msg.DownloadManual     = 'Handmatig proberen: ollama pull {0}'
            $script:Msg.DownloadDone       = 'Model gedownload: {0}'
            # Custom Model
            $script:Msg.CreatingCustom     = 'Hablará-model aanmaken...'
            $script:Msg.UpdatingCustom     = 'Bestaand Hablará-model bijwerken...'
            $script:Msg.CustomExists       = 'Hablará-model {0} al aanwezig.'
            $script:Msg.CustomSkip         = 'Overslaan (geen wijziging)'
            $script:Msg.CustomUpdateOpt    = 'Hablará-model bijwerken'
            $script:Msg.CustomUpdatePrompt = 'Keuze [1-2, Enter=1]'
            $script:Msg.CustomKept         = 'Hablará-model behouden'
            $script:Msg.CustomPresent      = 'Hablará-model al aanwezig'
            $script:Msg.UsingHablaraConf   = 'Hablará-configuratie gebruiken'
            $script:Msg.UsingDefaultConf   = 'Standaardconfiguratie gebruiken'
            $script:Msg.ConfigReadError    = 'Configuratie kon niet worden gelezen: {0}'
            $script:Msg.CustomCreating      = 'Hablará-model {0} aanmaken...'
            $script:Msg.CustomCreateTO     = 'ollama create time-out na 120s — basismodel gebruiken'
            $script:Msg.CustomCreateFail   = 'Hablará-model kon niet worden {0} - basismodel gebruiken'
            $script:Msg.CustomDone         = 'Hablará-model {0}: {1}'
            $script:Msg.ConfigError        = 'Configuratiefout'
            $script:Msg.PermsWarn          = 'Konden geen beperkende rechten instellen: {0}'
            $script:Msg.VerbCreated        = 'aangemaakt'
            $script:Msg.VerbUpdated        = 'bijgewerkt'
            # Verify
            $script:Msg.Verifying          = 'Installatie controleren...'
            $script:Msg.OllamaNotFound     = 'Ollama niet gevonden'
            $script:Msg.ServerUnreachable  = 'Ollama-server niet bereikbaar'
            $script:Msg.BaseNotFound       = 'Basismodel niet gevonden: {0}'
            $script:Msg.BaseOk             = 'Basismodel beschikbaar: {0}'
            $script:Msg.CustomOk           = 'Hablará-model beschikbaar: {0}'
            $script:Msg.CustomUnavail      = 'Hablará-model niet beschikbaar (basismodel gebruiken)'
            $script:Msg.InferenceFailed    = 'Modeltest mislukt, testen in de app'
            $script:Msg.SetupDone          = 'Installatie voltooid!'
            # Main Summary
            $script:Msg.SetupComplete      = 'Hablará Ollama-installatie voltooid!'
            $script:Msg.Installed          = 'Geïnstalleerd:'
            $script:Msg.BaseModelLabel     = '  Basismodel:      '
            $script:Msg.HablaraModelLabel  = '  Hablará-model:   '
            $script:Msg.OllamaConfig       = 'Ollama-configuratie:'
            $script:Msg.ModelLabel         = '  Model:    '
            $script:Msg.BaseUrlLabel       = '  Base URL: '
            $script:Msg.Docs               = 'Documentatie: https://github.com/fidpa/hablara'
            # Misc
            $script:Msg.TestModel          = 'Model testen...'
            $script:Msg.TestOk             = 'Modeltest geslaagd'
            $script:Msg.TestFail           = 'Modeltest mislukt'
            $script:Msg.WaitServer         = 'Wachten op Ollama-server...'
            $script:Msg.ServerReady        = 'Ollama-server is gereed'
            $script:Msg.ServerAlready      = 'Ollama-server is al actief'
            $script:Msg.ServerNoResponse   = 'Ollama-server reageert niet na {0}s'
            $script:Msg.SetupFailed        = 'Installatie mislukt'
            $script:Msg.OllamaListTimeout  = 'ollama list time-out (15s) bij modelcontrole'
            # Cleanup
            $script:Msg.CleanupNeedsTTY    = '-Cleanup vereist een interactieve sessie'
            $script:Msg.CleanupNoOllama    = 'Ollama niet gevonden'
            $script:Msg.CleanupNoServer    = 'Ollama-server niet bereikbaar'
            $script:Msg.CleanupStartHint   = 'Start Ollama en probeer opnieuw'
            $script:Msg.CleanupInstalled   = 'Geïnstalleerde Hablará-varianten:'
            $script:Msg.CleanupPrompt      = 'Welke variant verwijderen? (nummer, Enter=annuleren)'
            $script:Msg.CleanupInvalid     = 'Ongeldige selectie'
            $script:Msg.CleanupDeleted     = '{0} verwijderd'
            $script:Msg.CleanupTimeout     = '{0} kon niet worden verwijderd: Time-out (30s)'
            $script:Msg.CleanupFailed      = '{0} kon niet worden verwijderd: {1}'
            $script:Msg.CleanupUnknownErr  = 'onbekende fout'
            $script:Msg.CleanupNoneLeft    = 'Geen Hablará-modellen meer geïnstalleerd. Voer de installatie opnieuw uit om een model te installeren.'
            $script:Msg.CleanupNoModels    = 'Geen Hablará-modellen gevonden.'
            # Help
            $script:Msg.HelpTitle          = 'Hablará Ollama Setup v{0} (Windows)'
            $script:Msg.HelpDescription    = '  Installeert Ollama en configureert een geoptimaliseerd Hablará-model.'
            $script:Msg.HelpUsage          = 'Gebruik:'
            $script:Msg.HelpUsageLine      = '  .\setup-ollama-win.ps1 [OPTIES]'
            $script:Msg.HelpOptions        = 'Opties:'
            $script:Msg.HelpOptModel       = '  -Model VARIANT        Modelvariante kiezen: 1.5b, 3b, 7b, qwen3-8b (standaard: 3b)'
            $script:Msg.HelpOptUpdate      = '  -Update               Hablará-aangepast model opnieuw aanmaken (Modelfile bijwerken)'
            $script:Msg.HelpOptStatus      = '  -Status               Statuscontrole: 7-punts controle van de Ollama-installatie'
            $script:Msg.HelpOptDiagnose    = '  -Diagnose             Ondersteuningsrapport genereren (platte tekst, kopieerbaar)'
            $script:Msg.HelpOptCleanup     = '  -Cleanup              Geïnstalleerde variant interactief verwijderen'
            $script:Msg.HelpOptLang        = '  -Lang da|de|en|es|fr|it|nl|pl|pt|sv  Taal (da=Deens, de=Duits, en=Engels, es=Spaans, fr=Frans, it=Italiaans, nl=Nederlands, pl=Pools, pt=Portugees, sv=Zweeds)'
            $script:Msg.HelpOptHelp        = '  -Help                 Deze help weergeven'
            $script:Msg.HelpNoOpts         = '  Zonder opties wordt een interactief menu gestart.'
            $script:Msg.HelpVariants       = 'Modelvarianten:'
            $script:Msg.HelpExamples       = 'Voorbeelden:'
            $script:Msg.HelpExModel        = '  .\setup-ollama-win.ps1 -Model 3b       3b-variant installeren'
            $script:Msg.HelpExUpdate       = '  .\setup-ollama-win.ps1 -Update         Aangepast model bijwerken'
            $script:Msg.HelpExStatus       = '  .\setup-ollama-win.ps1 -Status         Installatie controleren'
            $script:Msg.HelpExDiagnose     = '  .\setup-ollama-win.ps1 -Diagnose       Bugrapport aanmaken'
            $script:Msg.HelpExCleanup      = '  .\setup-ollama-win.ps1 -Cleanup        Variant verwijderen'
            $script:Msg.HelpExitCodes      = 'Afsluitcodes:'
            $script:Msg.HelpExit0          = '  0  Geslaagd'
            $script:Msg.HelpExit1          = '  1  Algemene fout'
            $script:Msg.HelpExit2          = '  2  Onvoldoende schijfruimte'
            $script:Msg.HelpExit3          = '  3  Geen netwerkverbinding'
            $script:Msg.HelpExit4          = '  4  Verkeerd platform'
            $script:Msg.AutoInstallFailed  = 'Ollama kon niet automatisch worden geïnstalleerd'
            # Hardware Detection
            $script:Msg.HwDetectionHeader  = 'Hardware-detectie:'
            $script:Msg.HwBandwidth        = 'Geheugenbandbreedte: ~{0} GB/s · {1} GB RAM'
            $script:Msg.HwRecommendation   = 'Modelaanbeveling voor jouw hardware:'
            $script:Msg.HwLocalTooSlow     = 'Lokale modellen zullen traag zijn op deze hardware'
            $script:Msg.HwCloudHint        = 'Aanbeveling: OpenAI of Anthropic API voor de beste ervaring'
            $script:Msg.HwProceedLocal     = 'Toch lokaal installeren? [j/N]'
            $script:Msg.HwTagRecommended   = 'aanbevolen'
            $script:Msg.HwTagSlow          = 'traag'
            $script:Msg.HwTagTooSlow       = 'te traag'
            $script:Msg.ChoicePromptHw     = 'Keuze [1-4, Enter={0}]'
            $script:Msg.HwUnknownChip      = 'Onbekende processor — geen bandbreedteaanbeveling mogelijk'
            $script:Msg.HwMultiCallHint   = 'Hablará voert meerdere analysestappen per opname uit'
            # Benchmark
            $script:Msg.BenchResult        = 'Benchmark: ~{0} tok/s met {1}'
            $script:Msg.BenchExcellent     = 'Uitstekend — jouw hardware verwerkt dit model moeiteloos'
            $script:Msg.BenchGood          = 'Goed — dit model draait goed op jouw hardware'
            $script:Msg.BenchMarginal      = 'Marginaal — een kleiner model zorgt voor een vloeiendere ervaring'
            $script:Msg.BenchTooSlow       = 'Te traag — een kleiner model of cloud-aanbieder wordt aanbevolen'
            $script:Msg.BenchSkip          = 'Benchmark overgeslagen (meting mislukt)'
        }
        'pt' {
            $script:Msg.ErrorPrefix        = 'Erro'
            # Model Menu
            $script:Msg.ChooseModel        = 'Escolha um modelo:'
            $script:Msg.ChoicePrompt       = 'Opção [1-4, Enter=1]'
            $script:Msg.Model3B            = 'Melhor desempenho geral [Padrão]'
            $script:Msg.Model1_5B          = 'Rápido, precisão limitada [Básico]'
            $script:Msg.Model7B            = 'Requer hardware potente'
            $script:Msg.ModelQwen3         = 'Melhor análise de argumentação [Premium]'
            # Main Menu
            $script:Msg.ChooseAction       = 'Escolha uma ação:'
            $script:Msg.ActionSetup        = 'Instalar ou atualizar o Ollama'
            $script:Msg.ActionStatus       = 'Verificar status'
            $script:Msg.ActionDiagnose     = 'Diagnóstico (relatório de suporte)'
            $script:Msg.ActionCleanup      = 'Limpar modelos'
            $script:Msg.ActionPrompt       = 'Opção [1-4, Enter=1]'
            # Select Model
            $script:Msg.InvalidModel       = 'Variante de modelo inválida: {0}'
            $script:Msg.ValidVariants      = 'Variantes válidas: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b'
            $script:Msg.RamWarnModel       = 'Este modelo requer pelo menos {0}GB de RAM'
            $script:Msg.RamWarnSys         = 'O seu sistema tem {0}GB de RAM'
            $script:Msg.ContinueAnyway     = 'Continuar mesmo assim?'
            $script:Msg.ConfirmPrompt      = '[s/N]'
            $script:Msg.ConfirmPattern     = '^[sS]$'
            $script:Msg.Aborted            = 'Cancelado.'
            $script:Msg.SelectedModel      = 'Modelo selecionado: {0}'
            $script:Msg.ProceedNonInteract = 'A continuar...'
            $script:Msg.InternalError      = 'Erro interno: ModelName não definido'
            # Preflight
            $script:Msg.Preflight          = 'Executando verificações iniciais...'
            $script:Msg.PlatformError      = 'Este script é apenas para Windows'
            $script:Msg.PlatformMacHint    = 'Para macOS: scripts/setup-ollama-mac.sh'
            $script:Msg.PlatformLinuxHint  = 'Para Linux: scripts/setup-ollama-linux.sh'
            $script:Msg.DiskInsufficient   = 'Espaço em disco insuficiente: {0}GB disponíveis, {1}GB necessários'
            $script:Msg.DiskOk             = 'Espaço em disco: {0}GB disponíveis'
            $script:Msg.NetworkError       = 'Sem ligação à rede para ollama.com'
            $script:Msg.NetworkHint        = 'Verificar: Invoke-WebRequest -Uri https://ollama.com'
            $script:Msg.NetworkOk          = 'Ligação à rede OK'
            $script:Msg.GpuDetected        = 'GPU detetada: {0}'
            $script:Msg.GpuNone            = 'Nenhuma GPU detetada - processamento sem aceleração de GPU'
            # Status
            $script:Msg.StatusTitle        = 'Hablará Ollama Status (Windows)'
            $script:Msg.StatusInstalled    = 'Ollama instalado (v{0})'
            $script:Msg.StatusUpdateRec    = '    {0} Atualização recomendada (mínimo v{1}): winget upgrade Ollama.Ollama'
            $script:Msg.StatusNotFound     = 'Ollama não encontrado'
            $script:Msg.StatusServerOk     = 'Servidor em execução'
            $script:Msg.StatusServerFail   = 'Servidor inacessível'
            $script:Msg.StatusGpuNvidia    = 'NVIDIA (aceleração CUDA)'
            $script:Msg.StatusGpuAmd       = 'AMD (aceleração ROCm, experimental)'
            $script:Msg.StatusNoGpu        = 'Sem GPU — processamento sem aceleração de GPU'
            $script:Msg.StatusBaseModel    = 'Modelo base: {0}'
            $script:Msg.StatusBaseModels   = 'Modelos base:'
            $script:Msg.StatusNoBase       = 'Nenhum modelo base encontrado'
            $script:Msg.StatusHablaraModel = 'Modelo Hablará: {0}'
            $script:Msg.StatusHablaraModels= 'Modelos Hablará:'
            $script:Msg.StatusNoHablara    = 'Nenhum modelo Hablará encontrado'
            $script:Msg.StatusBaseMissing  = '    {0} Modelo base em falta — o modelo Hablará necessita dele como base'
            $script:Msg.StatusInfSkip      = 'Teste do modelo ignorado (servidor inacessível)'
            $script:Msg.StatusModelOk      = 'Modelo responde'
            $script:Msg.StatusModelFail    = 'Modelo não responde'
            $script:Msg.StatusStorage      = 'Uso de armazenamento (Hablará): ~{0} GB'
            $script:Msg.StatusStorageUnk   = 'Uso de armazenamento: não determinável'
            $script:Msg.StatusAllOk        = 'Tudo está em ordem.'
            $script:Msg.StatusProblems     = '{0} problema(s) encontrado(s).'
            $script:Msg.StatusRepair       = '    Reparar: .\setup-ollama-win.ps1'
            # Diagnose
            $script:Msg.DiagnoseTitle      = '=== Relatório de Diagnóstico Ollama do Hablará ==='
            $script:Msg.DiagnoseSystem     = 'Sistema:'
            $script:Msg.DiagnoseOllama     = 'Ollama:'
            $script:Msg.DiagnoseModels     = 'Modelos Hablará:'
            $script:Msg.DiagnoseStorage    = 'Armazenamento (Hablará):'
            $script:Msg.DiagnoseLog        = 'Registo do Ollama (erros recentes):'
            $script:Msg.DiagnoseCreated    = 'Criado:'
            $script:Msg.DiagnoseScript     = 'Script:'
            $script:Msg.DiagnoseSaved      = 'Relatório guardado: {0}'
            $script:Msg.DiagnoseSaveFailed = 'Não foi possível guardar o relatório'
            $script:Msg.DiagnoseRamAvail   = 'disponível'
            $script:Msg.DiagnoseStorFree   = 'livre'
            $script:Msg.DiagnoseStorDisk   = 'Armazenamento:'
            $script:Msg.DiagnoseUnknown    = 'desconhecido'
            $script:Msg.DiagnoseNotInst    = 'não instalado'
            $script:Msg.DiagnoseNotReach   = 'inacessível'
            $script:Msg.DiagnoseRunning    = 'em execução'
            $script:Msg.DiagnoseNoModels   = '    [nenhum modelo Hablará encontrado]'
            $script:Msg.DiagnoseNoErrors   = '    [nenhum erro encontrado]'
            $script:Msg.DiagnoseNoLog      = '    [ficheiro de registo não encontrado: {0}]'
            $script:Msg.DiagnoseLogUnread  = '    [ficheiro de registo não legível: {0}]'
            $script:Msg.DiagnoseGpuNone    = 'Nenhuma'
            $script:Msg.DiagnoseResponds   = '(responde)'
            # Install
            $script:Msg.Installing         = 'A instalar o Ollama...'
            $script:Msg.OllamaAlready      = 'O Ollama já está instalado'
            $script:Msg.OllamaVersion      = 'Versão: {0}'
            $script:Msg.ServerStartFailed  = 'Não foi possível iniciar o servidor Ollama'
            $script:Msg.ServerStartHint    = 'Iniciar manualmente: ollama serve'
            $script:Msg.UsingWinget        = 'A utilizar winget (tempo limite: 10 minutos)...'
            $script:Msg.WingetTimeout      = 'winget install atingiu o tempo limite de 10 minutos'
            $script:Msg.WingetFailed       = 'winget falhou: {0}'
            $script:Msg.OllamaInstalled    = 'Ollama instalado via winget'
            $script:Msg.WaitForAutoStart   = 'Aguardando o início automático da app Ollama...'
            $script:Msg.RebootRequired     = 'Pode ser necessário reiniciar o computador'
            $script:Msg.OllamaPathError    = 'Ollama instalado mas CLI não está no PATH. Abra um novo terminal ou verifique o PATH.'
            $script:Msg.ServerStartWarn    = 'Falha ao iniciar o servidor - iniciar manualmente: ollama serve'
            $script:Msg.ManualInstall      = 'Instale o Ollama manualmente: https://ollama.com/download'
            $script:Msg.ManualRerun        = 'Depois execute este script novamente.'
            $script:Msg.OllamaFound        = 'Ollama encontrado: {0}'
            $script:Msg.OllamaAppStart     = 'A iniciar a aplicação Ollama...'
            $script:Msg.OllamaServeStart   = 'A iniciar o servidor Ollama (ollama serve)...'
            $script:Msg.OllamaProcessExit  = 'Processo Ollama encerrado (código: {0})'
            $script:Msg.PortBusy           = 'Porta 11434 ocupada, a aguardar a API do Ollama...'
            $script:Msg.PortBusyWarn       = 'Porta 11434 ocupada mas a API do Ollama não responde'
            $script:Msg.VersionWarn        = 'Ollama versão {0} é mais antiga que a recomendada ({1})'
            $script:Msg.UpdateHint         = 'Atualizar: winget upgrade Ollama.Ollama'
            # Model Download
            $script:Msg.DownloadingBase    = 'A descarregar o modelo base...'
            $script:Msg.ModelExists        = 'Modelo já disponível: {0}'
            $script:Msg.DownloadingModel   = 'A descarregar {0} ({1}, pode demorar alguns minutos dependendo da ligação)...'
            $script:Msg.DownloadResumeTip  = 'Dica: Se interrompido (Ctrl+C), o descarregamento será retomado ao reiniciar'
            $script:Msg.DownloadHardTimeout= 'Tempo limite rígido de {0} minutos atingido — a cancelar'
            $script:Msg.DownloadStall      = 'Nenhum progresso no descarregamento em {0} minutos — a cancelar'
            $script:Msg.DownloadRunning    = '  Descarregamento em curso... ({0}m {1}s)'
            $script:Msg.DownloadTimeoutW   = 'Tempo limite do descarregamento após {0} minutos (tentativa {1}/3)'
            $script:Msg.DownloadFailedW    = 'Descarregamento falhou (tentativa {0}/3)'
            $script:Msg.DownloadRetry      = 'Próxima tentativa em 5s...'
            $script:Msg.DownloadFailed     = 'Descarregamento do modelo falhou após 3 tentativas'
            $script:Msg.DownloadManual     = 'Tentar manualmente: ollama pull {0}'
            $script:Msg.DownloadDone       = 'Modelo descarregado: {0}'
            # Custom Model
            $script:Msg.CreatingCustom     = 'A criar o modelo Hablará...'
            $script:Msg.UpdatingCustom     = 'A atualizar o modelo Hablará existente...'
            $script:Msg.CustomExists       = 'Modelo Hablará {0} já disponível.'
            $script:Msg.CustomSkip         = 'Ignorar (sem alterações)'
            $script:Msg.CustomUpdateOpt    = 'Atualizar o modelo Hablará'
            $script:Msg.CustomUpdatePrompt = 'Opção [1-2, Enter=1]'
            $script:Msg.CustomKept         = 'Modelo Hablará mantido'
            $script:Msg.CustomPresent      = 'Modelo Hablará já disponível'
            $script:Msg.UsingHablaraConf   = 'A utilizar a configuração Hablará'
            $script:Msg.UsingDefaultConf   = 'A utilizar a configuração padrão'
            $script:Msg.ConfigReadError    = 'Não foi possível ler a configuração: {0}'
            $script:Msg.CustomCreating      = 'A criar o modelo Hablará {0}...'
            $script:Msg.CustomCreateTO     = 'ollama create atingiu o tempo limite de 120s — a utilizar o modelo base'
            $script:Msg.CustomCreateFail   = 'Não foi possível {0} o modelo Hablará - a utilizar o modelo base'
            $script:Msg.CustomDone         = 'Modelo Hablará {0}: {1}'
            $script:Msg.ConfigError        = 'Erro de configuração'
            $script:Msg.PermsWarn          = 'Não foi possível definir permissões restritivas: {0}'
            $script:Msg.VerbCreated        = 'criado'
            $script:Msg.VerbUpdated        = 'atualizado'
            # Verify
            $script:Msg.Verifying          = 'A verificar a instalação...'
            $script:Msg.OllamaNotFound     = 'Ollama não encontrado'
            $script:Msg.ServerUnreachable  = 'Servidor Ollama inacessível'
            $script:Msg.BaseNotFound       = 'Modelo base não encontrado: {0}'
            $script:Msg.BaseOk             = 'Modelo base disponível: {0}'
            $script:Msg.CustomOk           = 'Modelo Hablará disponível: {0}'
            $script:Msg.CustomUnavail      = 'Modelo Hablará não disponível (a utilizar o modelo base)'
            $script:Msg.InferenceFailed    = 'Teste do modelo falhou, testar na aplicação'
            $script:Msg.SetupDone          = 'Instalação concluída!'
            # Main Summary
            $script:Msg.SetupComplete      = 'Instalação do Ollama para Hablará concluída!'
            $script:Msg.Installed          = 'Instalado:'
            $script:Msg.BaseModelLabel     = '  Modelo base:      '
            $script:Msg.HablaraModelLabel  = '  Modelo Hablará:   '
            $script:Msg.OllamaConfig       = 'Configuração do Ollama:'
            $script:Msg.ModelLabel         = '  Modelo:    '
            $script:Msg.BaseUrlLabel       = '  Base URL: '
            $script:Msg.Docs               = 'Documentação: https://github.com/fidpa/hablara'
            # Misc
            $script:Msg.TestModel          = 'A testar o modelo...'
            $script:Msg.TestOk             = 'Teste do modelo bem-sucedido'
            $script:Msg.TestFail           = 'Teste do modelo falhou'
            $script:Msg.WaitServer         = 'A aguardar o servidor Ollama...'
            $script:Msg.ServerReady        = 'Servidor Ollama pronto'
            $script:Msg.ServerAlready      = 'O servidor Ollama já está em execução'
            $script:Msg.ServerNoResponse   = 'Servidor Ollama não responde após {0}s'
            $script:Msg.SetupFailed        = 'Instalação falhou'
            $script:Msg.OllamaListTimeout  = 'ollama list atingiu o tempo limite (15s) na verificação do modelo'
            # Cleanup
            $script:Msg.CleanupNeedsTTY    = '-Cleanup requer uma sessão interativa'
            $script:Msg.CleanupNoOllama    = 'Ollama não encontrado'
            $script:Msg.CleanupNoServer    = 'Servidor Ollama inacessível'
            $script:Msg.CleanupStartHint   = 'Inicie o Ollama e tente novamente'
            $script:Msg.CleanupInstalled   = 'Variantes Hablará instaladas:'
            $script:Msg.CleanupPrompt      = 'Qual variante remover? (número, Enter=cancelar)'
            $script:Msg.CleanupInvalid     = 'Seleção inválida'
            $script:Msg.CleanupDeleted     = '{0} removido'
            $script:Msg.CleanupTimeout     = '{0} não pôde ser removido: Tempo limite (30s)'
            $script:Msg.CleanupFailed      = '{0} não pôde ser removido: {1}'
            $script:Msg.CleanupUnknownErr  = 'erro desconhecido'
            $script:Msg.CleanupNoneLeft    = 'Nenhum modelo Hablará instalado. Execute a instalação novamente para instalar um modelo.'
            $script:Msg.CleanupNoModels    = 'Nenhum modelo Hablará encontrado.'
            # Help
            $script:Msg.HelpTitle          = 'Hablará Ollama Setup v{0} (Windows)'
            $script:Msg.HelpDescription    = '  Instala o Ollama e configura um modelo Hablará otimizado.'
            $script:Msg.HelpUsage          = 'Uso:'
            $script:Msg.HelpUsageLine      = '  .\setup-ollama-win.ps1 [OPÇÕES]'
            $script:Msg.HelpOptions        = 'Opções:'
            $script:Msg.HelpOptModel       = '  -Model VARIANTE       Escolher variante: 1.5b, 3b, 7b, qwen3-8b (padrão: 3b)'
            $script:Msg.HelpOptUpdate      = '  -Update               Recriar o modelo personalizado Hablará (atualizar Modelfile)'
            $script:Msg.HelpOptStatus      = '  -Status               Verificação de status: 7 pontos de verificação da instalação do Ollama'
            $script:Msg.HelpOptDiagnose    = '  -Diagnose             Gerar relatório de suporte (texto simples, copiável)'
            $script:Msg.HelpOptCleanup     = '  -Cleanup              Remover variante instalada interativamente'
            $script:Msg.HelpOptLang        = '  -Lang da|de|en|es|fr|it|nl|pl|pt|sv  Idioma (da=Dinamarquês, de=Alemão, en=Inglês, es=Espanhol, fr=Francês, it=Italiano, nl=Holandês, pl=Polaco, pt=Português, sv=Sueco)'
            $script:Msg.HelpOptHelp        = '  -Help                 Mostrar esta ajuda'
            $script:Msg.HelpNoOpts         = '  Sem opções, é iniciado um menu interativo.'
            $script:Msg.HelpVariants       = 'Variantes de modelos:'
            $script:Msg.HelpExamples       = 'Exemplos:'
            $script:Msg.HelpExModel        = '  .\setup-ollama-win.ps1 -Model 3b       Instalar variante 3b'
            $script:Msg.HelpExUpdate       = '  .\setup-ollama-win.ps1 -Update         Atualizar modelo personalizado'
            $script:Msg.HelpExStatus       = '  .\setup-ollama-win.ps1 -Status         Verificar instalação'
            $script:Msg.HelpExDiagnose     = '  .\setup-ollama-win.ps1 -Diagnose       Criar relatório de erros'
            $script:Msg.HelpExCleanup      = '  .\setup-ollama-win.ps1 -Cleanup        Remover variante'
            $script:Msg.HelpExitCodes      = 'Códigos de saída:'
            $script:Msg.HelpExit0          = '  0  Sucesso'
            $script:Msg.HelpExit1          = '  1  Erro geral'
            $script:Msg.HelpExit2          = '  2  Espaço em disco insuficiente'
            $script:Msg.HelpExit3          = '  3  Sem ligação à rede'
            $script:Msg.HelpExit4          = '  4  Plataforma incorreta'
            $script:Msg.AutoInstallFailed  = 'Não foi possível instalar o Ollama automaticamente'
            # Hardware Detection
            $script:Msg.HwDetectionHeader  = 'Detecção de hardware:'
            $script:Msg.HwBandwidth        = 'Largura de banda de memória: ~{0} GB/s · {1} GB RAM'
            $script:Msg.HwRecommendation   = 'Recomendação de modelo para o seu hardware:'
            $script:Msg.HwLocalTooSlow     = 'Os modelos locais serão lentos neste hardware'
            $script:Msg.HwCloudHint        = 'Recomendação: API OpenAI ou Anthropic para melhor experiência'
            $script:Msg.HwProceedLocal     = 'Instalar localmente mesmo assim? [s/N]'
            $script:Msg.HwTagRecommended   = 'recomendado'
            $script:Msg.HwTagSlow          = 'lento'
            $script:Msg.HwTagTooSlow       = 'demasiado lento'
            $script:Msg.ChoicePromptHw     = 'Escolha [1-4, Enter={0}]'
            $script:Msg.HwUnknownChip      = 'Processador desconhecido — recomendação de largura de banda não disponível'
            $script:Msg.HwMultiCallHint   = 'Hablará executa várias etapas de análise por gravação'
            # Benchmark
            $script:Msg.BenchResult        = 'Benchmark: ~{0} tok/s com {1}'
            $script:Msg.BenchExcellent     = 'Excelente — o seu hardware lida com este modelo com facilidade'
            $script:Msg.BenchGood          = 'Bom — este modelo funciona bem no seu hardware'
            $script:Msg.BenchMarginal      = 'Marginal — considere um modelo menor para uma experiência mais fluida'
            $script:Msg.BenchTooSlow       = 'Demasiado lento — recomenda-se um modelo menor ou provedor cloud'
            $script:Msg.BenchSkip          = 'Benchmark ignorado (medição falhou)'
        }
        'pl' {
            $script:Msg.ErrorPrefix        = 'Błąd'
            # Model Menu
            $script:Msg.ChooseModel        = 'Wybierz model:'
            $script:Msg.ChoicePrompt       = 'Wybór [1-4, Enter=1]'
            $script:Msg.Model3B            = 'Najlepsza ogólna wydajność [Domyślny]'
            $script:Msg.Model1_5B          = 'Szybki, ograniczona dokładność [Podstawowy]'
            $script:Msg.Model7B            = 'Wymaga wydajnego sprzętu'
            $script:Msg.ModelQwen3         = 'Najlepsza analiza argumentów [Premium]'
            # Main Menu
            $script:Msg.ChooseAction       = 'Wybierz akcję:'
            $script:Msg.ActionSetup        = 'Zainstaluj lub zaktualizuj Ollama'
            $script:Msg.ActionStatus       = 'Sprawdź status'
            $script:Msg.ActionDiagnose     = 'Diagnostyka (raport pomocy technicznej)'
            $script:Msg.ActionCleanup      = 'Wyczyść modele'
            $script:Msg.ActionPrompt       = 'Wybór [1-4, Enter=1]'
            # Select Model
            $script:Msg.InvalidModel       = 'Nieprawidłowy wariant modelu: {0}'
            $script:Msg.ValidVariants      = 'Prawidłowe warianty: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b'
            $script:Msg.RamWarnModel       = 'Ten model wymaga co najmniej {0}GB pamięci RAM'
            $script:Msg.RamWarnSys         = 'Twój system ma {0}GB pamięci RAM'
            $script:Msg.ContinueAnyway     = 'Kontynuować mimo to?'
            $script:Msg.ConfirmPrompt      = '[t/N]'
            $script:Msg.ConfirmPattern     = '^[tT]$'
            $script:Msg.Aborted            = 'Anulowano.'
            $script:Msg.SelectedModel      = 'Wybrany model: {0}'
            $script:Msg.ProceedNonInteract = 'Kontynuowanie...'
            $script:Msg.InternalError      = 'Błąd wewnętrzny: ModelName nie zdefiniowany'
            # Preflight
            $script:Msg.Preflight          = 'Wykonywanie wstępnych sprawdzeń...'
            $script:Msg.PlatformError      = 'Ten skrypt jest przeznaczony tylko dla Windows'
            $script:Msg.PlatformMacHint    = 'Dla macOS: scripts/setup-ollama-mac.sh'
            $script:Msg.PlatformLinuxHint  = 'Dla Linux: scripts/setup-ollama-linux.sh'
            $script:Msg.DiskInsufficient   = 'Niewystarczające miejsce na dysku: dostępne {0}GB, wymagane {1}GB'
            $script:Msg.DiskOk             = 'Miejsce na dysku: dostępne {0}GB'
            $script:Msg.NetworkError       = 'Brak połączenia sieciowego z ollama.com'
            $script:Msg.NetworkHint        = 'Sprawdź: Invoke-WebRequest -Uri https://ollama.com'
            $script:Msg.NetworkOk          = 'Połączenie sieciowe OK'
            $script:Msg.GpuDetected        = 'Wykryto GPU: {0}'
            $script:Msg.GpuNone            = 'Nie wykryto GPU — przetwarzanie bez akceleracji GPU'
            # Status
            $script:Msg.StatusTitle        = 'Hablará Ollama Status (Windows)'
            $script:Msg.StatusInstalled    = 'Ollama zainstalowane (v{0})'
            $script:Msg.StatusUpdateRec    = '    {0} Zalecana aktualizacja (minimum v{1}): winget upgrade Ollama.Ollama'
            $script:Msg.StatusNotFound     = 'Nie znaleziono Ollama'
            $script:Msg.StatusServerOk     = 'Serwer działa'
            $script:Msg.StatusServerFail   = 'Serwer niedostępny'
            $script:Msg.StatusGpuNvidia    = 'NVIDIA (akceleracja CUDA)'
            $script:Msg.StatusGpuAmd       = 'AMD (akceleracja ROCm, eksperymentalne)'
            $script:Msg.StatusNoGpu        = 'Brak GPU — przetwarzanie bez akceleracji GPU'
            $script:Msg.StatusBaseModel    = 'Model bazowy: {0}'
            $script:Msg.StatusBaseModels   = 'Modele bazowe:'
            $script:Msg.StatusNoBase       = 'Nie znaleziono modelu bazowego'
            $script:Msg.StatusHablaraModel = 'Model Hablará: {0}'
            $script:Msg.StatusHablaraModels= 'Modele Hablará:'
            $script:Msg.StatusNoHablara    = 'Nie znaleziono modelu Hablará'
            $script:Msg.StatusBaseMissing  = '    {0} Brak modelu bazowego — model Hablará potrzebuje go jako podstawy'
            $script:Msg.StatusInfSkip      = 'Test modelu pominięty (serwer niedostępny)'
            $script:Msg.StatusModelOk      = 'Model odpowiada'
            $script:Msg.StatusModelFail    = 'Model nie odpowiada'
            $script:Msg.StatusStorage      = 'Użycie pamięci (Hablará): ~{0} GB'
            $script:Msg.StatusStorageUnk   = 'Użycie pamięci: nie można określić'
            $script:Msg.StatusAllOk        = 'Wszystko jest w porządku.'
            $script:Msg.StatusProblems     = 'Znaleziono {0} problem(y/ów).'
            $script:Msg.StatusRepair       = '    Napraw: .\setup-ollama-win.ps1'
            # Diagnose
            $script:Msg.DiagnoseTitle      = '=== Raport diagnostyczny Ollama Hablará ==='
            $script:Msg.DiagnoseSystem     = 'System:'
            $script:Msg.DiagnoseOllama     = 'Ollama:'
            $script:Msg.DiagnoseModels     = 'Modele Hablará:'
            $script:Msg.DiagnoseStorage    = 'Pamięć (Hablará):'
            $script:Msg.DiagnoseLog        = 'Dziennik Ollama (ostatnie błędy):'
            $script:Msg.DiagnoseCreated    = 'Utworzono:'
            $script:Msg.DiagnoseScript     = 'Skrypt:'
            $script:Msg.DiagnoseSaved      = 'Raport zapisany: {0}'
            $script:Msg.DiagnoseSaveFailed = 'Nie można zapisać raportu'
            $script:Msg.DiagnoseRamAvail   = 'dostępne'
            $script:Msg.DiagnoseStorFree   = 'wolne'
            $script:Msg.DiagnoseStorDisk   = 'Pamięć:'
            $script:Msg.DiagnoseUnknown    = 'nieznane'
            $script:Msg.DiagnoseNotInst    = 'nie zainstalowane'
            $script:Msg.DiagnoseNotReach   = 'niedostępne'
            $script:Msg.DiagnoseRunning    = 'działa'
            $script:Msg.DiagnoseNoModels   = '    [nie znaleziono modeli Hablará]'
            $script:Msg.DiagnoseNoErrors   = '    [nie znaleziono błędów]'
            $script:Msg.DiagnoseNoLog      = '    [nie znaleziono pliku dziennika: {0}]'
            $script:Msg.DiagnoseLogUnread  = '    [plik dziennika nieczytelny: {0}]'
            $script:Msg.DiagnoseGpuNone    = 'Brak'
            $script:Msg.DiagnoseResponds   = '(odpowiada)'
            # Install
            $script:Msg.Installing         = 'Instalowanie Ollama...'
            $script:Msg.OllamaAlready      = 'Ollama jest już zainstalowane'
            $script:Msg.OllamaVersion      = 'Wersja: {0}'
            $script:Msg.ServerStartFailed  = 'Nie udało się uruchomić serwera Ollama'
            $script:Msg.ServerStartHint    = 'Uruchom ręcznie: ollama serve'
            $script:Msg.UsingWinget        = 'Używanie winget (limit czasu: 10 minut)...'
            $script:Msg.WingetTimeout      = 'winget install przekroczył limit czasu 10 minut'
            $script:Msg.WingetFailed       = 'winget nie powiódł się: {0}'
            $script:Msg.OllamaInstalled    = 'Ollama zainstalowane przez winget'
            $script:Msg.WaitForAutoStart   = 'Oczekiwanie na automatyczne uruchomienie aplikacji Ollama...'
            $script:Msg.RebootRequired     = 'Może być konieczne ponowne uruchomienie komputera'
            $script:Msg.OllamaPathError    = 'Ollama zainstalowane, ale CLI nie jest w PATH. Otwórz nowy terminal lub sprawdź PATH.'
            $script:Msg.ServerStartWarn    = 'Nie udało się uruchomić serwera — uruchom ręcznie: ollama serve'
            $script:Msg.ManualInstall      = 'Zainstaluj Ollama ręcznie: https://ollama.com/download'
            $script:Msg.ManualRerun        = 'Następnie uruchom ponownie ten skrypt.'
            $script:Msg.OllamaFound        = 'Znaleziono Ollama: {0}'
            $script:Msg.OllamaAppStart     = 'Uruchamianie aplikacji Ollama...'
            $script:Msg.OllamaServeStart   = 'Uruchamianie serwera Ollama (ollama serve)...'
            $script:Msg.OllamaProcessExit  = 'Proces Ollama zakończony (kod: {0})'
            $script:Msg.PortBusy           = 'Port 11434 zajęty, oczekiwanie na API Ollama...'
            $script:Msg.PortBusyWarn       = 'Port 11434 zajęty, ale API Ollama nie odpowiada'
            $script:Msg.VersionWarn        = 'Ollama w wersji {0} jest starsza od zalecanej ({1})'
            $script:Msg.UpdateHint         = 'Aktualizuj: winget upgrade Ollama.Ollama'
            # Model Download
            $script:Msg.DownloadingBase    = 'Pobieranie modelu bazowego...'
            $script:Msg.ModelExists        = 'Model już dostępny: {0}'
            $script:Msg.DownloadingModel   = 'Pobieranie {0} ({1}, może potrwać kilka minut w zależności od połączenia)...'
            $script:Msg.DownloadResumeTip  = 'Wskazówka: Po przerwaniu (Ctrl+C) pobieranie zostanie wznowione po ponownym uruchomieniu'
            $script:Msg.DownloadHardTimeout= 'Osiągnięto twardy limit czasu {0} minut — anulowanie'
            $script:Msg.DownloadStall      = 'Brak postępu pobierania przez {0} minut — anulowanie'
            $script:Msg.DownloadRunning    = '  Pobieranie w toku... ({0}m {1}s)'
            $script:Msg.DownloadTimeoutW   = 'Przekroczono limit czasu pobierania po {0} minutach (próba {1}/3)'
            $script:Msg.DownloadFailedW    = 'Pobieranie nie powiodło się (próba {0}/3)'
            $script:Msg.DownloadRetry      = 'Następna próba za 5s...'
            $script:Msg.DownloadFailed     = 'Pobieranie modelu nie powiodło się po 3 próbach'
            $script:Msg.DownloadManual     = 'Spróbuj ręcznie: ollama pull {0}'
            $script:Msg.DownloadDone       = 'Model pobrany: {0}'
            # Custom Model
            $script:Msg.CreatingCustom     = 'Tworzenie modelu Hablará...'
            $script:Msg.UpdatingCustom     = 'Aktualizowanie istniejącego modelu Hablará...'
            $script:Msg.CustomExists       = 'Model Hablará {0} już dostępny.'
            $script:Msg.CustomSkip         = 'Pomiń (bez zmian)'
            $script:Msg.CustomUpdateOpt    = 'Zaktualizuj model Hablará'
            $script:Msg.CustomUpdatePrompt = 'Wybór [1-2, Enter=1]'
            $script:Msg.CustomKept         = 'Model Hablará zachowany'
            $script:Msg.CustomPresent      = 'Model Hablará już dostępny'
            $script:Msg.UsingHablaraConf   = 'Używanie konfiguracji Hablará'
            $script:Msg.UsingDefaultConf   = 'Używanie domyślnej konfiguracji'
            $script:Msg.ConfigReadError    = 'Nie można odczytać konfiguracji: {0}'
            $script:Msg.CustomCreating      = 'Tworzenie modelu Hablará {0}...'
            $script:Msg.CustomCreateTO     = 'ollama create przekroczył limit czasu 120s — używanie modelu bazowego'
            $script:Msg.CustomCreateFail   = 'Nie udało się {0} modelu Hablará — używanie modelu bazowego'
            $script:Msg.CustomDone         = 'Model Hablará {0}: {1}'
            $script:Msg.ConfigError        = 'Błąd konfiguracji'
            $script:Msg.PermsWarn          = 'Nie można ustawić restrykcyjnych uprawnień: {0}'
            $script:Msg.VerbCreated        = 'utworzony'
            $script:Msg.VerbUpdated        = 'zaktualizowany'
            # Verify
            $script:Msg.Verifying          = 'Weryfikowanie instalacji...'
            $script:Msg.OllamaNotFound     = 'Nie znaleziono Ollama'
            $script:Msg.ServerUnreachable  = 'Serwer Ollama niedostępny'
            $script:Msg.BaseNotFound       = 'Nie znaleziono modelu bazowego: {0}'
            $script:Msg.BaseOk             = 'Model bazowy dostępny: {0}'
            $script:Msg.CustomOk           = 'Model Hablará dostępny: {0}'
            $script:Msg.CustomUnavail      = 'Model Hablará niedostępny (używanie modelu bazowego)'
            $script:Msg.InferenceFailed    = 'Test modelu nie powiódł się, przetestuj w aplikacji'
            $script:Msg.SetupDone          = 'Instalacja zakończona!'
            # Main Summary
            $script:Msg.SetupComplete      = 'Instalacja Ollama dla Hablará zakończona!'
            $script:Msg.Installed          = 'Zainstalowano:'
            $script:Msg.BaseModelLabel     = '  Model bazowy:    '
            $script:Msg.HablaraModelLabel  = '  Model Hablará:   '
            $script:Msg.OllamaConfig       = 'Konfiguracja Ollama:'
            $script:Msg.ModelLabel         = '  Model:    '
            $script:Msg.BaseUrlLabel       = '  Base URL: '
            $script:Msg.Docs               = 'Dokumentacja: https://github.com/fidpa/hablara'
            # Misc
            $script:Msg.TestModel          = 'Testowanie modelu...'
            $script:Msg.TestOk             = 'Test modelu zakończony pomyślnie'
            $script:Msg.TestFail           = 'Test modelu nie powiódł się'
            $script:Msg.WaitServer         = 'Oczekiwanie na serwer Ollama...'
            $script:Msg.ServerReady        = 'Serwer Ollama gotowy'
            $script:Msg.ServerAlready      = 'Serwer Ollama jest już uruchomiony'
            $script:Msg.ServerNoResponse   = 'Serwer Ollama nie odpowiada po {0}s'
            $script:Msg.SetupFailed        = 'Instalacja nie powiodła się'
            $script:Msg.OllamaListTimeout  = 'ollama list przekroczył limit czasu (15s) podczas sprawdzania modelu'
            # Cleanup
            $script:Msg.CleanupNeedsTTY    = '-Cleanup wymaga sesji interaktywnej'
            $script:Msg.CleanupNoOllama    = 'Nie znaleziono Ollama'
            $script:Msg.CleanupNoServer    = 'Serwer Ollama niedostępny'
            $script:Msg.CleanupStartHint   = 'Uruchom Ollama i spróbuj ponownie'
            $script:Msg.CleanupInstalled   = 'Zainstalowane warianty Hablará:'
            $script:Msg.CleanupPrompt      = 'Który wariant usunąć? (numer, Enter=anuluj)'
            $script:Msg.CleanupInvalid     = 'Nieprawidłowy wybór'
            $script:Msg.CleanupDeleted     = '{0} usunięty'
            $script:Msg.CleanupTimeout     = '{0} nie mógł zostać usunięty: limit czasu (30s)'
            $script:Msg.CleanupFailed      = '{0} nie mógł zostać usunięty: {1}'
            $script:Msg.CleanupUnknownErr  = 'nieznany błąd'
            $script:Msg.CleanupNoneLeft    = 'Nie zainstalowano żadnych modeli Hablará. Uruchom ponownie instalację, aby zainstalować model.'
            $script:Msg.CleanupNoModels    = 'Nie znaleziono modeli Hablará.'
            # Help
            $script:Msg.HelpTitle          = 'Hablará Ollama Setup v{0} (Windows)'
            $script:Msg.HelpDescription    = '  Instaluje Ollama i konfiguruje zoptymalizowany model Hablará.'
            $script:Msg.HelpUsage          = 'Użycie:'
            $script:Msg.HelpUsageLine      = '  .\setup-ollama-win.ps1 [OPCJE]'
            $script:Msg.HelpOptions        = 'Opcje:'
            $script:Msg.HelpOptModel       = '  -Model WARIANT        Wybierz wariant: 1.5b, 3b, 7b, qwen3-8b (domyślny: 3b)'
            $script:Msg.HelpOptUpdate      = '  -Update               Odtwórz niestandardowy model Hablará (aktualizacja Modelfile)'
            $script:Msg.HelpOptStatus      = '  -Status               Sprawdzenie statusu: 7 punktów kontrolnych instalacji Ollama'
            $script:Msg.HelpOptDiagnose    = '  -Diagnose             Generuj raport pomocy technicznej (tekst, do skopiowania)'
            $script:Msg.HelpOptCleanup     = '  -Cleanup              Interaktywne usuwanie zainstalowanego wariantu'
            $script:Msg.HelpOptLang        = '  -Lang da|de|en|es|fr|it|nl|pl|pt|sv  Język (da=Duński, de=Niemiecki, en=Angielski, es=Hiszpański, fr=Francuski, it=Włoski, nl=Niderlandzki, pl=Polski, pt=Portugalski, sv=Szwedzki)'
            $script:Msg.HelpOptHelp        = '  -Help                 Wyświetl tę pomoc'
            $script:Msg.HelpNoOpts         = '  Bez opcji uruchamiany jest interaktywny menu.'
            $script:Msg.HelpVariants       = 'Warianty modeli:'
            $script:Msg.HelpExamples       = 'Przykłady:'
            $script:Msg.HelpExModel        = '  .\setup-ollama-win.ps1 -Model 3b       Zainstaluj wariant 3b'
            $script:Msg.HelpExUpdate       = '  .\setup-ollama-win.ps1 -Update         Zaktualizuj niestandardowy model'
            $script:Msg.HelpExStatus       = '  .\setup-ollama-win.ps1 -Status         Sprawdź instalację'
            $script:Msg.HelpExDiagnose     = '  .\setup-ollama-win.ps1 -Diagnose       Utwórz raport błędów'
            $script:Msg.HelpExCleanup      = '  .\setup-ollama-win.ps1 -Cleanup        Usuń wariant'
            $script:Msg.HelpExitCodes      = 'Kody wyjścia:'
            $script:Msg.HelpExit0          = '  0  Sukces'
            $script:Msg.HelpExit1          = '  1  Błąd ogólny'
            $script:Msg.HelpExit2          = '  2  Niewystarczające miejsce na dysku'
            $script:Msg.HelpExit3          = '  3  Brak połączenia sieciowego'
            $script:Msg.HelpExit4          = '  4  Nieprawidłowa platforma'
            $script:Msg.AutoInstallFailed  = 'Nie udało się automatycznie zainstalować Ollama'
            # Hardware Detection
            $script:Msg.HwDetectionHeader  = 'Wykrywanie sprzętu:'
            $script:Msg.HwBandwidth        = 'Przepustowość pamięci: ~{0} GB/s · {1} GB RAM'
            $script:Msg.HwRecommendation   = 'Rekomendacja modelu dla Twojego sprzętu:'
            $script:Msg.HwLocalTooSlow     = 'Lokalne modele będą wolne na tym sprzęcie'
            $script:Msg.HwCloudHint        = 'Rekomendacja: API OpenAI lub Anthropic dla najlepszego doświadczenia'
            $script:Msg.HwProceedLocal     = 'Zainstalować lokalnie mimo to? [t/N]'
            $script:Msg.HwTagRecommended   = 'zalecany'
            $script:Msg.HwTagSlow          = 'wolny'
            $script:Msg.HwTagTooSlow       = 'za wolny'
            $script:Msg.ChoicePromptHw     = 'Wybór [1-4, Enter={0}]'
            $script:Msg.HwUnknownChip      = 'Nieznany procesor — brak rekomendacji przepustowości'
            $script:Msg.HwMultiCallHint   = 'Hablará wykonuje wiele kroków analizy na nagranie'
            # Benchmark
            $script:Msg.BenchResult        = 'Benchmark: ~{0} tok/s z {1}'
            $script:Msg.BenchExcellent     = 'Doskonały — twój sprzęt obsługuje ten model bez trudu'
            $script:Msg.BenchGood          = 'Dobrze — ten model działa dobrze na twoim sprzęcie'
            $script:Msg.BenchMarginal      = 'Graniczny — mniejszy model zapewni płynniejsze działanie'
            $script:Msg.BenchTooSlow       = 'Za wolno — zalecany jest mniejszy model lub dostawca chmury'
            $script:Msg.BenchSkip          = 'Pominięto benchmark (pomiar nie powiódł się)'
        }
        'sv' {
            $script:Msg.ErrorPrefix        = 'Fel'
            # Model Menu
            $script:Msg.ChooseModel        = 'Välj en modell:'
            $script:Msg.ChoicePrompt       = 'Val [1-4, Enter=1]'
            $script:Msg.Model3B            = 'Optimal helhetsprestanda [Standard]'
            $script:Msg.Model1_5B          = 'Snabb, begränsad noggrannhet [Grundnivå]'
            $script:Msg.Model7B            = 'Kräver kraftfull hårdvara'
            $script:Msg.ModelQwen3         = 'Bästa argumentationsanalys [Premium]'
            # Main Menu
            $script:Msg.ChooseAction       = 'Välj en åtgärd:'
            $script:Msg.ActionSetup        = 'Installera eller uppdatera Ollama'
            $script:Msg.ActionStatus       = 'Kontrollera status'
            $script:Msg.ActionDiagnose     = 'Diagnostik (supportrapport)'
            $script:Msg.ActionCleanup      = 'Rensa modeller'
            $script:Msg.ActionPrompt       = 'Val [1-4, Enter=1]'
            # Select Model
            $script:Msg.InvalidModel       = 'Ogiltig modellvariant: {0}'
            $script:Msg.ValidVariants      = 'Giltiga varianter: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b'
            $script:Msg.RamWarnModel       = 'Den här modellen rekommenderar minst {0}GB RAM'
            $script:Msg.RamWarnSys         = 'Ditt system har {0}GB RAM'
            $script:Msg.ContinueAnyway     = 'Fortsätt ändå?'
            $script:Msg.ConfirmPrompt      = '[j/N]'
            $script:Msg.ConfirmPattern     = '^[jJyY]$'
            $script:Msg.Aborted            = 'Avbruten.'
            $script:Msg.SelectedModel      = 'Vald modell: {0}'
            $script:Msg.ProceedNonInteract = 'Fortsätter...'
            $script:Msg.InternalError      = 'Internt fel: ModelName är inte satt'
            # Preflight
            $script:Msg.Preflight          = 'Kör förkontroller...'
            $script:Msg.PlatformError      = 'Det här skriptet är endast för Windows'
            $script:Msg.PlatformMacHint    = 'För macOS: scripts/setup-ollama-mac.sh'
            $script:Msg.PlatformLinuxHint  = 'För Linux: scripts/setup-ollama-linux.sh'
            $script:Msg.DiskInsufficient   = 'Inte tillräckligt med utrymme: {0}GB tillgängligt, {1}GB krävs'
            $script:Msg.DiskOk             = 'Diskutrymme: {0}GB tillgängligt'
            $script:Msg.NetworkError       = 'Ingen nätverksanslutning till ollama.com'
            $script:Msg.NetworkHint        = 'Kontrollera: Invoke-WebRequest -Uri https://ollama.com'
            $script:Msg.NetworkOk          = 'Nätverksanslutning OK'
            $script:Msg.GpuDetected        = 'GPU detekterad: {0}'
            $script:Msg.GpuNone            = 'Ingen GPU detekterad – bearbetning utan GPU-acceleration'
            # Status
            $script:Msg.StatusTitle        = 'Hablará Ollama-status (Windows)'
            $script:Msg.StatusInstalled    = 'Ollama installerat (v{0})'
            $script:Msg.StatusUpdateRec    = '    {0} Uppdatering rekommenderas (minimum v{1}): winget upgrade Ollama.Ollama'
            $script:Msg.StatusNotFound     = 'Ollama hittades inte'
            $script:Msg.StatusServerOk     = 'Server körs'
            $script:Msg.StatusServerFail   = 'Server inte nåbar'
            $script:Msg.StatusGpuNvidia    = 'NVIDIA (CUDA-acceleration)'
            $script:Msg.StatusGpuAmd       = 'AMD (ROCm-acceleration, experimentell)'
            $script:Msg.StatusNoGpu        = 'Ingen GPU – bearbetning utan GPU-acceleration'
            $script:Msg.StatusBaseModel    = 'Basmodell: {0}'
            $script:Msg.StatusBaseModels   = 'Basmodeller:'
            $script:Msg.StatusNoBase       = 'Ingen basmodell hittad'
            $script:Msg.StatusHablaraModel = 'Hablará-modell: {0}'
            $script:Msg.StatusHablaraModels= 'Hablará-modeller:'
            $script:Msg.StatusNoHablara    = 'Ingen Hablará-modell hittad'
            $script:Msg.StatusBaseMissing  = '    {0} Basmodell saknas – Hablará-modell kräver den som grund'
            $script:Msg.StatusInfSkip      = 'Modelltest hoppades över (server inte nåbar)'
            $script:Msg.StatusModelOk      = 'Modell svarar'
            $script:Msg.StatusModelFail    = 'Modell svarar inte'
            $script:Msg.StatusStorage      = 'Lagringsanvändning (Hablará): ~{0} GB'
            $script:Msg.StatusStorageUnk   = 'Lagringsanvändning: ej bestämbar'
            $script:Msg.StatusAllOk        = 'Allt är i ordning.'
            $script:Msg.StatusProblems     = '{0} problem hittade.'
            $script:Msg.StatusRepair       = '    Reparera: .\setup-ollama-win.ps1'
            # Diagnose
            $script:Msg.DiagnoseTitle      = '=== Hablará Ollama Diagnostikrapport ==='
            $script:Msg.DiagnoseSystem     = 'System:'
            $script:Msg.DiagnoseOllama     = 'Ollama:'
            $script:Msg.DiagnoseModels     = 'Hablará-modeller:'
            $script:Msg.DiagnoseStorage    = 'Lagring (Hablará):'
            $script:Msg.DiagnoseLog        = 'Ollama-logg (senaste fel):'
            $script:Msg.DiagnoseCreated    = 'Skapad:'
            $script:Msg.DiagnoseScript     = 'Skript:'
            $script:Msg.DiagnoseSaved      = 'Rapport sparad: {0}'
            $script:Msg.DiagnoseSaveFailed = 'Det gick inte att spara rapporten'
            $script:Msg.DiagnoseRamAvail   = 'tillgängligt'
            $script:Msg.DiagnoseStorFree   = 'fritt'
            $script:Msg.DiagnoseStorDisk   = 'Lagring:'
            $script:Msg.DiagnoseUnknown    = 'okänd'
            $script:Msg.DiagnoseNotInst    = 'inte installerat'
            $script:Msg.DiagnoseNotReach   = 'inte nåbar'
            $script:Msg.DiagnoseRunning    = 'körs'
            $script:Msg.DiagnoseNoModels   = '    [inga Hablará-modeller hittade]'
            $script:Msg.DiagnoseNoErrors   = '    [inga fel hittade]'
            $script:Msg.DiagnoseNoLog      = '    [loggfil hittades inte: {0}]'
            $script:Msg.DiagnoseLogUnread  = '    [loggfil kunde inte läsas: {0}]'
            $script:Msg.DiagnoseGpuNone    = 'Ingen'
            $script:Msg.DiagnoseResponds   = '(svarar)'
            # Install
            $script:Msg.Installing         = 'Installerar Ollama...'
            $script:Msg.OllamaAlready      = 'Ollama är redan installerat'
            $script:Msg.OllamaVersion      = 'Version: {0}'
            $script:Msg.ServerStartFailed  = 'Kunde inte starta Ollama-server'
            $script:Msg.ServerStartHint    = 'Starta manuellt: ollama serve'
            $script:Msg.UsingWinget        = 'Använder winget (timeout: 10 minuter)...'
            $script:Msg.WingetTimeout      = 'winget install timeout efter 10 minuter'
            $script:Msg.WingetFailed       = 'winget-installation misslyckades: {0}'
            $script:Msg.OllamaInstalled    = 'Ollama installerat via winget'
            $script:Msg.WaitForAutoStart   = 'Väntar på automatisk start av Ollama-appen...'
            $script:Msg.RebootRequired     = 'En omstart av datorn kan krävas'
            $script:Msg.OllamaPathError    = 'Ollama installerat men CLI inte i PATH. Öppna en ny terminal eller kontrollera PATH.'
            $script:Msg.ServerStartWarn    = 'Serverstart misslyckades – starta manuellt: ollama serve'
            $script:Msg.ManualInstall      = 'Installera Ollama manuellt: https://ollama.com/download'
            $script:Msg.ManualRerun        = 'Kör sedan det här skriptet igen.'
            $script:Msg.OllamaFound        = 'Ollama hittad: {0}'
            $script:Msg.OllamaAppStart     = 'Startar Ollama-app...'
            $script:Msg.OllamaServeStart   = 'Startar Ollama-server (ollama serve)...'
            $script:Msg.OllamaProcessExit  = 'Ollama-process avslutad (kod: {0})'
            $script:Msg.PortBusy           = 'Port 11434 är upptagen, väntar på Ollama API...'
            $script:Msg.PortBusyWarn       = 'Port 11434 upptagen men Ollama API svarar inte'
            $script:Msg.VersionWarn        = 'Ollama-version {0} är äldre än rekommenderad ({1})'
            $script:Msg.UpdateHint         = 'Uppdatera: winget upgrade Ollama.Ollama'
            # Model Download
            $script:Msg.DownloadingBase    = 'Laddar ned basmodell...'
            $script:Msg.ModelExists        = 'Modell finns redan: {0}'
            $script:Msg.DownloadingModel   = 'Laddar ned {0} ({1}, tar flera minuter beroende på anslutning)...'
            $script:Msg.DownloadResumeTip  = 'Tips: Om avbrutet (Ctrl+C) fortsätter nedladdningen vid omstart'
            $script:Msg.DownloadHardTimeout= 'Hård timeout efter {0} minuter – avbryter'
            $script:Msg.DownloadStall      = 'Ingen nedladdningsframgång under {0} minuter – avbryter'
            $script:Msg.DownloadRunning    = '  Nedladdning pågår... ({0}m {1}s)'
            $script:Msg.DownloadTimeoutW   = 'Nedladdningstimeout efter {0} minuter (försök {1}/3)'
            $script:Msg.DownloadFailedW    = 'Nedladdning misslyckades (försök {0}/3)'
            $script:Msg.DownloadRetry      = 'Nästa försök om 5s...'
            $script:Msg.DownloadFailed     = 'Modellnedladdning misslyckades efter 3 försök'
            $script:Msg.DownloadManual     = 'Prova manuellt: ollama pull {0}'
            $script:Msg.DownloadDone       = 'Modell nedladdad: {0}'
            # Custom Model
            $script:Msg.CreatingCustom     = 'Skapar Hablará-modell...'
            $script:Msg.UpdatingCustom     = 'Uppdaterar befintlig Hablará-modell...'
            $script:Msg.CustomExists       = 'Hablará-modell {0} finns redan.'
            $script:Msg.CustomSkip         = 'Hoppa över (inga ändringar)'
            $script:Msg.CustomUpdateOpt    = 'Uppdatera Hablará-modell'
            $script:Msg.CustomUpdatePrompt = 'Val [1-2, Enter=1]'
            $script:Msg.CustomKept         = 'Hablará-modell behållen'
            $script:Msg.CustomPresent      = 'Hablará-modell finns redan'
            $script:Msg.UsingHablaraConf   = 'Använder Hablará-konfiguration'
            $script:Msg.UsingDefaultConf   = 'Använder standardkonfiguration'
            $script:Msg.ConfigReadError    = 'Kunde inte läsa konfiguration: {0}'
            $script:Msg.CustomCreating      = 'Skapar Hablará-modell {0}...'
            $script:Msg.CustomCreateTO     = 'ollama create timeout efter 120s – använder basmodell'
            $script:Msg.CustomCreateFail   = 'Hablará-modell kunde inte {0} – använder basmodell'
            $script:Msg.CustomDone         = 'Hablará-modell {0}: {1}'
            $script:Msg.ConfigError        = 'Konfigurationsfel'
            $script:Msg.PermsWarn          = 'Kunde inte sätta begränsade behörigheter: {0}'
            $script:Msg.VerbCreated        = 'skapad'
            $script:Msg.VerbUpdated        = 'uppdaterad'
            # Verify
            $script:Msg.Verifying          = 'Verifierar installation...'
            $script:Msg.OllamaNotFound     = 'Ollama hittades inte'
            $script:Msg.ServerUnreachable  = 'Ollama-server inte nåbar'
            $script:Msg.BaseNotFound       = 'Basmodell hittades inte: {0}'
            $script:Msg.BaseOk             = 'Basmodell tillgänglig: {0}'
            $script:Msg.CustomOk           = 'Hablará-modell tillgänglig: {0}'
            $script:Msg.CustomUnavail      = 'Hablará-modell otillgänglig (använder basmodell)'
            $script:Msg.InferenceFailed    = 'Modelltest misslyckades, testa i appen'
            $script:Msg.SetupDone          = 'Installation klar!'
            # Main Summary
            $script:Msg.SetupComplete      = 'Hablará Ollama-installation klar!'
            $script:Msg.Installed          = 'Installerat:'
            $script:Msg.BaseModelLabel     = '  Basmodell:        '
            $script:Msg.HablaraModelLabel  = '  Hablará-modell: '
            $script:Msg.OllamaConfig       = 'Ollama-konfiguration:'
            $script:Msg.ModelLabel         = '  Modell:    '
            $script:Msg.BaseUrlLabel       = '  Bas-URL:   '
            $script:Msg.Docs               = 'Dokumentation: https://github.com/fidpa/hablara'
            # Misc
            $script:Msg.TestModel          = 'Testar modell...'
            $script:Msg.TestOk             = 'Modelltest lyckades'
            $script:Msg.TestFail           = 'Modelltest misslyckades'
            $script:Msg.WaitServer         = 'Väntar på Ollama-server...'
            $script:Msg.ServerReady        = 'Ollama-server är redo'
            $script:Msg.ServerAlready      = 'Ollama-server körs redan'
            $script:Msg.ServerNoResponse   = 'Ollama-server svarar inte efter {0}s'
            $script:Msg.SetupFailed        = 'Installationen misslyckades'
            $script:Msg.OllamaListTimeout  = 'ollama list timeout (15s) vid modellkontroll'
            # Cleanup
            $script:Msg.CleanupNeedsTTY    = '-Cleanup kräver en interaktiv session'
            $script:Msg.CleanupNoOllama    = 'Ollama hittades inte'
            $script:Msg.CleanupNoServer    = 'Ollama-server inte nåbar'
            $script:Msg.CleanupStartHint   = 'Starta Ollama och försök igen'
            $script:Msg.CleanupInstalled   = 'Installerade Hablará-varianter:'
            $script:Msg.CleanupPrompt      = 'Vilken variant ska tas bort? (nummer, Enter=avbryt)'
            $script:Msg.CleanupInvalid     = 'Ogiltigt val'
            $script:Msg.CleanupDeleted     = '{0} borttagen'
            $script:Msg.CleanupTimeout     = '{0} kunde inte tas bort: Timeout (30s)'
            $script:Msg.CleanupFailed      = '{0} kunde inte tas bort: {1}'
            $script:Msg.CleanupUnknownErr  = 'okänt fel'
            $script:Msg.CleanupNoneLeft    = 'Inga Hablará-modeller installerade längre. Kör installationen igen för att installera en modell.'
            $script:Msg.CleanupNoModels    = 'Inga Hablará-modeller hittade.'
            # Help
            $script:Msg.HelpTitle          = 'Hablará Ollama Setup v{0} (Windows)'
            $script:Msg.HelpDescription    = '  Installerar Ollama och konfigurerar en optimerad Hablará-modell.'
            $script:Msg.HelpUsage          = 'Användning:'
            $script:Msg.HelpUsageLine      = '  .\setup-ollama-win.ps1 [ALTERNATIV]'
            $script:Msg.HelpOptions        = 'Alternativ:'
            $script:Msg.HelpOptModel       = '  -Model VARIANT        Välj modellvariant: 1.5b, 3b, 7b, qwen3-8b (standard: 3b)'
            $script:Msg.HelpOptUpdate      = '  -Update               Återskapa Hablará anpassad modell (uppdatera Modelfile)'
            $script:Msg.HelpOptStatus      = '  -Status               Hälsokontroll: 7-punkts Ollama-installationskontroll'
            $script:Msg.HelpOptDiagnose    = '  -Diagnose             Generera supportrapport (klartext, kopierbar)'
            $script:Msg.HelpOptCleanup     = '  -Cleanup              Interaktivt ta bort installerad variant'
            $script:Msg.HelpOptLang        = '  -Lang da|de|en|es|fr|it|nl|pl|pt|sv  Språk (da=danska, de=tyska, en=engelska, es=spanska, fr=franska, it=italienska, nl=holländska, pl=polska, pt=portugisiska, sv=svenska)'
            $script:Msg.HelpOptHelp        = '  -Help                 Visa den här hjälpen'
            $script:Msg.HelpNoOpts         = '  Utan alternativ startar en interaktiv meny.'
            $script:Msg.HelpVariants       = 'Modellvarianter:'
            $script:Msg.HelpExamples       = 'Exempel:'
            $script:Msg.HelpExModel        = '  .\setup-ollama-win.ps1 -Model 3b       Installera 3b-variant'
            $script:Msg.HelpExUpdate       = '  .\setup-ollama-win.ps1 -Update         Uppdatera anpassad modell'
            $script:Msg.HelpExStatus       = '  .\setup-ollama-win.ps1 -Status         Kontrollera installation'
            $script:Msg.HelpExDiagnose     = '  .\setup-ollama-win.ps1 -Diagnose       Skapa felrapport'
            $script:Msg.HelpExCleanup      = '  .\setup-ollama-win.ps1 -Cleanup        Ta bort variant'
            $script:Msg.HelpExitCodes      = 'Utgångskoder:'
            $script:Msg.HelpExit0          = '  0  Lyckades'
            $script:Msg.HelpExit1          = '  1  Allmänt fel'
            $script:Msg.HelpExit2          = '  2  Inte tillräckligt med diskutrymme'
            $script:Msg.HelpExit3          = '  3  Ingen nätverksanslutning'
            $script:Msg.HelpExit4          = '  4  Fel plattform'
            $script:Msg.AutoInstallFailed  = 'Ollama kunde inte installeras automatiskt'
            # Hardware Detection
            $script:Msg.HwDetectionHeader  = 'Maskinvarudetektering:'
            $script:Msg.HwBandwidth        = 'Minnesbandbredd: ~{0} GB/s · {1} GB RAM'
            $script:Msg.HwRecommendation   = 'Modellrekommendation för din maskinvara:'
            $script:Msg.HwLocalTooSlow     = 'Lokala modeller kommer vara långsamma på denna maskinvara'
            $script:Msg.HwCloudHint        = 'Rekommendation: OpenAI eller Anthropic API för bästa upplevelse'
            $script:Msg.HwProceedLocal     = 'Installera lokalt ändå? [j/N]'
            $script:Msg.HwTagRecommended   = 'rekommenderad'
            $script:Msg.HwTagSlow          = 'långsam'
            $script:Msg.HwTagTooSlow       = 'för långsam'
            $script:Msg.ChoicePromptHw     = 'Val [1-4, Enter={0}]'
            $script:Msg.HwUnknownChip      = 'Okänd processor — ingen bandbreddsrekommendation möjlig'
            $script:Msg.HwMultiCallHint   = 'Hablará kör flera analyssteg per inspelning'
            # Benchmark
            $script:Msg.BenchResult        = 'Benchmark: ~{0} tok/s med {1}'
            $script:Msg.BenchExcellent     = 'Utmärkt — din maskinvara hanterar den här modellen utan problem'
            $script:Msg.BenchGood          = 'Bra — den här modellen körs bra på din maskinvara'
            $script:Msg.BenchMarginal      = 'Marginellt — en mindre modell ger en smidigare upplevelse'
            $script:Msg.BenchTooSlow       = 'För långsamt — en mindre modell eller molnleverantör rekommenderas'
            $script:Msg.BenchSkip          = 'Benchmark hoppades över (mätning misslyckades)'
        }
        'da' {
            $script:Msg.ErrorPrefix        = 'Fejl'
            # Model Menu
            $script:Msg.ChooseModel        = 'Vælg en model:'
            $script:Msg.ChoicePrompt       = 'Valg [1-4, Enter=1]'
            $script:Msg.Model3B            = 'Bedste samlede ydelse [Standard]'
            $script:Msg.Model1_5B          = 'Hurtig, begrænset præcision [Grundlæggende]'
            $script:Msg.Model7B            = 'Kræver kraftfuld hardware'
            $script:Msg.ModelQwen3         = 'Bedste argumentationsanalyse [Premium]'
            # Main Menu
            $script:Msg.ChooseAction       = 'Vælg en handling:'
            $script:Msg.ActionSetup        = 'Installer eller opdater Ollama'
            $script:Msg.ActionStatus       = 'Kontrollér status'
            $script:Msg.ActionDiagnose     = 'Diagnostik (supportrapport)'
            $script:Msg.ActionCleanup      = 'Rens modeller'
            $script:Msg.ActionPrompt       = 'Valg [1-4, Enter=1]'
            # Select Model
            $script:Msg.InvalidModel       = 'Ugyldig modelvariant: {0}'
            $script:Msg.ValidVariants      = 'Gyldige varianter: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b'
            $script:Msg.RamWarnModel       = 'Denne model anbefaler mindst {0}GB RAM'
            $script:Msg.RamWarnSys         = 'Dit system har {0}GB RAM'
            $script:Msg.ContinueAnyway     = 'Fortsæt alligevel?'
            $script:Msg.ConfirmPrompt      = '[j/N]'
            $script:Msg.ConfirmPattern     = '^[jJyY]$'
            $script:Msg.Aborted            = 'Afbrudt.'
            $script:Msg.SelectedModel      = 'Valgt model: {0}'
            $script:Msg.ProceedNonInteract = 'Fortsætter...'
            $script:Msg.InternalError      = 'Intern fejl: ModelName er ikke sat'
            # Preflight
            $script:Msg.Preflight          = 'Udfører forhåndskontrol...'
            $script:Msg.PlatformError      = 'Dette script er kun til Windows'
            $script:Msg.PlatformMacHint    = 'Til macOS: scripts/setup-ollama-mac.sh'
            $script:Msg.PlatformLinuxHint  = 'Til Linux: scripts/setup-ollama-linux.sh'
            $script:Msg.DiskInsufficient   = 'Ikke nok diskplads: {0}GB tilgængelig, {1}GB krævet'
            $script:Msg.DiskOk             = 'Diskplads: {0}GB tilgængelig'
            $script:Msg.NetworkError       = 'Ingen netværksforbindelse til ollama.com'
            $script:Msg.NetworkHint        = 'Kontrollér: Invoke-WebRequest -Uri https://ollama.com'
            $script:Msg.NetworkOk          = 'Netværksforbindelse OK'
            $script:Msg.GpuDetected        = 'GPU registreret: {0}'
            $script:Msg.GpuNone            = 'Ingen GPU registreret – behandling uden GPU-acceleration'
            # Status
            $script:Msg.StatusTitle        = 'Hablará Ollama-status (Windows)'
            $script:Msg.StatusInstalled    = 'Ollama installeret (v{0})'
            $script:Msg.StatusUpdateRec    = '    {0} Opdatering anbefales (minimum v{1}): winget upgrade Ollama.Ollama'
            $script:Msg.StatusNotFound     = 'Ollama ikke fundet'
            $script:Msg.StatusServerOk     = 'Server kører'
            $script:Msg.StatusServerFail   = 'Server ikke tilgængelig'
            $script:Msg.StatusGpuNvidia    = 'NVIDIA (CUDA-acceleration)'
            $script:Msg.StatusGpuAmd       = 'AMD (ROCm-acceleration, eksperimentel)'
            $script:Msg.StatusNoGpu        = 'Ingen GPU – behandling uden GPU-acceleration'
            $script:Msg.StatusBaseModel    = 'Basismodel: {0}'
            $script:Msg.StatusBaseModels   = 'Basismodeller:'
            $script:Msg.StatusNoBase       = 'Ingen basismodel fundet'
            $script:Msg.StatusHablaraModel = 'Hablará-model: {0}'
            $script:Msg.StatusHablaraModels= 'Hablará-modeller:'
            $script:Msg.StatusNoHablara    = 'Ingen Hablará-model fundet'
            $script:Msg.StatusBaseMissing  = '    {0} Basismodel mangler – Hablará-model kræver den som grundlag'
            $script:Msg.StatusInfSkip      = 'Modeltest sprunget over (server ikke tilgængelig)'
            $script:Msg.StatusModelOk      = 'Model svarer'
            $script:Msg.StatusModelFail    = 'Model svarer ikke'
            $script:Msg.StatusStorage      = 'Lagringsforbrug (Hablará): ~{0} GB'
            $script:Msg.StatusStorageUnk   = 'Lagringsforbrug: kan ikke bestemmes'
            $script:Msg.StatusAllOk        = 'Alt er i orden.'
            $script:Msg.StatusProblems     = '{0} problem(er) fundet.'
            $script:Msg.StatusRepair       = '    Reparer: .\setup-ollama-win.ps1'
            # Diagnose
            $script:Msg.DiagnoseTitle      = '=== Hablará Ollama Diagnostikrapport ==='
            $script:Msg.DiagnoseSystem     = 'System:'
            $script:Msg.DiagnoseOllama     = 'Ollama:'
            $script:Msg.DiagnoseModels     = 'Hablará-modeller:'
            $script:Msg.DiagnoseStorage    = 'Lagring (Hablará):'
            $script:Msg.DiagnoseLog        = 'Ollama-log (seneste fejl):'
            $script:Msg.DiagnoseCreated    = 'Oprettet:'
            $script:Msg.DiagnoseScript     = 'Script:'
            $script:Msg.DiagnoseSaved      = 'Rapport gemt: {0}'
            $script:Msg.DiagnoseSaveFailed = 'Rapporten kunne ikke gemmes'
            $script:Msg.DiagnoseRamAvail   = 'tilgængelig'
            $script:Msg.DiagnoseStorFree   = 'fri'
            $script:Msg.DiagnoseStorDisk   = 'Lagring:'
            $script:Msg.DiagnoseUnknown    = 'ukendt'
            $script:Msg.DiagnoseNotInst    = 'ikke installeret'
            $script:Msg.DiagnoseNotReach   = 'ikke tilgængelig'
            $script:Msg.DiagnoseRunning    = 'kører'
            $script:Msg.DiagnoseNoModels   = '    [ingen Hablará-modeller fundet]'
            $script:Msg.DiagnoseNoErrors   = '    [ingen fejl fundet]'
            $script:Msg.DiagnoseNoLog      = '    [logfil ikke fundet: {0}]'
            $script:Msg.DiagnoseLogUnread  = '    [logfil kunne ikke læses: {0}]'
            $script:Msg.DiagnoseGpuNone    = 'Ingen'
            $script:Msg.DiagnoseResponds   = '(svarer)'
            # Install
            $script:Msg.Installing         = 'Installerer Ollama...'
            $script:Msg.OllamaAlready      = 'Ollama er allerede installeret'
            $script:Msg.OllamaVersion      = 'Version: {0}'
            $script:Msg.ServerStartFailed  = 'Kunne ikke starte Ollama-server'
            $script:Msg.ServerStartHint    = 'Start manuelt: ollama serve'
            $script:Msg.UsingWinget        = 'Bruger winget (timeout: 10 minutter)...'
            $script:Msg.WingetTimeout      = 'winget install timeout efter 10 minutter'
            $script:Msg.WingetFailed       = 'winget-installation mislykkedes: {0}'
            $script:Msg.OllamaInstalled    = 'Ollama installeret via winget'
            $script:Msg.WaitForAutoStart   = 'Venter på automatisk start af Ollama-appen...'
            $script:Msg.RebootRequired     = 'En genstart af computeren kan være nødvendig'
            $script:Msg.OllamaPathError    = 'Ollama installeret, men CLI er ikke i PATH. Åbn en ny terminal eller kontrollér PATH.'
            $script:Msg.ServerStartWarn    = 'Serverstart mislykkedes – start manuelt: ollama serve'
            $script:Msg.ManualInstall      = 'Installer Ollama manuelt: https://ollama.com/download'
            $script:Msg.ManualRerun        = 'Kør derefter dette script igen.'
            $script:Msg.OllamaFound        = 'Ollama fundet: {0}'
            $script:Msg.OllamaAppStart     = 'Starter Ollama-app...'
            $script:Msg.OllamaServeStart   = 'Starter Ollama-server (ollama serve)...'
            $script:Msg.OllamaProcessExit  = 'Ollama-proces afsluttet (kode: {0})'
            $script:Msg.PortBusy           = 'Port 11434 er optaget, venter på Ollama API...'
            $script:Msg.PortBusyWarn       = 'Port 11434 optaget, men Ollama API svarer ikke'
            $script:Msg.VersionWarn        = 'Ollama-version {0} er ældre end anbefalet ({1})'
            $script:Msg.UpdateHint         = 'Opdatér: winget upgrade Ollama.Ollama'
            # Model Download
            $script:Msg.DownloadingBase    = 'Henter basismodel...'
            $script:Msg.ModelExists        = 'Model findes allerede: {0}'
            $script:Msg.DownloadingModel   = 'Henter {0} ({1}, tager nogle minutter afhængigt af forbindelsen)...'
            $script:Msg.DownloadResumeTip  = 'Tip: Hvis afbrudt (Ctrl+C) genoptages download ved genstart'
            $script:Msg.DownloadHardTimeout= 'Hård timeout efter {0} minutter – afbryder'
            $script:Msg.DownloadStall      = 'Ingen downloadfremgang i {0} minutter – afbryder'
            $script:Msg.DownloadRunning    = '  Download i gang... ({0}m {1}s)'
            $script:Msg.DownloadTimeoutW   = 'Download-timeout efter {0} minutter (forsøg {1}/3)'
            $script:Msg.DownloadFailedW    = 'Download mislykkedes (forsøg {0}/3)'
            $script:Msg.DownloadRetry      = 'Næste forsøg om 5s...'
            $script:Msg.DownloadFailed     = 'Modeldownload mislykkedes efter 3 forsøg'
            $script:Msg.DownloadManual     = 'Prøv manuelt: ollama pull {0}'
            $script:Msg.DownloadDone       = 'Model hentet: {0}'
            # Custom Model
            $script:Msg.CreatingCustom     = 'Opretter Hablará-model...'
            $script:Msg.UpdatingCustom     = 'Opdaterer eksisterende Hablará-model...'
            $script:Msg.CustomExists       = 'Hablará-model {0} findes allerede.'
            $script:Msg.CustomSkip         = 'Spring over (ingen ændringer)'
            $script:Msg.CustomUpdateOpt    = 'Opdatér Hablará-model'
            $script:Msg.CustomUpdatePrompt = 'Valg [1-2, Enter=1]'
            $script:Msg.CustomKept         = 'Hablará-model beholdt'
            $script:Msg.CustomPresent      = 'Hablará-model findes allerede'
            $script:Msg.UsingHablaraConf   = 'Bruger Hablará-konfiguration'
            $script:Msg.UsingDefaultConf   = 'Bruger standardkonfiguration'
            $script:Msg.ConfigReadError    = 'Kunne ikke læse konfiguration: {0}'
            $script:Msg.CustomCreating      = 'Opretter Hablará-model {0}...'
            $script:Msg.CustomCreateTO     = 'ollama create timeout efter 120s – bruger basismodel'
            $script:Msg.CustomCreateFail   = 'Hablará-model kunne ikke {0} – bruger basismodel'
            $script:Msg.CustomDone         = 'Hablará-model {0}: {1}'
            $script:Msg.ConfigError        = 'Konfigurationsfejl'
            $script:Msg.PermsWarn          = 'Kunne ikke angive begrænsede tilladelser: {0}'
            $script:Msg.VerbCreated        = 'oprettet'
            $script:Msg.VerbUpdated        = 'opdateret'
            # Verify
            $script:Msg.Verifying          = 'Verificerer installation...'
            $script:Msg.OllamaNotFound     = 'Ollama ikke fundet'
            $script:Msg.ServerUnreachable  = 'Ollama-server ikke tilgængelig'
            $script:Msg.BaseNotFound       = 'Basismodel ikke fundet: {0}'
            $script:Msg.BaseOk             = 'Basismodel tilgængelig: {0}'
            $script:Msg.CustomOk           = 'Hablará-model tilgængelig: {0}'
            $script:Msg.CustomUnavail      = 'Hablará-model ikke tilgængelig (bruger basismodel)'
            $script:Msg.InferenceFailed    = 'Modeltest mislykkedes, test i appen'
            $script:Msg.SetupDone          = 'Installation fuldført!'
            # Main Summary
            $script:Msg.SetupComplete      = 'Hablará Ollama-installation fuldført!'
            $script:Msg.Installed          = 'Installeret:'
            $script:Msg.BaseModelLabel     = '  Basismodel:       '
            $script:Msg.HablaraModelLabel  = '  Hablará-model:  '
            $script:Msg.OllamaConfig       = 'Ollama-konfiguration:'
            $script:Msg.ModelLabel         = '  Model:     '
            $script:Msg.BaseUrlLabel       = '  Basis-URL: '
            $script:Msg.Docs               = 'Dokumentation: https://github.com/fidpa/hablara'
            # Misc
            $script:Msg.TestModel          = 'Tester model...'
            $script:Msg.TestOk             = 'Modeltest lykkedes'
            $script:Msg.TestFail           = 'Modeltest mislykkedes'
            $script:Msg.WaitServer         = 'Venter på Ollama-server...'
            $script:Msg.ServerReady        = 'Ollama-server er klar'
            $script:Msg.ServerAlready      = 'Ollama-server kører allerede'
            $script:Msg.ServerNoResponse   = 'Ollama-server svarer ikke efter {0}s'
            $script:Msg.SetupFailed        = 'Installation mislykkedes'
            $script:Msg.OllamaListTimeout  = 'ollama list timeout (15s) ved modelkontrol'
            # Cleanup
            $script:Msg.CleanupNeedsTTY    = '-Cleanup kræver en interaktiv session'
            $script:Msg.CleanupNoOllama    = 'Ollama ikke fundet'
            $script:Msg.CleanupNoServer    = 'Ollama-server ikke tilgængelig'
            $script:Msg.CleanupStartHint   = 'Start Ollama og prøv igen'
            $script:Msg.CleanupInstalled   = 'Installerede Hablará-varianter:'
            $script:Msg.CleanupPrompt      = 'Hvilken variant skal fjernes? (nummer, Enter=annullér)'
            $script:Msg.CleanupInvalid     = 'Ugyldigt valg'
            $script:Msg.CleanupDeleted     = '{0} fjernet'
            $script:Msg.CleanupTimeout     = '{0} kunne ikke fjernes: Timeout (30s)'
            $script:Msg.CleanupFailed      = '{0} kunne ikke fjernes: {1}'
            $script:Msg.CleanupUnknownErr  = 'ukendt fejl'
            $script:Msg.CleanupNoneLeft    = 'Ingen Hablará-modeller installeret længere. Kør installationen igen for at installere en model.'
            $script:Msg.CleanupNoModels    = 'Ingen Hablará-modeller fundet.'
            # Help
            $script:Msg.HelpTitle          = 'Hablará Ollama Setup v{0} (Windows)'
            $script:Msg.HelpDescription    = '  Installerer Ollama og konfigurerer en optimeret Hablará-model.'
            $script:Msg.HelpUsage          = 'Brug:'
            $script:Msg.HelpUsageLine      = '  .\setup-ollama-win.ps1 [TILVALG]'
            $script:Msg.HelpOptions        = 'Tilvalg:'
            $script:Msg.HelpOptModel       = '  -Model VARIANT        Vælg modelvariant: 1.5b, 3b, 7b, qwen3-8b (standard: 3b)'
            $script:Msg.HelpOptUpdate      = '  -Update               Gengenerér Hablará tilpasset model (opdatér Modelfile)'
            $script:Msg.HelpOptStatus      = '  -Status               Sundhedstjek: 7-punkts Ollama-installationskontrol'
            $script:Msg.HelpOptDiagnose    = '  -Diagnose             Generér supportrapport (klartekst, kopierbar)'
            $script:Msg.HelpOptCleanup     = '  -Cleanup              Fjern installeret variant interaktivt'
            $script:Msg.HelpOptLang        = '  -Lang da|de|en|es|fr|it|nl|pl|pt|sv  Sprog (da=dansk, de=tysk, en=engelsk, es=spansk, fr=fransk, it=italiensk, nl=nederlandsk, pl=polsk, pt=portugisisk, sv=svensk)'
            $script:Msg.HelpOptHelp        = '  -Help                 Vis denne hjælp'
            $script:Msg.HelpNoOpts         = '  Uden tilvalg startes en interaktiv menu.'
            $script:Msg.HelpVariants       = 'Modelvarianter:'
            $script:Msg.HelpExamples       = 'Eksempler:'
            $script:Msg.HelpExModel        = '  .\setup-ollama-win.ps1 -Model 3b       Installer 3b-variant'
            $script:Msg.HelpExUpdate       = '  .\setup-ollama-win.ps1 -Update         Opdatér tilpasset model'
            $script:Msg.HelpExStatus       = '  .\setup-ollama-win.ps1 -Status         Kontrollér installation'
            $script:Msg.HelpExDiagnose     = '  .\setup-ollama-win.ps1 -Diagnose       Opret fejlrapport'
            $script:Msg.HelpExCleanup      = '  .\setup-ollama-win.ps1 -Cleanup        Fjern variant'
            $script:Msg.HelpExitCodes      = 'Afslutningskoder:'
            $script:Msg.HelpExit0          = '  0  Lykkedes'
            $script:Msg.HelpExit1          = '  1  Generel fejl'
            $script:Msg.HelpExit2          = '  2  Ikke nok diskplads'
            $script:Msg.HelpExit3          = '  3  Ingen netværksforbindelse'
            $script:Msg.HelpExit4          = '  4  Forkert platform'
            $script:Msg.AutoInstallFailed  = 'Ollama kunne ikke installeres automatisk'
            # Hardware Detection
            $script:Msg.HwDetectionHeader  = 'Hardware-detektion:'
            $script:Msg.HwBandwidth        = 'Hukommelsesbåndbredde: ~{0} GB/s · {1} GB RAM'
            $script:Msg.HwRecommendation   = 'Modelanbefaling til din hardware:'
            $script:Msg.HwLocalTooSlow     = 'Lokale modeller vil være langsomme på denne hardware'
            $script:Msg.HwCloudHint        = 'Anbefaling: OpenAI eller Anthropic API for den bedste oplevelse'
            $script:Msg.HwProceedLocal     = 'Installér lokalt alligevel? [j/N]'
            $script:Msg.HwTagRecommended   = 'anbefalet'
            $script:Msg.HwTagSlow          = 'langsom'
            $script:Msg.HwTagTooSlow       = 'for langsom'
            $script:Msg.ChoicePromptHw     = 'Valg [1-4, Enter={0}]'
            $script:Msg.HwUnknownChip      = 'Ukendt processor — ingen båndbreddeanbefaling mulig'
            $script:Msg.HwMultiCallHint   = 'Hablará udfører flere analysetrin per optagelse'
            # Benchmark
            $script:Msg.BenchResult        = 'Benchmark: ~{0} tok/s med {1}'
            $script:Msg.BenchExcellent     = 'Fremragende — din hardware håndterer denne model med lethed'
            $script:Msg.BenchGood          = 'Godt — denne model kører godt på din hardware'
            $script:Msg.BenchMarginal      = 'Grænsetilfælde — en mindre model giver en mere flydende oplevelse'
            $script:Msg.BenchTooSlow       = 'For langsomt — en mindre model eller cloud-udbyder anbefales'
            $script:Msg.BenchSkip          = 'Benchmark sprunget over (måling mislykkedes)'
        }
        default {
            $script:Msg.ErrorPrefix        = 'Fehler'
            # Model Menu
            $script:Msg.ChooseModel        = 'Wähle ein Modell:'
            $script:Msg.ChoicePrompt       = 'Auswahl [1-4, Enter=1]'
            $script:Msg.Model3B            = 'Optimale Gesamtleistung [Standard]'
            $script:Msg.Model1_5B          = 'Schnell, eingeschränkte Genauigkeit [Einstieg]'
            $script:Msg.Model7B            = 'Erfordert sehr leistungsfähige Hardware'
            $script:Msg.ModelQwen3         = 'Beste Argumentationsanalyse [Premium]'
            # Main Menu
            $script:Msg.ChooseAction       = 'Wähle eine Aktion:'
            $script:Msg.ActionSetup        = 'Ollama einrichten oder aktualisieren'
            $script:Msg.ActionStatus       = 'Status prüfen'
            $script:Msg.ActionDiagnose     = 'Diagnose (Support-Report)'
            $script:Msg.ActionCleanup      = 'Modelle aufräumen'
            $script:Msg.ActionPrompt       = 'Auswahl [1-4, Enter=1]'
            # Select Model
            $script:Msg.InvalidModel       = 'Ungültige Modell-Variante: {0}'
            $script:Msg.ValidVariants      = 'Gültige Varianten: qwen2.5-1.5b, qwen2.5-3b, qwen2.5-7b, qwen3-8b'
            $script:Msg.RamWarnModel       = 'Dieses Modell empfiehlt mindestens {0}GB RAM'
            $script:Msg.RamWarnSys         = 'Dein System hat {0}GB RAM'
            $script:Msg.ContinueAnyway     = 'Trotzdem fortfahren?'
            $script:Msg.ConfirmPrompt      = '[j/N]'
            $script:Msg.ConfirmPattern     = '^[jJyY]$'
            $script:Msg.Aborted            = 'Abgebrochen.'
            $script:Msg.SelectedModel      = 'Ausgewähltes Modell: {0}'
            $script:Msg.ProceedNonInteract = 'Fahre fort...'
            $script:Msg.InternalError      = 'Interner Fehler: ModelName nicht gesetzt'
            # Preflight
            $script:Msg.Preflight          = 'Führe Vorab-Prüfungen durch...'
            $script:Msg.PlatformError      = 'Dieses Script ist nur für Windows'
            $script:Msg.PlatformMacHint    = 'Für macOS: scripts/setup-ollama-mac.sh'
            $script:Msg.PlatformLinuxHint  = 'Für Linux: scripts/setup-ollama-linux.sh'
            $script:Msg.DiskInsufficient   = 'Nicht genügend Speicher: {0}GB verfügbar, {1}GB benötigt'
            $script:Msg.DiskOk             = 'Speicherplatz: {0}GB verfügbar'
            $script:Msg.NetworkError       = 'Keine Netzwerkverbindung zu ollama.com'
            $script:Msg.NetworkHint        = 'Prüfe: Invoke-WebRequest -Uri https://ollama.com'
            $script:Msg.NetworkOk          = 'Netzwerkverbindung OK'
            $script:Msg.GpuDetected        = 'GPU erkannt: {0}'
            $script:Msg.GpuNone            = 'Keine GPU erkannt - Verarbeitung ohne GPU-Beschleunigung'
            # Status
            $script:Msg.StatusTitle        = 'Hablará Ollama Status (Windows)'
            $script:Msg.StatusInstalled    = 'Ollama installiert (v{0})'
            $script:Msg.StatusUpdateRec    = '    {0} Update empfohlen (mindestens v{1}): winget upgrade Ollama.Ollama'
            $script:Msg.StatusNotFound     = 'Ollama nicht gefunden'
            $script:Msg.StatusServerOk     = 'Server läuft'
            $script:Msg.StatusServerFail   = 'Server nicht erreichbar'
            $script:Msg.StatusGpuNvidia    = 'NVIDIA (CUDA-Beschleunigung)'
            $script:Msg.StatusGpuAmd       = 'AMD (ROCm-Beschleunigung, experimentell)'
            $script:Msg.StatusNoGpu        = 'Keine GPU — Verarbeitung ohne GPU-Beschleunigung'
            $script:Msg.StatusBaseModel    = 'Basis-Modell: {0}'
            $script:Msg.StatusBaseModels   = 'Basis-Modelle:'
            $script:Msg.StatusNoBase       = 'Kein Basis-Modell gefunden'
            $script:Msg.StatusHablaraModel = 'Hablará-Modell: {0}'
            $script:Msg.StatusHablaraModels= 'Hablará-Modelle:'
            $script:Msg.StatusNoHablara    = 'Kein Hablará-Modell gefunden'
            $script:Msg.StatusBaseMissing  = '    {0} Basis-Modell fehlt — Hablará-Modell benötigt es als Grundlage'
            $script:Msg.StatusInfSkip      = 'Modell-Test übersprungen (Server nicht erreichbar)'
            $script:Msg.StatusModelOk      = 'Modell antwortet'
            $script:Msg.StatusModelFail    = 'Modell antwortet nicht'
            $script:Msg.StatusStorage      = 'Speicherverbrauch (Hablará): ~{0} GB'
            $script:Msg.StatusStorageUnk   = 'Speicherverbrauch: nicht ermittelbar'
            $script:Msg.StatusAllOk        = 'Alles in Ordnung.'
            $script:Msg.StatusProblems     = '{0} Problem(e) gefunden.'
            $script:Msg.StatusRepair       = '    Reparieren: .\setup-ollama-win.ps1'
            # Diagnose
            $script:Msg.DiagnoseTitle      = '=== Hablará Ollama Diagnose-Report ==='
            $script:Msg.DiagnoseSystem     = 'System:'
            $script:Msg.DiagnoseOllama     = 'Ollama:'
            $script:Msg.DiagnoseModels     = 'Hablará-Modelle:'
            $script:Msg.DiagnoseStorage    = 'Speicher (Hablará):'
            $script:Msg.DiagnoseLog        = 'Ollama-Log (letzte Fehler):'
            $script:Msg.DiagnoseCreated    = 'Erstellt:'
            $script:Msg.DiagnoseScript     = 'Script:'
            $script:Msg.DiagnoseSaved      = 'Report gespeichert: {0}'
            $script:Msg.DiagnoseSaveFailed = 'Report konnte nicht gespeichert werden'
            $script:Msg.DiagnoseRamAvail   = 'verfügbar'
            $script:Msg.DiagnoseStorFree   = 'frei'
            $script:Msg.DiagnoseStorDisk   = 'Speicher:'
            $script:Msg.DiagnoseUnknown    = 'unbekannt'
            $script:Msg.DiagnoseNotInst    = 'nicht installiert'
            $script:Msg.DiagnoseNotReach   = 'nicht erreichbar'
            $script:Msg.DiagnoseRunning    = 'läuft'
            $script:Msg.DiagnoseNoModels   = '    [keine Hablará-Modelle gefunden]'
            $script:Msg.DiagnoseNoErrors   = '    [keine Fehler gefunden]'
            $script:Msg.DiagnoseNoLog      = '    [Log-Datei nicht gefunden: {0}]'
            $script:Msg.DiagnoseLogUnread  = '    [Log-Datei nicht lesbar: {0}]'
            $script:Msg.DiagnoseGpuNone    = 'Keine'
            $script:Msg.DiagnoseResponds   = '(antwortet)'
            # Install
            $script:Msg.Installing         = 'Installiere Ollama...'
            $script:Msg.OllamaAlready      = 'Ollama bereits installiert'
            $script:Msg.OllamaVersion      = 'Version: {0}'
            $script:Msg.ServerStartFailed  = 'Konnte Ollama Server nicht starten'
            $script:Msg.ServerStartHint    = 'Manuell starten: ollama serve'
            $script:Msg.UsingWinget        = 'Verwende winget (Timeout: 10 Minuten)...'
            $script:Msg.WingetTimeout      = 'winget install Timeout nach 10 Minuten'
            $script:Msg.WingetFailed       = 'winget Installation fehlgeschlagen: {0}'
            $script:Msg.OllamaInstalled    = 'Ollama via winget installiert'
            $script:Msg.WaitForAutoStart   = 'Warte auf automatischen Start der Ollama-App...'
            $script:Msg.RebootRequired     = 'Ein Neustart des Computers kann erforderlich sein'
            $script:Msg.OllamaPathError    = 'Ollama installiert, aber CLI nicht im PATH. Neues Terminal öffnen oder PATH prüfen.'
            $script:Msg.ServerStartWarn    = 'Server-Start fehlgeschlagen - manuell starten: ollama serve'
            $script:Msg.ManualInstall      = 'Bitte Ollama manuell installieren: https://ollama.com/download'
            $script:Msg.ManualRerun        = 'Danach dieses Script erneut ausführen.'
            $script:Msg.OllamaFound        = 'Ollama gefunden: {0}'
            $script:Msg.OllamaAppStart     = 'Starte Ollama App...'
            $script:Msg.OllamaServeStart   = 'Starte Ollama Server (ollama serve)...'
            $script:Msg.OllamaProcessExit  = 'Ollama Prozess beendet (Code: {0})'
            $script:Msg.PortBusy           = 'Port 11434 ist belegt, warte auf Ollama API...'
            $script:Msg.PortBusyWarn       = 'Port 11434 belegt, aber Ollama API antwortet nicht'
            $script:Msg.VersionWarn        = 'Ollama Version {0} ist älter als empfohlen ({1})'
            $script:Msg.UpdateHint         = 'Update: winget upgrade Ollama.Ollama'
            # Model Download
            $script:Msg.DownloadingBase    = 'Lade Basis-Modell herunter...'
            $script:Msg.ModelExists        = 'Modell bereits vorhanden: {0}'
            $script:Msg.DownloadingModel   = 'Lade {0} ({1}, dauert mehrere Minuten je nach Verbindung)...'
            $script:Msg.DownloadResumeTip  = 'Tipp: Bei Abbruch (Ctrl+C) setzt ein erneuter Start den Download fort'
            $script:Msg.DownloadHardTimeout= 'Hard-Timeout nach {0} Minuten — Abbruch'
            $script:Msg.DownloadStall      = 'Kein Download-Fortschritt seit {0} Minuten — Abbruch'
            $script:Msg.DownloadRunning    = '  Download läuft... ({0}m {1}s)'
            $script:Msg.DownloadTimeoutW   = 'Download-Timeout nach {0} Minuten (Versuch {1}/3)'
            $script:Msg.DownloadFailedW    = 'Download fehlgeschlagen (Versuch {0}/3)'
            $script:Msg.DownloadRetry      = 'Nächster Versuch in 5s...'
            $script:Msg.DownloadFailed     = 'Modell-Download fehlgeschlagen nach 3 Versuchen'
            $script:Msg.DownloadManual     = 'Manuell versuchen: ollama pull {0}'
            $script:Msg.DownloadDone       = 'Modell heruntergeladen: {0}'
            # Custom Model
            $script:Msg.CreatingCustom     = 'Erstelle Hablará-Modell...'
            $script:Msg.UpdatingCustom     = 'Aktualisiere bestehendes Hablará-Modell...'
            $script:Msg.CustomExists       = 'Hablará-Modell {0} bereits vorhanden.'
            $script:Msg.CustomSkip         = 'Überspringen (keine Änderung)'
            $script:Msg.CustomUpdateOpt    = 'Hablará-Modell aktualisieren'
            $script:Msg.CustomUpdatePrompt = 'Auswahl [1-2, Enter=1]'
            $script:Msg.CustomKept         = 'Hablará-Modell beibehalten'
            $script:Msg.CustomPresent      = 'Hablará-Modell bereits vorhanden'
            $script:Msg.UsingHablaraConf   = 'Verwende Hablará-Konfiguration'
            $script:Msg.UsingDefaultConf   = 'Verwende Standard-Konfiguration'
            $script:Msg.ConfigReadError    = 'Konnte Konfiguration nicht lesen: {0}'
            $script:Msg.CustomCreating      = 'Erstelle Hablará-Modell {0}...'
            $script:Msg.CustomCreateTO     = 'ollama create Timeout nach 120s — verwende Basis-Modell'
            $script:Msg.CustomCreateFail   = 'Hablará-Modell konnte nicht {0} werden - verwende Basis-Modell'
            $script:Msg.CustomDone         = 'Hablará-Modell {0}: {1}'
            $script:Msg.ConfigError        = 'Konfigurationsfehler'
            $script:Msg.PermsWarn          = 'Konnte restriktive Berechtigungen nicht setzen: {0}'
            $script:Msg.VerbCreated        = 'erstellt'
            $script:Msg.VerbUpdated        = 'aktualisiert'
            # Verify
            $script:Msg.Verifying          = 'Überprüfe Installation...'
            $script:Msg.OllamaNotFound     = 'Ollama nicht gefunden'
            $script:Msg.ServerUnreachable  = 'Ollama Server nicht erreichbar'
            $script:Msg.BaseNotFound       = 'Basis-Modell nicht gefunden: {0}'
            $script:Msg.BaseOk             = 'Basis-Modell verfügbar: {0}'
            $script:Msg.CustomOk           = 'Hablará-Modell verfügbar: {0}'
            $script:Msg.CustomUnavail      = 'Hablará-Modell nicht verfügbar (verwende Basis-Modell)'
            $script:Msg.InferenceFailed    = 'Modell-Test fehlgeschlagen, teste in der App'
            $script:Msg.SetupDone          = 'Setup abgeschlossen!'
            # Main Summary
            $script:Msg.SetupComplete      = 'Hablará Ollama Setup abgeschlossen!'
            $script:Msg.Installed          = 'Installiert:'
            $script:Msg.BaseModelLabel     = '  Basis-Modell:   '
            $script:Msg.HablaraModelLabel  = '  Hablará-Modell: '
            $script:Msg.OllamaConfig       = 'Ollama-Konfiguration:'
            $script:Msg.ModelLabel         = '  Modell:   '
            $script:Msg.BaseUrlLabel       = '  Base URL: '
            $script:Msg.Docs               = 'Dokumentation: https://github.com/fidpa/hablara'
            # Misc
            $script:Msg.TestModel          = 'Teste Modell...'
            $script:Msg.TestOk             = 'Modell-Test erfolgreich'
            $script:Msg.TestFail           = 'Modell-Test fehlgeschlagen'
            $script:Msg.WaitServer         = 'Warte auf Ollama Server...'
            $script:Msg.ServerReady        = 'Ollama Server ist bereit'
            $script:Msg.ServerAlready      = 'Ollama Server läuft bereits'
            $script:Msg.ServerNoResponse   = 'Ollama Server antwortet nicht nach {0}s'
            $script:Msg.SetupFailed        = 'Setup fehlgeschlagen'
            $script:Msg.OllamaListTimeout  = 'ollama list Timeout (15s) bei Modell-Prüfung'
            # Cleanup
            $script:Msg.CleanupNeedsTTY    = '-Cleanup erfordert eine interaktive Sitzung'
            $script:Msg.CleanupNoOllama    = 'Ollama nicht gefunden'
            $script:Msg.CleanupNoServer    = 'Ollama Server nicht erreichbar'
            $script:Msg.CleanupStartHint   = 'Starte Ollama und versuche es erneut'
            $script:Msg.CleanupInstalled   = 'Installierte Hablará-Varianten:'
            $script:Msg.CleanupPrompt      = 'Welche Variante löschen? (Nummer, Enter=abbrechen)'
            $script:Msg.CleanupInvalid     = 'Ungültige Auswahl'
            $script:Msg.CleanupDeleted     = '{0} gelöscht'
            $script:Msg.CleanupTimeout     = '{0} konnte nicht gelöscht werden: Timeout (30s)'
            $script:Msg.CleanupFailed      = '{0} konnte nicht gelöscht werden: {1}'
            $script:Msg.CleanupUnknownErr  = 'unbekannter Fehler'
            $script:Msg.CleanupNoneLeft    = 'Keine Hablará-Modelle mehr installiert. Führe das Setup erneut aus, um ein Modell zu installieren.'
            $script:Msg.CleanupNoModels    = 'Keine Hablará-Modelle gefunden.'
            # Help
            $script:Msg.HelpTitle          = 'Hablará Ollama Setup v{0} (Windows)'
            $script:Msg.HelpDescription    = '  Installiert Ollama und richtet ein optimiertes Hablará-Modell ein.'
            $script:Msg.HelpUsage          = 'Verwendung:'
            $script:Msg.HelpUsageLine      = '  .\setup-ollama-win.ps1 [OPTIONEN]'
            $script:Msg.HelpOptions        = 'Optionen:'
            $script:Msg.HelpOptModel       = '  -Model VARIANTE       Modell-Variante wählen: 1.5b, 3b, 7b, qwen3-8b (Standard: 3b)'
            $script:Msg.HelpOptUpdate      = '  -Update               Hablará-Custom-Modell neu erstellen (Modelfile aktualisieren)'
            $script:Msg.HelpOptStatus      = '  -Status               Health-Check: 7-Punkte-Prüfung der Ollama-Installation'
            $script:Msg.HelpOptDiagnose    = '  -Diagnose             Support-Report generieren (Plain-Text, kopierfähig)'
            $script:Msg.HelpOptCleanup     = '  -Cleanup              Installierte Variante interaktiv löschen (erfordert Terminal)'
            $script:Msg.HelpOptLang        = '  -Lang da|de|en|es|fr|it|nl|pl|pt|sv  Sprache (da=Dänisch, de=Deutsch, en=Englisch, es=Spanisch, fr=Französisch, it=Italienisch, nl=Niederländisch, pl=Polnisch, pt=Portugiesisch, sv=Schwedisch)'
            $script:Msg.HelpOptHelp        = '  -Help                 Diese Hilfe anzeigen'
            $script:Msg.HelpNoOpts         = '  Ohne Optionen startet ein interaktives Menü.'
            $script:Msg.HelpVariants       = 'Modell-Varianten:'
            $script:Msg.HelpExamples       = 'Beispiele:'
            $script:Msg.HelpExModel        = '  .\setup-ollama-win.ps1 -Model 3b       3b-Variante installieren'
            $script:Msg.HelpExUpdate       = '  .\setup-ollama-win.ps1 -Update         Custom-Modell aktualisieren'
            $script:Msg.HelpExStatus       = '  .\setup-ollama-win.ps1 -Status         Installation prüfen'
            $script:Msg.HelpExDiagnose     = '  .\setup-ollama-win.ps1 -Diagnose       Report für Bug-Ticket erstellen'
            $script:Msg.HelpExCleanup      = '  .\setup-ollama-win.ps1 -Cleanup        Variante entfernen'
            $script:Msg.HelpExitCodes      = 'Exit Codes:'
            $script:Msg.HelpExit0          = '  0  Erfolg'
            $script:Msg.HelpExit1          = '  1  Allgemeiner Fehler'
            $script:Msg.HelpExit2          = '  2  Nicht genügend Speicherplatz'
            $script:Msg.HelpExit3          = '  3  Keine Netzwerkverbindung'
            $script:Msg.HelpExit4          = '  4  Falsche Plattform'
            $script:Msg.AutoInstallFailed  = 'Ollama konnte nicht automatisch installiert werden'
            # Hardware Detection
            $script:Msg.HwDetectionHeader  = 'Hardware-Erkennung:'
            $script:Msg.HwBandwidth        = 'Speicherbandbreite: ~{0} GB/s · {1} GB RAM'
            $script:Msg.HwRecommendation   = 'Modell-Empfehlung für deine Hardware:'
            $script:Msg.HwLocalTooSlow     = 'Lokale Modelle werden auf dieser Hardware langsam sein'
            $script:Msg.HwCloudHint        = 'Empfehlung: OpenAI oder Anthropic API für beste Erfahrung'
            $script:Msg.HwProceedLocal     = 'Trotzdem lokal installieren? [j/N]'
            $script:Msg.HwTagRecommended   = 'empfohlen'
            $script:Msg.HwTagSlow          = 'langsam'
            $script:Msg.HwTagTooSlow       = 'zu langsam'
            $script:Msg.ChoicePromptHw     = 'Auswahl [1-4, Enter={0}]'
            $script:Msg.HwUnknownChip      = 'Unbekannter Prozessor — keine Bandbreiten-Empfehlung möglich'
            $script:Msg.HwMultiCallHint   = 'Hablará führt mehrere Analyse-Schritte pro Aufnahme aus'
            # Benchmark
            $script:Msg.BenchResult        = 'Benchmark: ~{0} tok/s mit {1}'
            $script:Msg.BenchExcellent     = 'Exzellent — deine Hardware bewältigt dieses Modell mühelos'
            $script:Msg.BenchGood          = 'Gut — dieses Modell läuft gut auf deiner Hardware'
            $script:Msg.BenchMarginal      = 'Grenzwertig — ein kleineres Modell sorgt für flüssigere Bedienung'
            $script:Msg.BenchTooSlow       = 'Zu langsam — ein kleineres Modell oder Cloud-Anbieter wird empfohlen'
            $script:Msg.BenchSkip          = 'Benchmark übersprungen (Messung fehlgeschlagen)'
        }
    }
}

# Status-Check helpers (2-space indent, matching Bash status output format)
function Write-StatusOk { param([string]$Message); Write-Host "  $([char]0x2713) " -ForegroundColor Green -NoNewline; Write-Host $Message }
function Write-StatusWarn { param([string]$Message); Write-Host "  $([char]0x26A0) " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
function Write-StatusFail { param([string]$Message); Write-Host "  $([char]0x2717) " -ForegroundColor Red -NoNewline; Write-Host $Message }
function Write-StatusNote { param([string]$Message); Write-Host "  $([char]0x2022) " -ForegroundColor Yellow -NoNewline; Write-Host $Message }

function Test-CommandExists { param([string]$Command); $null -ne (Get-Command $Command -ErrorAction SilentlyContinue) }

function Test-OllamaModelExists {
    param([string]$Model)
    if (-not (Test-CommandExists 'ollama')) { return $false }
    $result = Invoke-WithTimeout -TimeoutSeconds 15 -Command 'ollama' -Arguments @('list')
    if ($result.TimedOut) {
        Write-Warning $script:Msg.OllamaListTimeout
        return $false
    }
    if ($result.ExitCode -ne 0 -or -not $result.Output) { return $false }
    foreach ($line in $result.Output) {
        $name = ($line -split '\s+')[0]
        if ($name -eq $Model) { return $true }
    }
    return $false
}

function Test-InteractiveSession {
    try { return -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected }
    catch { return $false }
}

function Get-SystemRAMGB {
    try {
        $mem = Get-CimInstance -ClassName Win32_ComputerSystem -Property TotalPhysicalMemory -ErrorAction Stop
        return [math]::Floor($mem.TotalPhysicalMemory / 1GB)
    } catch { return 0 }
}

# Returns Ollama data path (respects OLLAMA_MODELS > default)
function Get-OllamaDataPath {
    if ($env:OLLAMA_MODELS -and [System.IO.Path]::IsPathRooted($env:OLLAMA_MODELS)) {
        return $env:OLLAMA_MODELS
    }
    return (Join-Path $env:USERPROFILE '.ollama')
}

function Get-FreeDiskSpaceGB {
    try {
        $ollamaPath = Get-OllamaDataPath
        if (-not (Test-Path $ollamaPath)) { $ollamaPath = $env:USERPROFILE }

        # Try PSDrive first (works for local drives)
        $driveInfo = $null
        $psDrive = (Get-Item $ollamaPath -ErrorAction SilentlyContinue).PSDrive
        if ($psDrive -and $psDrive.Free -gt 0) {
            return [math]::Floor($psDrive.Free / 1GB)
        }

        # Fallback for UNC paths and network drives: use WMI/CIM on the root path
        $root = [System.IO.Path]::GetPathRoot($ollamaPath)
        if ($root) {
            $driveInfo = [System.IO.DriveInfo]::new($root)
            return [math]::Floor($driveInfo.AvailableFreeSpace / 1GB)
        }

        return 0
    } catch { return 0 }
}

function Compare-SemanticVersion {
    param([string]$Version1, [string]$Version2)
    # Strip pre-release suffixes (e.g., "0.6.2-rc1" -> "0.6.2")
    $Version1 = ($Version1 -split '-')[0]
    $Version2 = ($Version2 -split '-')[0]
    $v1Parts = ($Version1 -replace '[^0-9.]', '') -split '\.' | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ }
    $v2Parts = ($Version2 -replace '[^0-9.]', '') -split '\.' | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ }

    for ($i = 0; $i -lt [Math]::Max($v1Parts.Length, $v2Parts.Length); $i++) {
        $p1 = if ($i -lt $v1Parts.Length) { $v1Parts[$i] } else { 0 }
        $p2 = if ($i -lt $v2Parts.Length) { $v2Parts[$i] } else { 0 }
        if ($p1 -lt $p2) { return -1 }
        if ($p1 -gt $p2) { return 1 }
    }
    return 0
}

function Test-GpuAvailable {
    if (Test-CommandExists 'nvidia-smi') {
        try {
            $null = & nvidia-smi 2>$null
            if ($LASTEXITCODE -eq 0) { return @{ Available = $true; Type = 'NVIDIA' } }
        } catch {}
    }
    $rocmBase = if ($env:ROCM_PATH) { $env:ROCM_PATH } else { 'C:\Program Files\AMD\ROCm' }
    if (Test-Path "$rocmBase\*\bin\rocm-smi.exe") {
        return @{ Available = $true; Type = 'AMD ROCm' }
    }
    return @{ Available = $false; Type = 'CPU' }
}

# GPU bandwidth lookup table (dedicated GPU VRAM bandwidth in GB/s)
function Get-GpuBandwidthLookup {
    param([string]$GpuName)
    switch -Wildcard ($GpuName) {
        '*4090*'        { return 1008 }
        '*4080*'        { return 717 }
        '*4070 Ti*'     { return 672 }
        '*4070*'        { return 504 }
        '*3090*'        { return 936 }
        '*3080*'        { return 760 }
        '*3070*'        { return 448 }
        '*3060 Ti*'     { return 448 }
        '*3060*'        { return 360 }
        '*2080*'        { return 448 }
        '*2070*'        { return 448 }
        '*7900 XTX*'    { return 960 }
        '*7900 XT*'     { return 800 }
        '*6800 XT*'     { return 512 }
        default         { return 0 }
    }
}

# Detect memory bandwidth in GB/s (Windows: GPU lookup or RAM speed estimation)
function Get-MemoryBandwidthGbps {
    # Try GPU bandwidth first
    if (Test-CommandExists 'nvidia-smi') {
        try {
            $gpuName = & nvidia-smi --query-gpu=name --format=csv,noheader 2>$null | Select-Object -First 1
            if ($gpuName) {
                $gpuBw = Get-GpuBandwidthLookup -GpuName $gpuName
                if ($gpuBw -gt 0) { return $gpuBw }
            }
        } catch {}
    }

    # Fallback: RAM speed via WMI
    try {
        $ramModules = Get-CimInstance -ClassName Win32_PhysicalMemory -Property Speed -ErrorAction Stop
        $maxSpeed = ($ramModules | Measure-Object -Property Speed -Maximum).Maximum
        if ($maxSpeed -and $maxSpeed -gt 0) {
            # Conservative dual-channel estimate: speed_mhz * 16 bytes / 1000
            return [math]::Floor($maxSpeed * 16 / 1000)
        }
    } catch {}

    return 0
}

# Recommend model size based on memory bandwidth
function Get-RecommendedModel {
    param([int]$Bandwidth)
    if ($Bandwidth -ge 500) { return 'qwen3-8b' }
    elseif ($Bandwidth -ge 300) { return '7b' }
    elseif ($Bandwidth -ge 150) { return '3b' }
    elseif ($Bandwidth -ge 50) { return '1.5b' }
    else { return 'none' }
}

# Estimate tokens per second: bw * factor / sizeX10
# Sizes from ollama list; factors calibrated from M4 Pro benchmarks
function Get-EstimatedToksPerSec {
    param([int]$Bandwidth, [string]$Model)
    $sizeX10, $factor = switch ($Model) {
        '1.5b'     { 10, 6 }
        '3b'       { 19, 7 }
        '7b'       { 47, 8 }
        'qwen3-8b' { 52, 8 }
        default    { 20, 6 }
    }
    return [math]::Floor($Bandwidth * $factor / $sizeX10)
}

# Format a single model rating line
function Write-ModelRatingLine {
    param([string]$ModelLabel, [int]$Toks, [bool]$IsRecommended)

    if ($Toks -ge 50) {
        $icon = [char]0x2713  # ✓
        $color = 'Green'
        $tag = if ($IsRecommended) { "[$($script:Msg.HwTagRecommended)]" } else { '' }
    } elseif ($Toks -ge 25) {
        $icon = [char]0x26A0  # ⚠
        $color = 'Yellow'
        $tag = "[$($script:Msg.HwTagSlow)]"
    } else {
        $icon = [char]0x2717  # ✗
        $color = 'Red'
        $tag = "[$($script:Msg.HwTagTooSlow)]"
    }

    $line = "  $icon  $($ModelLabel.PadRight(16)) ~$($Toks.ToString().PadLeft(3)) tok/s  $tag"
    Write-Host $line -ForegroundColor $color
}

# Show hardware-aware model recommendation
function Show-HardwareRecommendation {
    param([int]$Bandwidth)

    $systemRam = Get-SystemRAMGB

    Write-Host ""
    Write-Host $script:Msg.HwDetectionHeader -ForegroundColor Cyan
    Write-Info ($script:Msg.HwBandwidth -f $Bandwidth, $systemRam)

    $script:RecommendedModel = Get-RecommendedModel -Bandwidth $Bandwidth

    Write-Host ""
    Write-Host $script:Msg.HwRecommendation -ForegroundColor Cyan

    $toks15b = Get-EstimatedToksPerSec -Bandwidth $Bandwidth -Model '1.5b'
    $toks3b  = Get-EstimatedToksPerSec -Bandwidth $Bandwidth -Model '3b'
    $toks7b  = Get-EstimatedToksPerSec -Bandwidth $Bandwidth -Model '7b'
    $toksQ3  = Get-EstimatedToksPerSec -Bandwidth $Bandwidth -Model 'qwen3-8b'

    Write-ModelRatingLine -ModelLabel 'qwen2.5:1.5b' -Toks $toks15b -IsRecommended ($script:RecommendedModel -eq '1.5b')
    Write-ModelRatingLine -ModelLabel 'qwen2.5:3b'   -Toks $toks3b  -IsRecommended ($script:RecommendedModel -eq '3b')
    Write-ModelRatingLine -ModelLabel 'qwen2.5:7b'   -Toks $toks7b  -IsRecommended ($script:RecommendedModel -eq '7b')
    Write-ModelRatingLine -ModelLabel 'qwen3:8b'     -Toks $toksQ3  -IsRecommended ($script:RecommendedModel -eq 'qwen3-8b')
    Write-Host ""
    Write-Info "→ $($script:Msg.HwMultiCallHint)"

    if ($script:RecommendedModel -eq 'none') {
        Write-Host ""
        Write-Warning $script:Msg.HwLocalTooSlow
        Write-Info $script:Msg.HwCloudHint
        Write-Host ""

        if (Test-InteractiveSession) {
            $confirm = Read-Host $script:Msg.HwProceedLocal
            if ($confirm -notmatch $script:Msg.ConfirmPattern) {
                Write-Info $script:Msg.Aborted
                exit 0
            }
        }
        $script:RecommendedModel = $DefaultModel
    }

}

# Returns version string (e.g. "0.6.2") or localized "unknown"
function Get-OllamaVersionString {
    try {
        $versionOutput = & ollama --version 2>&1 | Select-Object -First 1
        if ($versionOutput -match '(\d+\.\d+\.?\d*)') { return $Matches[1] }
    } catch {}
    return $script:Msg.DiagnoseUnknown
}

function Test-OllamaVersion {
    $currentVersion = Get-OllamaVersionString
    if ($currentVersion -ne $script:Msg.DiagnoseUnknown) {
        if ((Compare-SemanticVersion $currentVersion $MinOllamaVersion) -lt 0) {
            Write-Warning ($script:Msg.VersionWarn -f $currentVersion, $MinOllamaVersion)
            Write-Info $script:Msg.UpdateHint
            return $false
        }
    }
    return $true
}

# Silent inference check: returns $true if model responds, $false otherwise (no log output)
function Test-ModelResponds {
    param([string]$Model, [int]$TimeoutSec = 60)
    try {
        $body = @{ model = $Model; prompt = "OK"; stream = $false; options = @{ num_predict = 5 } } | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "$OllamaApiUrl/api/generate" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec $TimeoutSec
        if ($response.response) { return $true }
    } catch {}
    return $false
}

function Test-ModelInference {
    param([string]$Model)
    Write-Info $script:Msg.TestModel

    if (Test-ModelResponds -Model $Model) { Write-Success $script:Msg.TestOk; return $true }
    Write-Warning $script:Msg.TestFail
    return $false
}

# Measure actual inference speed: returns tok/s as decimal number or $null
function Invoke-Benchmark {
    param([string]$Model = $script:CustomModelName)
    try {
        $body = @{
            model = $Model; prompt = "Describe in one sentence what you do."
            stream = $false; options = @{ num_predict = 30 }
        } | ConvertTo-Json
        $resp = Invoke-RestMethod -Uri "$OllamaApiUrl/api/generate" -Method Post `
            -Body $body -ContentType 'application/json' -TimeoutSec 60
        if (-not $resp.eval_count -or $resp.eval_count -eq 0 -or -not $resp.eval_duration -or $resp.eval_duration -eq 0) { return $null }
        [math]::Round($resp.eval_count / ($resp.eval_duration / 1e9), 1)
    } catch { return $null }
}

# Display benchmark result and persist to %APPDATA%\hablara\benchmark.json
function Show-BenchmarkResult {
    param([string]$Model = $script:CustomModelName)
    $toks = Invoke-Benchmark -Model $Model
    if ($null -eq $toks) { Write-Warning $script:Msg.BenchSkip; return }

    Write-Host ""
    if ($toks -ge 80) {
        Write-Success ($script:Msg.BenchResult -f $toks, $Model)
        Write-Info $script:Msg.BenchExcellent
    } elseif ($toks -ge 50) {
        Write-Success ($script:Msg.BenchResult -f $toks, $Model)
        Write-Info $script:Msg.BenchGood
    } elseif ($toks -ge 25) {
        Write-Warning ($script:Msg.BenchResult -f $toks, $Model)
        Write-Warning $script:Msg.BenchMarginal
    } else {
        Write-Warning ($script:Msg.BenchResult -f $toks, $Model)
        Write-Warning $script:Msg.BenchTooSlow
        Write-Info $script:Msg.HwCloudHint
    }

    # Persist benchmark result as multi-model map (atomic write, graceful fail)
    try {
        $configDir = Join-Path $env:APPDATA 'hablara'
        if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
        $tmpFile = Join-Path $configDir '.benchmark.json.tmp'
        $benchFile = Join-Path $configDir 'benchmark.json'
        $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        # Read existing map, merge current model entry
        $existing = @{}
        if (Test-Path $benchFile) {
            try {
                $raw = Get-Content -Path $benchFile -Raw -ErrorAction Stop
                $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
                foreach ($prop in $parsed.PSObject.Properties) {
                    $existing[$prop.Name] = $prop.Value
                }
            } catch {
                $existing = @{}
            }
        }
        $existing[$Model] = @{ toks_per_sec = $toks; measured_at = $ts }
        $json = $existing | ConvertTo-Json -Compress -Depth 3
        [System.IO.File]::WriteAllText($tmpFile, $json, [System.Text.UTF8Encoding]::new($false))
        Move-Item -Path $tmpFile -Destination $benchFile -Force
    } catch {}
}

function Wait-OllamaServer {
    param([int]$TimeoutSeconds = 30)
    $isInteractive = Test-InteractiveSession
    $spinChars = @([char]0x280B,[char]0x2819,[char]0x2839,[char]0x2838,
                   [char]0x283C,[char]0x2834,[char]0x2826,[char]0x2827,
                   [char]0x2807,[char]0x280F)
    $spinIdx = 0
    $attempt = 0

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $null = Invoke-RestMethod -Uri "$OllamaApiUrl/api/version" -TimeoutSec 2 -ErrorAction Stop
            if ($isInteractive) { Write-Host "`r$(' ' * 60)`r" -NoNewline }
            Write-Success $script:Msg.ServerReady
            return $true
        } catch {
            if ($isInteractive) {
                $c = $spinChars[$spinIdx % 10]
                Write-Host "`r    $c $($script:Msg.WaitServer) (${attempt}s)" -NoNewline
            }
            $spinIdx++
            $attempt++
            Start-Sleep -Seconds 1
        }
    }
    if ($isInteractive) { Write-Host "`r$(' ' * 60)`r" -NoNewline }
    Write-Err ($script:Msg.ServerNoResponse -f $TimeoutSeconds)
    return $false
}

function Test-PortInUse {
    param([int]$Port = 11434)
    try {
        $connection = New-Object System.Net.Sockets.TcpClient
        try {
            $task = $connection.ConnectAsync('127.0.0.1', $Port)
            $connected = $task.Wait(2000)
            if (-not $connected) { return $false }
            return $connection.Connected
        }
        finally { $connection.Close(); $connection.Dispose() }
    } catch { return $false }
}

# Runs an external command with a timeout (PowerShell equivalent of Bash run_with_timeout)
# Returns: hashtable with TimedOut, ExitCode, Output (stdout lines), ErrorOutput (stderr lines)
function Invoke-WithTimeout {
    param(
        [int]$TimeoutSeconds,
        [string]$Command,
        [string[]]$Arguments
    )
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Command
        $psi.Arguments = ($Arguments | ForEach-Object {
            if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
        }) -join ' '
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $process = [System.Diagnostics.Process]::Start($psi)

        # Read stdout/stderr asynchronously to prevent deadlocks on large output
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $process.Kill() } catch {}
            return @{ TimedOut = $true; ExitCode = 124; Output = $null; ErrorOutput = $null }
        }

        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $outputLines = if ($stdout) { $stdout -split "`r?`n" | Where-Object { $_ -ne '' } } else { @() }
        $errorLines = if ($stderr) { $stderr -split "`r?`n" | Where-Object { $_ -ne '' } } else { @() }

        return @{
            TimedOut    = $false
            ExitCode    = $process.ExitCode
            Output      = $outputLines
            ErrorOutput = $errorLines
        }
    } catch {
        return @{ TimedOut = $false; ExitCode = 1; Output = $null; ErrorOutput = "$_" }
    } finally {
        if ($null -ne $process) { try { $process.Dispose() } catch {} }
    }
}

# Downloads a model with heartbeat and stall detection (PowerShell equivalent of Bash _pull_with_heartbeat)
# Returns: hashtable with Success, TimedOut, Stalled
function Invoke-PullWithHeartbeat {
    param(
        [string]$ModelName,
        [int]$HardTimeoutSeconds,
        [int]$StallTimeoutSeconds = 300,
        [int]$HeartbeatIntervalSeconds = 30
    )
    $pullLog = Join-Path $env:TEMP "hablara-pull-$([System.IO.Path]::GetRandomFileName()).tmp"

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'ollama'
        $psi.Arguments = "pull $ModelName"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $process = [System.Diagnostics.Process]::Start($psi)

        # Drain stdout asynchronously to prevent buffer deadlock
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()

        # Use event-based stderr reading for reliable stall detection.
        # ReadToEndAsync() only completes when the stream closes (process exits),
        # making IsCompleted unsuitable for mid-download stall checks.
        $startTime = Get-Date
        $progress = [hashtable]::Synchronized(@{ LastTime = $startTime })
        $process.ErrorDataReceived += { param($s, $e); if ($null -ne $e.Data) { $progress.LastTime = Get-Date } }
        $process.BeginErrorReadLine()

        $lastHeartbeat = $startTime
        $firstHeartbeat = $true

        while (-not $process.HasExited) {
            Start-Sleep -Seconds 5
            $elapsed = ((Get-Date) - $startTime).TotalSeconds

            # Hard timeout
            if ($elapsed -ge $HardTimeoutSeconds) {
                Write-Warning ($script:Msg.DownloadHardTimeout -f [math]::Floor($HardTimeoutSeconds / 60))
                try { $process.Kill() } catch {}
                return @{ Success = $false; TimedOut = $true; Stalled = $false }
            }

            # Stall detection: no stderr output for StallTimeoutSeconds
            $stallSeconds = ((Get-Date) - $progress.LastTime).TotalSeconds
            if ($stallSeconds -ge $StallTimeoutSeconds) {
                Write-Warning ($script:Msg.DownloadStall -f [math]::Floor($StallTimeoutSeconds / 60))
                try { $process.Kill() } catch {}
                return @{ Success = $false; TimedOut = $false; Stalled = $true }
            }

            # Heartbeat: first after 1s, then every 30 seconds
            $sinceHeartbeat = ((Get-Date) - $lastHeartbeat).TotalSeconds
            $isFirstFire = $firstHeartbeat -and ($elapsed -ge 1)
            $isIntervalFire = (-not $firstHeartbeat) -and ($sinceHeartbeat -ge $HeartbeatIntervalSeconds)
            if ($isFirstFire -or $isIntervalFire) {
                $firstHeartbeat = $false
                $lastHeartbeat = Get-Date
                $elapsedMin = [math]::Floor($elapsed / 60)
                $elapsedSec = [math]::Floor($elapsed % 60)
                Write-Info ($script:Msg.DownloadRunning -f $elapsedMin, $elapsedSec)
            }
        }

        $exitCode = $process.ExitCode
        return @{ Success = ($exitCode -eq 0); TimedOut = $false; Stalled = $false }
    } catch {
        return @{ Success = $false; TimedOut = $false; Stalled = $false }
    } finally {
        if ($null -ne $process) { try { $process.CancelErrorRead(); $process.Dispose() } catch {} }
        Remove-Item -LiteralPath $pullLog -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# Status Check
# ============================================================================

function Invoke-StatusCheck {
    $errors = 0

    Write-Host ""
    Write-Host $script:Msg.StatusTitle -ForegroundColor Cyan
    Write-Host ""

    # 1. Ollama installed?
    if (Test-CommandExists 'ollama') {
        $currentVersion = Get-OllamaVersionString
        Write-StatusOk ($script:Msg.StatusInstalled -f $currentVersion)
        if ($currentVersion -ne $script:Msg.DiagnoseUnknown -and (Compare-SemanticVersion $currentVersion $MinOllamaVersion) -lt 0) {
            Write-Host "    " -NoNewline; Write-Host ($script:Msg.StatusUpdateRec -f [char]0x21B3, $MinOllamaVersion) -ForegroundColor Yellow
        }
    } else {
        Write-StatusFail $script:Msg.StatusNotFound
        $errors++
    }

    # 2. Server reachable?
    $serverReachable = $false
    try {
        $null = Invoke-RestMethod -Uri "$OllamaApiUrl/api/version" -TimeoutSec 5 -ErrorAction Stop
        $serverReachable = $true
        Write-StatusOk $script:Msg.StatusServerOk
    } catch {
        Write-StatusFail $script:Msg.StatusServerFail
        $errors++
    }

    # 3. GPU detected?
    $gpu = Test-GpuAvailable
    if ($gpu.Available) {
        $gpuLabel = switch ($gpu.Type) {
            'NVIDIA'   { $script:Msg.StatusGpuNvidia }
            'AMD ROCm' { $script:Msg.StatusGpuAmd }
            default     { $gpu.Type }
        }
        Write-StatusOk "GPU: $gpuLabel"
    } else {
        Write-StatusNote $script:Msg.StatusNoGpu
    }

    # 4. Base models present? (scan all variants, largest first)
    $baseModelsFound = @()
    foreach ($variant in @('qwen3-8b', '7b', '3b', '1.5b')) {
        if (-not $ModelConfigs.ContainsKey($variant)) { continue }
        $modelName = $ModelConfigs[$variant].Name
        if (Test-OllamaModelExists $modelName) { $baseModelsFound += $modelName }
    }

    if ($baseModelsFound.Count -eq 1) {
        Write-StatusOk ($script:Msg.StatusBaseModel -f $baseModelsFound[0])
    } elseif ($baseModelsFound.Count -gt 1) {
        Write-StatusOk $script:Msg.StatusBaseModels
        foreach ($m in $baseModelsFound) {
            Write-Host "    " -NoNewline; Write-Host "$([char]0x2713) $m" -ForegroundColor Green
        }
    } else {
        Write-StatusFail $script:Msg.StatusNoBase
        $errors++
    }

    # 5. Custom models present? (scan all variants, largest first)
    $customModelsFound = @()
    foreach ($variant in @('qwen3-8b', '7b', '3b', '1.5b')) {
        if (-not $ModelConfigs.ContainsKey($variant)) { continue }
        $modelName = "$($ModelConfigs[$variant].Name)-custom"
        if (Test-OllamaModelExists $modelName) { $customModelsFound += $modelName }
    }

    if ($customModelsFound.Count -eq 1) {
        Write-StatusOk ($script:Msg.StatusHablaraModel -f $customModelsFound[0])
        if ($baseModelsFound.Count -eq 0) {
            Write-Host "    " -NoNewline; Write-Host ($script:Msg.StatusBaseMissing -f [char]0x21B3) -ForegroundColor Yellow
        }
    } elseif ($customModelsFound.Count -gt 1) {
        Write-StatusOk $script:Msg.StatusHablaraModels
        foreach ($m in $customModelsFound) {
            Write-Host "    " -NoNewline; Write-Host "$([char]0x2713) $m" -ForegroundColor Green
        }
        if ($baseModelsFound.Count -eq 0) {
            Write-Host "    " -NoNewline; Write-Host ($script:Msg.StatusBaseMissing -f [char]0x21B3) -ForegroundColor Yellow
        }
    } else {
        Write-StatusFail $script:Msg.StatusNoHablara
        $errors++
    }

    # 6. Model inference works? (use smallest model for fastest check)
    # Explicit priority: 3b > 7b > qwen3-8b (smallest = fastest)
    $modelPriority = @('1.5b', '3b', '7b', 'qwen3-8b')
    $testModel = $null
    foreach ($prio in $modelPriority) {
        if (-not $ModelConfigs.ContainsKey($prio)) { continue }
        $candidate = "$($ModelConfigs[$prio].Name)-custom"
        if ($customModelsFound -contains $candidate) { $testModel = $candidate; break }
    }
    if (-not $testModel) {
        foreach ($prio in $modelPriority) {
            if (-not $ModelConfigs.ContainsKey($prio)) { continue }
            $candidate = $ModelConfigs[$prio].Name
            if ($baseModelsFound -contains $candidate) { $testModel = $candidate; break }
        }
    }
    if (-not $serverReachable) {
        Write-StatusNote $script:Msg.StatusInfSkip
    } elseif ($testModel) {
        if (Test-ModelResponds -Model $testModel -TimeoutSec 15) {
            Write-StatusOk $script:Msg.StatusModelOk
        } else {
            Write-StatusFail $script:Msg.StatusModelFail
            $errors++
        }
    } else {
        Write-StatusFail $script:Msg.StatusModelFail
        $errors++
    }

    # 7. Storage usage (only Hablará-relevant qwen2.5 models, parsed from ollama list)
    $allModels = @($baseModelsFound) + @($customModelsFound)
    if ($allModels.Count -gt 0 -and (Test-CommandExists 'ollama')) {
        try {
            $listResult = Invoke-WithTimeout -TimeoutSeconds 15 -Command 'ollama' -Arguments @('list')
            $ollamaList = if (-not $listResult.TimedOut -and $listResult.Output) { $listResult.Output } else { @() }
            $totalGB = 0.0
            foreach ($m in $allModels) {
                $line = $ollamaList | Where-Object { $_ -match "^$([regex]::Escape($m))\s" } | Select-Object -First 1
                if ($line -and $line -match '(\d+\.?\d*)\s*(KB|MB|GB|TB)') {
                    $val = [double]::Parse($Matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
                    switch ($Matches[2]) {
                        'TB' { $totalGB += $val * 1024 }
                        'GB' { $totalGB += $val }
                        'MB' { $totalGB += $val / 1024 }
                        'KB' { $totalGB += $val / 1048576 }
                    }
                }
            }
            $totalGB = [math]::Round($totalGB, 1)
            Write-StatusNote ($script:Msg.StatusStorage -f $totalGB)
        } catch {
            Write-StatusNote $script:Msg.StatusStorageUnk
        }
    } else {
        Write-StatusNote $script:Msg.StatusStorageUnk
    }

    Write-Host ""
    if ($errors -eq 0) {
        Write-Host $script:Msg.StatusAllOk -ForegroundColor Green
    } else {
        Write-Host ($script:Msg.StatusProblems -f $errors) -ForegroundColor Red
        Write-Host $script:Msg.StatusRepair
    }
    Write-Host ""

    return [math]::Min($errors, 1)
}

# ============================================================================
# Diagnose Report
# ============================================================================

function Invoke-DiagnoseReport {
    # --- System ---
    $osInfo = [System.Environment]::OSVersion
    $osVersion = "Windows $($osInfo.Version.Major).$($osInfo.Version.Minor)"
    try {
        $wmiOs = Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption -ErrorAction Stop
        $osVersion = $wmiOs.Caption -replace 'Microsoft\s+', ''
    } catch {}
    $arch = $env:PROCESSOR_ARCHITECTURE

    $ramTotalGB = $script:Msg.DiagnoseUnknown
    $ramFreeGB = $script:Msg.DiagnoseUnknown
    try {
        $compSys = Get-CimInstance -ClassName Win32_ComputerSystem -Property TotalPhysicalMemory -ErrorAction Stop
        $ramTotalGB = [math]::Floor($compSys.TotalPhysicalMemory / 1GB)
    } catch {}
    try {
        # FreePhysicalMemory is in KB (not bytes!) — dividing KB by 1MB (1048576) gives GB
        $osObj = Get-CimInstance -ClassName Win32_OperatingSystem -Property FreePhysicalMemory -ErrorAction Stop
        $ramFreeGB = [math]::Floor($osObj.FreePhysicalMemory / 1MB)
    } catch {}

    $freeDiskGB = $script:Msg.DiagnoseUnknown
    try {
        $freeDiskGB = Get-FreeDiskSpaceGB
        if ($freeDiskGB -eq 0) { $freeDiskGB = $script:Msg.DiagnoseUnknown }
    } catch {}

    $shellVersion = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"

    # --- Ollama ---
    $ollamaVersion = $script:Msg.DiagnoseNotInst
    $serverStatus = $script:Msg.DiagnoseNotReach
    $gpuLabel = $script:Msg.DiagnoseUnknown

    if (Test-CommandExists 'ollama') {
        $ollamaVersion = Get-OllamaVersionString
    }

    try {
        $null = Invoke-RestMethod -Uri "$OllamaApiUrl/api/version" -TimeoutSec 5 -ErrorAction Stop
        $serverStatus = $script:Msg.DiagnoseRunning
    } catch {}

    $gpu = Test-GpuAvailable
    if ($gpu.Available) {
        $gpuLabel = switch ($gpu.Type) {
            'NVIDIA'   { 'NVIDIA (CUDA)' }
            'AMD ROCm' { 'AMD (ROCm)' }
            default     { $gpu.Type }
        }
    } else {
        $gpuLabel = $script:Msg.DiagnoseGpuNone
    }

    # --- Models ---
    $modelsOutput = ''
    $totalStorageGB = 0.0
    $ollamaAvailable = (Test-CommandExists 'ollama')
    $ollamaList = $null
    if ($ollamaAvailable) {
        $listResult = Invoke-WithTimeout -TimeoutSeconds 15 -Command 'ollama' -Arguments @('list')
        if (-not $listResult.TimedOut -and $listResult.Output) { $ollamaList = $listResult.Output }
    }

    if ($ollamaAvailable -and $ollamaList) {
        foreach ($variant in @('qwen3-8b', '7b', '3b', '1.5b')) {
            if (-not $ModelConfigs.ContainsKey($variant)) { continue }
            $modelName = $ModelConfigs[$variant].Name
            $customName = "${modelName}-custom"

            # Check base model
            if (Test-OllamaModelExists $modelName) {
                $line = $ollamaList | Where-Object { $_ -match "^$([regex]::Escape($modelName))\s" } | Select-Object -First 1
                $sizeDisplay = $script:Msg.DiagnoseUnknown
                if ($line -and $line -match '(\d+\.?\d*)\s*(KB|MB|GB|TB)') {
                    $sizeDisplay = "$($Matches[1]) $($Matches[2])"
                    $val = [double]::Parse($Matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
                    switch ($Matches[2]) {
                        'GB' { $totalStorageGB += $val }
                        'MB' { $totalStorageGB += $val / 1024 }
                    }
                }
                $padding = ' ' * [math]::Max(1, 20 - $modelName.Length)
                $modelsOutput += "    ${modelName}${padding}${sizeDisplay}  $([char]0x2713)`n"
            }

            # Check custom model
            if (Test-OllamaModelExists $customName) {
                $line = $ollamaList | Where-Object { $_ -match "^$([regex]::Escape($customName))\s" } | Select-Object -First 1
                $sizeDisplay = $script:Msg.DiagnoseUnknown
                if ($line -and $line -match '(\d+\.?\d*)\s*(KB|MB|GB|TB)') {
                    $sizeDisplay = "$($Matches[1]) $($Matches[2])"
                    $val = [double]::Parse($Matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
                    switch ($Matches[2]) {
                        'GB' { $totalStorageGB += $val }
                        'MB' { $totalStorageGB += $val / 1024 }
                    }
                }
                $respondsLabel = ''
                if ($serverStatus -eq $script:Msg.DiagnoseRunning -and (Test-ModelResponds -Model $customName -TimeoutSec 15)) {
                    $respondsLabel = " $($script:Msg.DiagnoseResponds)"
                }
                $padding = ' ' * [math]::Max(1, 20 - $customName.Length)
                $modelsOutput += "    ${customName}${padding}${sizeDisplay}  $([char]0x2713)${respondsLabel}`n"
            }
        }
    }

    if ([string]::IsNullOrEmpty($modelsOutput)) {
        $modelsOutput = "$($script:Msg.DiagnoseNoModels)`n"
    }

    $totalStorageGB = [math]::Round($totalStorageGB, 1)

    # --- Ollama Log ---
    $logOutput = ''
    $logFile = Join-Path $env:USERPROFILE '.ollama\logs\server.log'
    if (Test-Path $logFile) {
        try {
            $logLines = Get-Content -Path $logFile -Tail 200 -ErrorAction Stop
            $errorLines = $logLines | Where-Object { $_ -match 'ERROR|WARN|fatal' } | Select-Object -Last 10
            if ($errorLines) {
                $logOutput = ($errorLines -join "`n")
            } else {
                $logOutput = $script:Msg.DiagnoseNoErrors
            }
        } catch {
            $logOutput = $script:Msg.DiagnoseLogUnread -f $logFile
        }
    } else {
        $logOutput = $script:Msg.DiagnoseNoLog -f $logFile
    }

    # --- Output (plain text, no colors) ---
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    $diagTitle    = $script:Msg.DiagnoseTitle
    $diagSystem   = $script:Msg.DiagnoseSystem
    $diagOllama   = $script:Msg.DiagnoseOllama
    $diagModels   = $script:Msg.DiagnoseModels
    $diagStorage  = $script:Msg.DiagnoseStorage
    $diagLog      = $script:Msg.DiagnoseLog
    $diagCreated  = $script:Msg.DiagnoseCreated
    $diagScript   = $script:Msg.DiagnoseScript
    $diagAvail    = $script:Msg.DiagnoseRamAvail
    $diagFree     = $script:Msg.DiagnoseStorFree
    $diagStorDisk = $script:Msg.DiagnoseStorDisk

    $reportContent = @"

${diagTitle}

${diagSystem}
  OS:           ${osVersion} (${arch})
  RAM:          ${ramTotalGB} GB (${ramFreeGB} GB ${diagAvail})
  ${diagStorDisk} ${freeDiskGB} GB ${diagFree}
  Shell:        PowerShell ${shellVersion}

${diagOllama}
  Version:      ${ollamaVersion}
  Server:       ${serverStatus}
  API-URL:      ${OllamaApiUrl}
  GPU:          ${gpuLabel}

${diagModels}
${modelsOutput}
${diagStorage}  ~${totalStorageGB} GB

${diagLog}
${logOutput}

---
${diagCreated} ${timestamp}
${diagScript}   setup-ollama-win.ps1 v${ScriptVersion}

"@
    Write-Host $reportContent

    # Save to Desktop
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    if ($desktopPath -and (Test-Path $desktopPath -PathType Container)) {
        $fileName = "hablara-diagnose-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
        $reportFile = Join-Path $desktopPath $fileName
        try {
            [System.IO.File]::WriteAllText($reportFile, $reportContent, [System.Text.UTF8Encoding]::new($false))
            Write-Success ($script:Msg.DiagnoseSaved -f $reportFile)
        } catch {
            Write-Warning $script:Msg.DiagnoseSaveFailed
        }
    }
}

# ============================================================================
# Cleanup
# ============================================================================

function Invoke-Cleanup {
    if (-not (Test-InteractiveSession)) {
        Write-Err $script:Msg.CleanupNeedsTTY
        exit 1
    }

    if (-not (Test-CommandExists 'ollama')) {
        Write-Err $script:Msg.CleanupNoOllama
        exit 1
    }

    $listCheck = Invoke-WithTimeout -TimeoutSeconds 15 -Command 'ollama' -Arguments @('list')
    if ($listCheck.TimedOut -or $listCheck.ExitCode -ne 0) {
        Write-Err $script:Msg.CleanupNoServer
        Write-Info $script:Msg.CleanupStartHint
        exit 1
    }

    # Discover installed Hablará variants
    $variants = @()
    foreach ($variant in @('1.5b', '3b', '7b', 'qwen3-8b')) {
        if (-not $ModelConfigs.ContainsKey($variant)) { continue }
        $modelName = $ModelConfigs[$variant].Name
        $customName = "${modelName}-custom"
        $hasBase = Test-OllamaModelExists $modelName
        $hasCustom = Test-OllamaModelExists $customName

        if ($hasBase -and $hasCustom) {
            $variants += @{ Variant = $variant; Base = $modelName; Custom = $customName; Label = "${variant}  (${modelName} + ${customName})" }
        } elseif ($hasBase) {
            $variants += @{ Variant = $variant; Base = $modelName; Custom = $null; Label = "${variant}  (${modelName})" }
        } elseif ($hasCustom) {
            $variants += @{ Variant = $variant; Base = $null; Custom = $customName; Label = "${variant}  (${customName})" }
        }
    }

    if ($variants.Count -eq 0) {
        Write-Host ""
        Write-Info $script:Msg.CleanupNoModels
        Write-Host ""
        return
    }

    Write-Host ""
    Write-Host $script:Msg.CleanupInstalled -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $variants.Count; $i++) {
        Write-Host "  $($i + 1)) $($variants[$i].Label)"
    }
    Write-Host ""
    $choice = Read-Host $script:Msg.CleanupPrompt

    # Empty = abort
    if ([string]::IsNullOrEmpty($choice)) {
        return
    }

    # Validate choice
    $choiceNum = 0
    if (-not [int]::TryParse($choice, [ref]$choiceNum) -or $choiceNum -lt 1 -or $choiceNum -gt $variants.Count) {
        Write-Err $script:Msg.CleanupInvalid
        return 1
    }

    $selected = $variants[$choiceNum - 1]

    Write-Host ""

    # Delete custom first (depends on base)
    if ($selected.Custom) {
        $rmResult = Invoke-WithTimeout -TimeoutSeconds 30 -Command 'ollama' -Arguments @('rm', $selected.Custom)
        if ($rmResult.TimedOut) {
            Write-Warning ($script:Msg.CleanupTimeout -f $selected.Custom)
        } elseif ($rmResult.ExitCode -eq 0) {
            Write-Success ($script:Msg.CleanupDeleted -f $selected.Custom)
        } else {
            $reason = if ($rmResult.ErrorOutput) { $rmResult.ErrorOutput -join ' ' } else { $script:Msg.CleanupUnknownErr }
            Write-Warning ($script:Msg.CleanupFailed -f $selected.Custom, $reason)
        }
    }

    if ($selected.Base) {
        $rmResult = Invoke-WithTimeout -TimeoutSeconds 30 -Command 'ollama' -Arguments @('rm', $selected.Base)
        if ($rmResult.TimedOut) {
            Write-Warning ($script:Msg.CleanupTimeout -f $selected.Base)
        } elseif ($rmResult.ExitCode -eq 0) {
            Write-Success ($script:Msg.CleanupDeleted -f $selected.Base)
        } else {
            $reason = if ($rmResult.ErrorOutput) { $rmResult.ErrorOutput -join ' ' } else { $script:Msg.CleanupUnknownErr }
            Write-Warning ($script:Msg.CleanupFailed -f $selected.Base, $reason)
        }
    }

    # Check if any Hablará models remain
    $remaining = $false
    foreach ($variant in @('1.5b', '3b', '7b', 'qwen3-8b')) {
        if (-not $ModelConfigs.ContainsKey($variant)) { continue }
        $modelName = $ModelConfigs[$variant].Name
        if ((Test-OllamaModelExists $modelName) -or (Test-OllamaModelExists "${modelName}-custom")) {
            $remaining = $true
            break
        }
    }

    if (-not $remaining) {
        Write-Host ""
        Write-Warning $script:Msg.CleanupNoneLeft
    }

    Write-Host ""
    return 0
}

# ============================================================================
# Model Selection
# ============================================================================

function Show-HelpMessage {
    Write-Host ""
    Write-Host ($script:Msg.HelpTitle -f $ScriptVersion) -ForegroundColor Cyan
    Write-Host ""
    Write-Host $script:Msg.HelpDescription
    Write-Host ""
    Write-Host $script:Msg.HelpUsage -ForegroundColor Green
    Write-Host $script:Msg.HelpUsageLine
    Write-Host ""
    Write-Host $script:Msg.HelpOptions -ForegroundColor Green
    Write-Host $script:Msg.HelpOptModel
    Write-Host $script:Msg.HelpOptUpdate
    Write-Host $script:Msg.HelpOptStatus
    Write-Host $script:Msg.HelpOptDiagnose
    Write-Host $script:Msg.HelpOptCleanup
    Write-Host $script:Msg.HelpOptLang
    Write-Host $script:Msg.HelpOptHelp
    Write-Host ""
    Write-Host $script:Msg.HelpNoOpts
    Write-Host ""
    Write-Host $script:Msg.HelpVariants -ForegroundColor Green
    Write-Host "  qwen2.5-1.5b  ~1 GB     $($script:Msg.Model1_5B)"
    Write-Host "  qwen2.5-3b    ~2 GB     $($script:Msg.Model3B)"
    Write-Host "  qwen2.5-7b    ~4.7 GB   $($script:Msg.Model7B)"
    Write-Host "  qwen3-8b      ~5.2 GB   $($script:Msg.ModelQwen3)"
    Write-Host ""
    Write-Host $script:Msg.HelpExamples -ForegroundColor Green
    Write-Host $script:Msg.HelpExModel
    Write-Host $script:Msg.HelpExUpdate
    Write-Host $script:Msg.HelpExStatus
    Write-Host $script:Msg.HelpExDiagnose
    Write-Host $script:Msg.HelpExCleanup
    Write-Host ""
    Write-Host $script:Msg.HelpExitCodes -ForegroundColor Green
    Write-Host $script:Msg.HelpExit0
    Write-Host $script:Msg.HelpExit1
    Write-Host $script:Msg.HelpExit2
    Write-Host $script:Msg.HelpExit3
    Write-Host $script:Msg.HelpExit4
    Write-Host ""
}

function Show-ModelMenu {
    $rec = if ($script:RecommendedModel) { $script:RecommendedModel } else { $DefaultModel }
    $s1 = ''; $s2 = ''; $s3 = ''; $s4 = ''
    switch ($rec) {
        '1.5b'     { $s1 = ' ★' }
        '3b'       { $s2 = ' ★' }
        '7b'       { $s3 = ' ★' }
        'qwen3-8b' { $s4 = ' ★' }
    }

    # Map recommended model to menu number for dynamic default
    $defaultNum = switch ($rec) {
        '1.5b'     { '1' }
        '3b'       { '2' }
        '7b'       { '3' }
        'qwen3-8b' { '4' }
        default     { '2' }
    }

    Write-Host ""
    Write-Host $script:Msg.ChooseModel -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) qwen2.5-1.5b - $($script:Msg.Model1_5B)$s1"
    Write-Host "  2) qwen2.5-3b   - $($script:Msg.Model3B)$s2"
    Write-Host "  3) qwen2.5-7b   - $($script:Msg.Model7B)$s3"
    Write-Host "  4) qwen3-8b     - $($script:Msg.ModelQwen3)$s4"
    Write-Host ""

    $prompt = if ($script:RecommendedModel) {
        $script:Msg.ChoicePromptHw -f $defaultNum
    } else {
        $script:Msg.ChoicePrompt
    }
    $choice = Read-Host $prompt

    switch ($choice) {
        '1' { return '1.5b' }
        '2' { return '3b' }
        '3' { return '7b' }
        '4' { return 'qwen3-8b' }
        default { return $rec }
    }
}

function Show-MainMenu {
    Write-Host ""
    Write-Host $script:Msg.ChooseAction -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) $($script:Msg.ActionSetup)"
    Write-Host "  2) $($script:Msg.ActionStatus)"
    Write-Host "  3) $($script:Msg.ActionDiagnose)"
    Write-Host "  4) $($script:Msg.ActionCleanup)"
    Write-Host ""
    $choice = Read-Host $script:Msg.ActionPrompt

    switch ($choice) {
        '2' { return 'status' }
        '3' { return 'diagnose' }
        '4' { return 'cleanup' }
        default { return 'setup' }
    }
}

function Select-ModelConfig {
    param([string]$RequestedModel)

    if ($Help) { Show-HelpMessage; exit 0 }
    if ($Status) { $exitCode = Invoke-StatusCheck; exit $exitCode }
    if ($Diagnose) { Invoke-DiagnoseReport; exit 0 }
    if ($Cleanup) { $exitCode = Invoke-Cleanup; exit ($exitCode -as [int]) }

    $hasExplicitFlags = $Update -or (-not [string]::IsNullOrEmpty($RequestedModel))

    # Interactive main menu (only when no explicit flags and interactive session)
    if (-not $hasExplicitFlags -and (Test-InteractiveSession)) {
        $action = Show-MainMenu
        if ($action -eq 'status') {
            $exitCode = Invoke-StatusCheck
            exit $exitCode
        } elseif ($action -eq 'diagnose') {
            Invoke-DiagnoseReport
            exit 0
        } elseif ($action -eq 'cleanup') {
            $exitCode = Invoke-Cleanup
            exit ($exitCode -as [int])
        }
    }

    # Hardware-aware recommendation (before model menu)
    $detectedBw = Get-MemoryBandwidthGbps
    if ($detectedBw -gt 0 -and [string]::IsNullOrEmpty($RequestedModel) -and (Test-InteractiveSession)) {
        Show-HardwareRecommendation -Bandwidth $detectedBw
    } elseif ($detectedBw -eq 0 -and [string]::IsNullOrEmpty($RequestedModel) -and (Test-InteractiveSession)) {
        Write-Info $script:Msg.HwUnknownChip
    }

    $selectedModel = $RequestedModel
    if ([string]::IsNullOrEmpty($selectedModel)) {
        $selectedModel = if (Test-InteractiveSession) { Show-ModelMenu } else { $DefaultModel }
    }

    if (-not $ModelConfigs.ContainsKey($selectedModel)) {
        Write-Err ($script:Msg.InvalidModel -f $selectedModel)
        Write-Host $script:Msg.ValidVariants
        exit 1
    }

    $config = $ModelConfigs[$selectedModel]
    $script:ModelName = $config.Name
    $script:CustomModelName = "$($config.Name)-custom"
    $script:ModelSize = $config.Size
    $script:RequiredDiskSpaceGB = $config.DiskGB

    # RAM warning for large models
    if ($config.RAMWarn) {
        $systemRAM = Get-SystemRAMGB
        if ($systemRAM -gt 0 -and $systemRAM -lt $config.MinRAM) {
            Write-Host ""
            Write-Warning ($script:Msg.RamWarnModel -f $config.MinRAM)
            Write-Warning ($script:Msg.RamWarnSys -f $systemRAM)
            Write-Host ""

            if (Test-InteractiveSession) {
                $confirm = Read-Host "$($script:Msg.ContinueAnyway) $($script:Msg.ConfirmPrompt)"
                if ($confirm -notmatch $script:Msg.ConfirmPattern) { Write-Info $script:Msg.Aborted; exit 0 }
            } else {
                Write-Warning $script:Msg.ProceedNonInteract
            }
        }
    }

    if ([string]::IsNullOrEmpty($script:ModelName)) { Write-Err $script:Msg.InternalError; exit 1 }
    Write-Info ($script:Msg.SelectedModel -f $script:ModelName)
    return $config
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

function Test-Prerequisites {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ($script:Msg.HelpTitle -f $ScriptVersion) -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    Write-Step $script:Msg.Preflight

    if ([Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        Write-Err $script:Msg.PlatformError
        Write-Info $script:Msg.PlatformMacHint
        Write-Info $script:Msg.PlatformLinuxHint
        exit 4
    }

    $freeSpace = Get-FreeDiskSpaceGB
    if ($freeSpace -lt $script:RequiredDiskSpaceGB) {
        Write-Err ($script:Msg.DiskInsufficient -f $freeSpace, $script:RequiredDiskSpaceGB)
        exit 2
    }
    Write-Success ($script:Msg.DiskOk -f $freeSpace)

    try {
        $null = Invoke-WebRequest -Uri 'https://ollama.com' -TimeoutSec 10 -UseBasicParsing
        Write-Success $script:Msg.NetworkOk
    } catch {
        # Fallback: TCP connectivity check (more reliable in restricted environments)
        $tcpOk = $false
        try {
            $tcpOk = Test-NetConnection -ComputerName 'ollama.com' -Port 443 `
                -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        } catch { }
        if ($tcpOk) {
            Write-Success $script:Msg.NetworkOk
        } else {
            Write-Err $script:Msg.NetworkError
            Write-Info $script:Msg.NetworkHint
            exit 3
        }
    }

    $gpu = Test-GpuAvailable
    if ($gpu.Available) { Write-Success ($script:Msg.GpuDetected -f $gpu.Type) }
    else { Write-Warning $script:Msg.GpuNone }

    Write-Host ""
}

# ============================================================================
# Ollama Installation
# ============================================================================

function Start-OllamaServer {
    try {
        $response = Invoke-RestMethod -Uri "$OllamaApiUrl/api/version" -TimeoutSec 5 -ErrorAction Stop
        Write-Success $script:Msg.ServerAlready
        return $true
    } catch {}

    # Port might be in use by starting server - delegate to Wait-OllamaServer (60s)
    if (Test-PortInUse -Port 11434) {
        Write-Info $script:Msg.PortBusy
        if (Wait-OllamaServer -TimeoutSeconds 60) { return $true }
        Write-Warning $script:Msg.PortBusyWarn
        return $false
    }

    # Try Ollama Desktop App. Pfade analog Find-OllamaInstallation —
    # winget installiert seit Ende 2024 standardmäßig nach %LOCALAPPDATA%\Programs\Ollama\.
    $ollamaAppPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama app.exe'),
        (Join-Path $env:LOCALAPPDATA 'Ollama\ollama app.exe'),
        (Join-Path $env:ProgramFiles 'Ollama\ollama app.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Ollama\ollama app.exe')
    )
    $ollamaApp = $ollamaAppPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($ollamaApp) {
        Write-Info $script:Msg.OllamaAppStart
        Start-Process -FilePath $ollamaApp -WindowStyle Hidden
        # Desktop-App braucht länger als `ollama serve` bis API auf 11434 antwortet.
        if (Wait-OllamaServer -TimeoutSeconds 60) { return $true }
    }

    # Fallback: ollama serve. Vorher final prüfen, ob Desktop-App in Zwischenzeit
    # Port belegt hat — dann nicht parallel starten (verhindert "address in use" Race).
    if (Test-PortInUse -Port 11434) {
        Write-Info $script:Msg.PortBusy
        if (Wait-OllamaServer -TimeoutSeconds 30) { return $true }
        Write-Warning $script:Msg.PortBusyWarn
        return $false
    }

    if (Test-CommandExists 'ollama') {
        Write-Info $script:Msg.OllamaServeStart
        $process = Start-Process -FilePath 'ollama' -ArgumentList 'serve' -WindowStyle Hidden -PassThru
        $serverReady = Wait-OllamaServer -TimeoutSeconds 30

        if ($serverReady -and -not $process.HasExited) { return $true }
        if ($process.HasExited) { Write-Err ($script:Msg.OllamaProcessExit -f $process.ExitCode); return $false }
        # Server not ready but process still running — kill orphaned process
        try { $process.Kill() } catch {}
        return $false
    }
    return $false
}

# Detects Ollama in non-standard locations and extends PATH if found
function Find-OllamaInstallation {
    if (Test-CommandExists 'ollama') { return $true }

    # Check common Windows installation paths
    $searchPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'),
        (Join-Path $env:ProgramFiles 'Ollama\ollama.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Ollama\ollama.exe'),
        (Join-Path $env:LOCALAPPDATA 'Ollama\ollama.exe')
    )

    foreach ($p in $searchPaths) {
        if (Test-Path $p) {
            $dir = Split-Path $p -Parent
            Write-Info ($script:Msg.OllamaFound -f $p)
            $env:Path += ";$dir"
            return $true
        }
    }

    return $false
}

function Install-Ollama {
    Write-Step $script:Msg.Installing

    # Try to detect Ollama even if not in standard PATH
    Find-OllamaInstallation | Out-Null

    if (Test-CommandExists 'ollama') {
        Write-Success $script:Msg.OllamaAlready
        $version = & ollama --version 2>&1 | Select-Object -First 1
        Write-Info ($script:Msg.OllamaVersion -f $version)
        Test-OllamaVersion | Out-Null

        if (-not (Start-OllamaServer)) {
            Write-Err $script:Msg.ServerStartFailed
            Write-Info $script:Msg.ServerStartHint
            exit 1
        }
        return
    }

    if (Test-CommandExists 'winget') {
        Write-Info $script:Msg.UsingWinget
        try {
            $wingetResult = Invoke-WithTimeout -TimeoutSeconds 600 -Command 'winget' `
                -Arguments @('install', 'Ollama.Ollama', '--silent', '--accept-source-agreements', '--accept-package-agreements')
            if ($wingetResult.TimedOut) {
                Write-Warning $script:Msg.WingetTimeout
                throw "timeout"
            }
            $wingetExit = $wingetResult.ExitCode
            if ($wingetExit -eq 0 -or $wingetExit -eq 3010) {
                Write-Success $script:Msg.OllamaInstalled
                if ($wingetExit -eq 3010) { Write-Warning $script:Msg.RebootRequired }

                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

                if (-not (Test-CommandExists 'ollama')) {
                    @("$env:LOCALAPPDATA\Programs\Ollama", "$env:ProgramFiles\Ollama") | ForEach-Object {
                        if (Test-Path (Join-Path $_ 'ollama.exe')) { $env:Path += ";$_" }
                    }
                }

                # Verify ollama CLI is now accessible
                if (-not (Test-CommandExists 'ollama')) {
                    Write-Err $script:Msg.OllamaPathError
                    exit 1
                }

                # Ollama-Installer startet die Desktop-App automatisch nach Install.
                # Kurz warten + Quick-Probe, damit Start-OllamaServer den laufenden
                # Server erkennt statt parallel `ollama serve` zu starten (Port-Race).
                Write-Info $script:Msg.WaitForAutoStart
                Start-Sleep -Seconds 5

                if (-not (Start-OllamaServer)) {
                    Write-Err $script:Msg.ServerStartFailed
                    Write-Info $script:Msg.ServerStartHint
                    exit 1
                }
                return
            }
        } catch { Write-Warning ($script:Msg.WingetFailed -f $_) }
    }

    Write-Warning $script:Msg.AutoInstallFailed
    Write-Host ""
    Write-Host $script:Msg.ManualInstall -ForegroundColor Cyan
    Write-Host $script:Msg.ManualRerun
    Write-Host ""
    exit 1
}

# ============================================================================
# Model Management
# ============================================================================

function Install-BaseModel {
    Write-Step $script:Msg.DownloadingBase

    if (Test-OllamaModelExists $script:ModelName) {
        Write-Success ($script:Msg.ModelExists -f $script:ModelName)
        return
    }

    Write-Info ($script:Msg.DownloadingModel -f $script:ModelName, $script:ModelSize)
    Write-Info $script:Msg.DownloadResumeTip

    # Hard timeout per attempt: 20 min for all models
    $pullTimeout = 1200

    $pullSuccess = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $pullResult = Invoke-PullWithHeartbeat -ModelName $script:ModelName -HardTimeoutSeconds $pullTimeout
        if ($pullResult.Success) { $pullSuccess = $true; break }

        if ($pullResult.TimedOut) {
            Write-Warning ($script:Msg.DownloadTimeoutW -f [math]::Floor($pullTimeout / 60), $attempt)
        } else {
            Write-Warning ($script:Msg.DownloadFailedW -f $attempt)
        }
        if ($attempt -lt 3) {
            Write-Info $script:Msg.DownloadRetry
            Start-Sleep -Seconds 5
        }
    }

    if (-not $pullSuccess) {
        Write-Err $script:Msg.DownloadFailed
        Write-Info ($script:Msg.DownloadManual -f $script:ModelName)
        exit 1
    }
    Write-Success ($script:Msg.DownloadDone -f $script:ModelName)
}

function New-CustomModel {
    Write-Step $script:Msg.CreatingCustom

    $actionVerb = $script:Msg.VerbCreated

    if (Test-OllamaModelExists $script:CustomModelName) {
        if ($Update) {
            Write-Info $script:Msg.UpdatingCustom
            $actionVerb = $script:Msg.VerbUpdated
        } elseif (Test-InteractiveSession) {
            # Interactive: show menu
            Write-Host ""
            Write-Info ($script:Msg.CustomExists -f $script:CustomModelName)
            Write-Host ""
            Write-Host "  1) $($script:Msg.CustomSkip)"
            Write-Host "  2) $($script:Msg.CustomUpdateOpt)"
            Write-Host ""
            $updateChoice = Read-Host $script:Msg.CustomUpdatePrompt
            if ($updateChoice -ne '2') {
                Write-Success $script:Msg.CustomKept
                return
            }
            Write-Info $script:Msg.UpdatingCustom
            $actionVerb = $script:Msg.VerbUpdated
        } else {
            # Non-interactive without -Update: skip
            Write-Success $script:Msg.CustomPresent
            return
        }
    }

    # Dynamic modelfile path based on selected model variant (e.g. qwen2.5:7b → qwen2.5-7b-custom.modelfile)
    $modelfileName = ($script:ModelName -replace ':', '-') + "-custom.modelfile"
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { "" }
    $externalModelfile = if ($scriptDir) { Join-Path $scriptDir "ollama\$modelfileName" } else { "" }

    $modelfileContent = ""
    if ($externalModelfile -and (Test-Path $externalModelfile)) {
        try {
            $modelfileContent = [System.IO.File]::ReadAllText($externalModelfile)
            Write-Info $script:Msg.UsingHablaraConf
        } catch {
            Write-Warning ($script:Msg.ConfigReadError -f $_)
            $externalModelfile = ""
        }
    }
    if (-not $modelfileContent) {
        # KEIN SYSTEM-Prompt: Ollama 0.18.0 Constrained-Decoding-Bug bei qwen3-Modellen —
        # SYSTEM + format:"json" korrumpiert JSON-Output (Token-Alignment-Verschiebung).
        # Alle Instruktionen kommen via Per-Request-Prompts.
        # Referenz: docs/reference/benchmarks/JSON_DE.md
        Write-Info $script:Msg.UsingDefaultConf
        $modelfileContent = "FROM $($script:ModelName)`n`n" + @'
PARAMETER num_ctx 8192
PARAMETER temperature 0.3
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
'@
    }

    $modelfilePath = Join-Path $env:TEMP "hablara-modelfile-$([System.IO.Path]::GetRandomFileName()).tmp"

    # Path traversal prevention (case-insensitive, trailing backslash prevents C:\Temp vs C:\Temp2)
    $canonicalPath = [System.IO.Path]::GetFullPath($modelfilePath)
    $canonicalTemp = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
    if (-not $canonicalPath.StartsWith($canonicalTemp, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Err $script:Msg.ConfigError
        return
    }

    # Write without BOM (Ollama can't parse BOM)
    [System.IO.File]::WriteAllText($modelfilePath, $modelfileContent, [System.Text.UTF8Encoding]::new($false))

    # Restrictive permissions to prevent race condition attacks
    try {
        $acl = Get-Acl $modelfilePath
        $acl.SetAccessRuleProtection($true, $false)
        $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) } | Out-Null
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, 'FullControl', 'Allow')
        $acl.AddAccessRule($rule)
        Set-Acl -Path $modelfilePath -AclObject $acl -ErrorAction Stop
    } catch { Write-Warning ($script:Msg.PermsWarn -f $_) }

    $isInteractive = Test-InteractiveSession
    $spinChars = @([char]0x280B,[char]0x2819,[char]0x2839,[char]0x2838,
                   [char]0x283C,[char]0x2834,[char]0x2826,[char]0x2827,
                   [char]0x2807,[char]0x280F)
    $spinIdx = 0
    $createMsg = $script:Msg.CustomCreating -f $script:CustomModelName

    try {
        $createJob = Start-Job -ScriptBlock {
            param($cmd, $cmdArgs, $timeout, $envPath)
            # Restore runtime PATH modifications (Start-Job runs in a new process)
            if ($envPath) { $env:Path = $envPath }
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $cmd
            $psi.Arguments = ($cmdArgs | ForEach-Object {
                if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
            }) -join ' '
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $proc = [System.Diagnostics.Process]::Start($psi)
            $timedOut = -not $proc.WaitForExit($timeout * 1000)
            if ($timedOut) { try { $proc.Kill() } catch {} }
            $result = @{ TimedOut = $timedOut; ExitCode = if ($timedOut) { -1 } else { $proc.ExitCode } }
            try { $proc.Dispose() } catch {}
            $result
        } -ArgumentList 'ollama', @('create', $script:CustomModelName, '-f', $modelfilePath), 120, $env:Path

        while ($createJob.State -eq 'Running') {
            if ($isInteractive) {
                $c = $spinChars[$spinIdx % 10]
                Write-Host "`r    $c $createMsg" -NoNewline
            }
            $spinIdx++
            Start-Sleep -Milliseconds 100
        }
        if ($isInteractive) { Write-Host "`r$(' ' * ($createMsg.Length + 8))`r" -NoNewline }

        $createResult = Receive-Job -Job $createJob -Wait
        Remove-Job -Job $createJob -Force

        if ($createResult.TimedOut) {
            Write-Warning $script:Msg.CustomCreateTO
            return
        }
        if ($createResult.ExitCode -ne 0) {
            Write-Warning ($script:Msg.CustomCreateFail -f $actionVerb)
            return
        }
        Write-Success ($script:Msg.CustomDone -f $actionVerb, $script:CustomModelName)
    } finally {
        if (Test-Path $modelfilePath) { Remove-Item -LiteralPath $modelfilePath -Force -ErrorAction SilentlyContinue }
    }
}

# ============================================================================
# Verification
# ============================================================================

function Test-Installation {
    Write-Host ""
    Write-Step $script:Msg.Verifying

    if (-not (Test-CommandExists 'ollama')) { Write-Err $script:Msg.OllamaNotFound; return $false }

    try { $null = Invoke-RestMethod -Uri "$OllamaApiUrl/api/version" -TimeoutSec 5 }
    catch { Write-Err $script:Msg.ServerUnreachable; return $false }

    if (-not (Test-OllamaModelExists $script:ModelName)) { Write-Err ($script:Msg.BaseNotFound -f $script:ModelName); return $false }
    Write-Success ($script:Msg.BaseOk -f $script:ModelName)

    $testModel = $script:ModelName
    if (Test-OllamaModelExists $script:CustomModelName) {
        Write-Success ($script:Msg.CustomOk -f $script:CustomModelName)
        $testModel = $script:CustomModelName
    } else {
        Write-Warning $script:Msg.CustomUnavail
    }

    if (-not (Test-ModelInference -Model $testModel)) {
        Write-Warning $script:Msg.InferenceFailed
    }

    Show-BenchmarkResult -Model $testModel

    Write-Host ""
    Write-Success $script:Msg.SetupDone
    return $true
}

# ============================================================================
# Main
# ============================================================================

function Main {
    $langCode = Select-Language
    Initialize-Messages -LangCode $langCode

    $null = Select-ModelConfig -RequestedModel $Model
    Test-Prerequisites
    Install-Ollama
    Install-BaseModel
    New-CustomModel

    if (-not (Test-Installation)) { exit 1 }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  $($script:Msg.SetupComplete)" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    $finalModel = if (Test-OllamaModelExists $script:CustomModelName) { $script:CustomModelName } else { $script:ModelName }

    Write-Host $script:Msg.Installed
    Write-Host "$($script:Msg.BaseModelLabel)$($script:ModelName)"
    if (Test-OllamaModelExists $script:CustomModelName) {
        Write-Host "$($script:Msg.HablaraModelLabel)$($script:CustomModelName)"
    }
    Write-Host ""
    Write-Host $script:Msg.OllamaConfig -ForegroundColor Blue
    Write-Host "$($script:Msg.ModelLabel)$finalModel"
    Write-Host "$($script:Msg.BaseUrlLabel)http://localhost:11434"
    Write-Host ""
    Write-Host $script:Msg.Docs -ForegroundColor Cyan
    Write-Host ""
}

Main
