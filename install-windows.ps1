# Parquet Pipelines Windows Installation Script
# Run this script as Administrator

Write-Host "Installing Parquet Pipelines on Windows..." -ForegroundColor Green

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Check Python installation
Write-Host "Checking Python installation..." -ForegroundColor Blue
try {
    $pythonVersion = python --version 2>&1
    Write-Host "Found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "Python not found. Please install Python 3.8+ from https://python.org" -ForegroundColor Red
    exit 1
}

# Check if pip is available
Write-Host "Checking pip..." -ForegroundColor Blue
try {
    pip --version | Out-Null
    Write-Host "pip is available" -ForegroundColor Green
} catch {
    Write-Host "pip not found. Please ensure pip is installed with Python." -ForegroundColor Red
    exit 1
}

# Install Microsoft ODBC Driver for SQL Server
Write-Host "Installing Microsoft ODBC Driver 17 for SQL Server..." -ForegroundColor Blue
$odbcUrl = "https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/msodbcsql.msi"
$odbcInstaller = "$env:TEMP\msodbcsql.msi"

try {
    Invoke-WebRequest -Uri $odbcUrl -OutFile $odbcInstaller
    Start-Process msiexec.exe -ArgumentList "/i $odbcInstaller /quiet /norestart IACCEPTMSODBCSQLLICENSETERMS=YES" -Wait
    Write-Host "ODBC Driver installed successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Could not install ODBC Driver automatically. Please install manually if needed." -ForegroundColor Yellow
}

# Create virtual environment
Write-Host "Creating Python virtual environment..." -ForegroundColor Blue
python -m venv venv
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create virtual environment" -ForegroundColor Red
    exit 1
}

# Activate virtual environment
Write-Host "Activating virtual environment..." -ForegroundColor Blue
& .\venv\Scripts\Activate.ps1

# Upgrade pip
Write-Host "Upgrading pip..." -ForegroundColor Blue
python -m pip install --upgrade pip

# Install Parquet Pipelines
Write-Host "Installing Parquet Pipelines dependencies..." -ForegroundColor Blue
pip install -r requirements.txt

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Install in development mode
Write-Host "Installing Parquet Pipelines..." -ForegroundColor Blue
pip install -e .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to install Parquet Pipelines" -ForegroundColor Red
    exit 1
}

Write-Host "" -ForegroundColor White
Write-Host "✅ Installation completed successfully!" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "To get started:" -ForegroundColor Yellow
Write-Host "1. Activate the virtual environment: .\venv\Scripts\Activate.ps1" -ForegroundColor White
Write-Host "2. Initialize a new project: python -m parquet_pipelines init" -ForegroundColor White
Write-Host "3. Edit config/source_tables.yml with your database settings" -ForegroundColor White
Write-Host "4. Run your first extraction: python -m parquet_pipelines extract --all" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "For help: python -m parquet_pipelines --help" -ForegroundColor White

# Create desktop shortcut (optional)
$createShortcut = Read-Host "Create desktop shortcut for Parquet Pipelines? (y/n)"
if ($createShortcut -eq "y" -or $createShortcut -eq "Y") {
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$Home\Desktop\Parquet Pipelines.lnk")
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-NoExit -Command `"cd '$PWD'; .\venv\Scripts\Activate.ps1`""
    $Shortcut.WorkingDirectory = $PWD
    $Shortcut.IconLocation = "powershell.exe,0"
    $Shortcut.Description = "Parquet Pipelines Data Framework"
    $Shortcut.Save()
    Write-Host "Desktop shortcut created!" -ForegroundColor Green
}
