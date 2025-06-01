#!/bin/bash
# Parquet Pipelines Linux/Mac Installation Script

set -e

echo "🚀 Installing Parquet Pipelines..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Python installation
echo -e "${BLUE}Checking Python installation...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
    echo -e "${GREEN}Found: $(python3 --version)${NC}"
elif command -v python &> /dev/null; then
    PYTHON_CMD=python
    echo -e "${GREEN}Found: $(python --version)${NC}"
else
    echo -e "${RED}Python not found. Please install Python 3.8+ first.${NC}"
    exit 1
fi

# Check pip
echo -e "${BLUE}Checking pip...${NC}"
if command -v pip3 &> /dev/null; then
    PIP_CMD=pip3
elif command -v pip &> /dev/null; then
    PIP_CMD=pip
else
    echo -e "${RED}pip not found. Please install pip first.${NC}"
    exit 1
fi

# Detect OS and install system dependencies
echo -e "${BLUE}Installing system dependencies...${NC}"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y curl gnupg unixodbc unixodbc-dev
        
        # Install Microsoft ODBC Driver for SQL Server
        echo -e "${BLUE}Installing Microsoft ODBC Driver for SQL Server...${NC}"
        curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
        curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
        sudo apt-get update
        sudo ACCEPT_EULA=Y apt-get install -y msodbcsql17
        
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        sudo yum install -y curl unixODBC unixODBC-devel
        
        # Install Microsoft ODBC Driver
        sudo curl -o /etc/yum.repos.d/mssql-release.repo https://packages.microsoft.com/config/rhel/8/prod.repo
        sudo ACCEPT_EULA=Y yum install -y msodbcsql17
    fi
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if command -v brew &> /dev/null; then
        echo -e "${BLUE}Installing dependencies via Homebrew...${NC}"
        brew install unixodbc
        
        # Install Microsoft ODBC Driver
        brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
        brew update
        HOMEBREW_NO_ENV_FILTERING=1 ACCEPT_EULA=Y brew install msodbcsql17 mssql-tools
    else
        echo -e "${YELLOW}Homebrew not found. Please install manually or install Homebrew first.${NC}"
    fi
else
    echo -e "${YELLOW}Unknown OS. Some dependencies might need manual installation.${NC}"
fi

# Create virtual environment
echo -e "${BLUE}Creating Python virtual environment...${NC}"
$PYTHON_CMD -m venv venv
source venv/bin/activate

# Upgrade pip
echo -e "${BLUE}Upgrading pip...${NC}"
$PYTHON_CMD -m pip install --upgrade pip

# Install dependencies
echo -e "${BLUE}Installing Parquet Pipelines dependencies...${NC}"
pip install -r requirements.txt

# Install in development mode
echo -e "${BLUE}Installing Parquet Pipelines...${NC}"
pip install -e .

echo ""
echo -e "${GREEN}✅ Installation completed successfully!${NC}"
echo ""
echo -e "${YELLOW}To get started:${NC}"
echo -e "1. Activate the virtual environment: ${BLUE}source venv/bin/activate${NC}"
echo -e "2. Initialize a new project: ${BLUE}python -m parquet_pipelines init${NC}"
echo -e "3. Edit config/source_tables.yml with your database settings"
echo -e "4. Run your first extraction: ${BLUE}python -m parquet_pipelines extract --all${NC}"
echo ""
echo -e "For help: ${BLUE}python -m parquet_pipelines --help${NC}"

# Create alias (optional)
echo ""
read -p "Add 'pp' alias to your shell profile for quick access? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ALIAS_LINE="alias pp='python -m parquet_pipelines'"
    
    # Detect shell and add alias
    if [[ $SHELL == *"zsh"* ]]; then
        echo "$ALIAS_LINE" >> ~/.zshrc
        echo -e "${GREEN}Added alias to ~/.zshrc${NC}"
    elif [[ $SHELL == *"bash"* ]]; then
        echo "$ALIAS_LINE" >> ~/.bashrc
        echo -e "${GREEN}Added alias to ~/.bashrc${NC}"
    else
        echo -e "${YELLOW}Add this line to your shell profile: $ALIAS_LINE${NC}"
    fi
    
    echo -e "Restart your terminal or run: ${BLUE}source ~/.bashrc${NC} (or ~/.zshrc)"
    echo -e "Then you can use: ${BLUE}pp init${NC} instead of ${BLUE}python -m parquet_pipelines init${NC}"
fi
