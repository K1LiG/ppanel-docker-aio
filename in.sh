#!/bin/bash

# ===========================
# PPanel One-Click Deployment Script
# ===========================
# Supports selecting different service combinations for installation,
# automatically sets NEXT_PUBLIC_API_URL (default to server IP + 8080),
# clears other environment variables.
# Prompts user to modify ppanel.yaml and corresponding Docker Compose files
# when deploying the server and one-click deployment.
# Checks if the user is already in the ppanel-script directory.
# Supports English and Chinese prompts.
# Added an "Update services" option that functions similarly to "Restart services".

# ===========================
# Color Definitions
# ===========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# ===========================
# Output Functions
# ===========================
log() {
    echo -e "$1"
}

error() {
    echo -e "${RED}$1${NC}"
}

prompt() {
    echo -ne "${BOLD}$1${NC}"
}

info() {
    echo -e "${GREEN}$1${NC}"
}

warning() {
    echo -e "${YELLOW}$1${NC}"
}

bold_echo() {
    echo -e "${BOLD}$1${NC}"
}

# ===========================
# Helper Function: Set NEXT_PUBLIC_API_URL
# ===========================
set_next_public_api_url_in_yml() {
    # Default API URL is server IP + 8080 port
    DEFAULT_API_URL="http://$SERVER_IP:8080"
    if [ "$LANGUAGE" == "CN" ]; then
        prompt "请输入 NEXT_PUBLIC_API_URL (默认为：$DEFAULT_API_URL)："
    else
        prompt "Please enter NEXT_PUBLIC_API_URL (default: $DEFAULT_API_URL): "
    fi
    read api_url
    if [ -z "$api_url" ]; then
        api_url="$DEFAULT_API_URL"
        if [ "$LANGUAGE" == "CN" ]; then
            warning "未输入，使用默认的 NEXT_PUBLIC_API_URL：$api_url"
        else
            warning "No input detected. Using default NEXT_PUBLIC_API_URL: $api_url"
        fi
    fi
    yml_file=$1

    # Backup the original yml file
    cp "$yml_file" "${yml_file}.bak"

    # Create a temporary file
    temp_file=$(mktemp)

    # Initialize flag
    in_environment_section=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check if entering the environment section
        if [[ $line =~ ^[[:space:]]*environment: ]]; then
            echo "$line" >> "$temp_file"
            in_environment_section=1
            continue
        fi

        # If in the environment section
        if [[ $in_environment_section -eq 1 ]]; then
            # Check if it's the next top-level key (no indentation)
            if [[ $line =~ ^[[:space:]]{0,2}[a-zA-Z0-9_-]+: ]]; then
                in_environment_section=0
            elif [[ $line =~ ^([[:space:]]*)(NEXT_PUBLIC_API_URL): ]]; then
                indentation="${BASH_REMATCH[1]}"
                var_name="${BASH_REMATCH[2]}"
                # Set NEXT_PUBLIC_API_URL to user-provided value
                echo "${indentation}${var_name}: $api_url" >> "$temp_file"
                continue
            fi
        fi

        # Copy other lines
        echo "$line" >> "$temp_file"
    done < "$yml_file"

    # Replace the original yml file with the modified one
    mv "$temp_file" "$yml_file"
}

# ===========================
# Main Function
# ===========================
main() {
    # Display language selection menu
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${BOLD}Please select your language / 请选择语言：${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "1) English"
    echo -e "2) 中文"
    echo -e "${CYAN}==================================================${NC}"
    prompt "Please enter a number (1-2) [1]: "
    read lang_choice

    # Default to English if no input
    if [ -z "$lang_choice" ]; then
        lang_choice=1
    fi

    # Set LANGUAGE variable based on user choice
    case $lang_choice in
        1)
            LANGUAGE="EN"
            ;;
        2)
            LANGUAGE="CN"
            ;;
        *)
            warning "Invalid selection. Defaulting to English."
            LANGUAGE="EN"
            ;;
    esac

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        if [ "$LANGUAGE" == "CN" ]; then
            error "请以 root 用户运行此脚本。"
        else
            error "Please run this script as root."
        fi
        exit 1
    fi

    # Update system package index
    if [ "$LANGUAGE" == "CN" ]; then
        info "更新系统包索引..."
    else
        info "Updating system package index..."
    fi
    apt-get update -y

    # Install necessary packages
    # Check if curl is installed
    if command -v curl >/dev/null 2>&1; then
        if [ "$LANGUAGE" == "CN" ]; then
            warning "检测到 curl 已安装，跳过安装步骤。"
        else
            warning "curl is already installed. Skipping installation."
        fi
    else
        if [ "$LANGUAGE" == "CN" ]; then
            info "正在安装 curl..."
        else
            info "Installing curl..."
        fi
        apt-get install -y curl
    fi

    # Check if git is installed
    if command -v git >/dev/null 2>&1; then
        if [ "$LANGUAGE" == "CN" ]; then
            warning "检测到 git 已安装，跳过安装步骤。"
        else
            warning "git is already installed. Skipping installation."
        fi
    else
        if [ "$LANGUAGE" == "CN" ]; then
            info "正在安装 git..."
        else
            info "Installing git..."
        fi
        apt-get install -y git
    fi

    # Check if Docker is installed
    if command -v docker >/dev/null 2>&1; then
        if [ "$LANGUAGE" == "CN" ]; then
            warning "检测到 Docker 已安装，跳过安装步骤。"
        else
            warning "Docker is already installed. Skipping installation."
        fi
    else
        # Install Docker
        if [ "$LANGUAGE" == "CN" ]; then
            info "正在安装 Docker..."
        else
            info "Installing Docker..."
        fi
        curl -fsSL https://get.docker.com | bash -s -- -y
    fi

    # Check if in ppanel-script directory
    CURRENT_DIR=${PWD##*/}
    if [ "$CURRENT_DIR" != "ppanel-script" ]; then
        # Clone PPanel script repository
        if [ "$LANGUAGE" == "CN" ]; then
            info "正在克隆 PPanel 脚本仓库..."
        else
            info "Cloning PPanel script repository..."
        fi
        git clone https://ghfast.top/https://github.com/perfect-panel/ppanel-script.git
        cd ppanel-script
    else
        if [ "$LANGUAGE" == "CN" ]; then
            warning "检测到已在 ppanel-script 目录中，跳过克隆步骤。"
        else
            warning "Detected that you are already in the ppanel-script directory, skipping clone step."
        fi
    fi

    # Get server IP address
    SERVER_IP=$(hostname -I | awk '{print $1}')

    # Display service component selection menu
    bold_echo "=================================================="
    if [ "$LANGUAGE" == "CN" ]; then
        bold_echo "请选择您要执行的操作："
    else
        bold_echo "Please select the action you want to perform:"
    fi
    bold_echo "=================================================="

    if [ "$LANGUAGE" == "CN" ]; then
        echo -e "1) 一键部署（全部组件）"
        echo -e "2) 部署服务端"
        echo -e "3) 部署管理端"
        echo -e "4) 部署用户端"
        echo -e "5) 部署前端（管理端和用户端）"
        echo -e "6) 更新服务"
        echo -e "7) 重启服务"
        echo -e "8) 查看日志"
        echo -e "9) 退出"
    else
        echo -e "1) One-click deployment (All components)"
        echo -e "2) Deploy server"
        echo -e "3) Deploy admin dashboard"
        echo -e "4) Deploy user dashboard"
        echo -e "5) Deploy front-end (Admin and User dashboards)"
        echo -e "6) Update services"
        echo -e "7) Restart services"
        echo -e "8) View logs"
        echo -e "9) Exit"
    fi
    bold_echo "=================================================="

    # Prompt user for selection
    if [ "$LANGUAGE" == "CN" ]; then
        prompt "请输入一个数字 (1-9) [1]: "
    else
        prompt "Please enter a number (1-9) [1]: "
    fi
    read choice

    # If the user does not input, default to 1
    if [ -z "$choice" ]; then
        choice=1
    fi

    # Handle user selection
    case $choice in
        1)
            if [ "$LANGUAGE" == "CN" ]; then
                info "开始一键部署所有组件..."
            else
                info "Starting one-click deployment of all components..."
            fi
            # Set NEXT_PUBLIC_API_URL and update related yml files
            set_next_public_api_url_in_yml "docker-compose.yml"
            # Prompt user to modify configuration files
            if [ "$LANGUAGE" == "CN" ]; then
                warning "请根据实际需求修改以下配置文件，然后再继续部署："
                echo "- ppanel-script/config/ppanel.yaml"
                echo "- ppanel-script/docker-compose.yml"
                prompt "修改完成后，按回车键继续... "
            else
                warning "Please modify the following configuration files according to your needs before continuing:"
                echo "- ppanel-script/config/ppanel.yaml"
                echo "- ppanel-script/docker-compose.yml"
                prompt "After modification, press Enter to continue... "
            fi
            read
            docker compose up -d
            ;;
        2)
            if [ "$LANGUAGE" == "CN" ]; then
                info "开始部署服务端..."
            else
                info "Starting deployment of the server..."
            fi
            # Prompt user to modify configuration files
            if [ "$LANGUAGE" == "CN" ]; then
                warning "请根据实际需求修改以下配置文件，然后再继续部署："
                echo "- ppanel-script/config/ppanel.yaml"
                echo "- ppanel-script/ppanel-server.yml"
                prompt "修改完成后，按回车键继续... "
            else
                warning "Please modify the following configuration files according to your needs before continuing:"
                echo "- ppanel-script/config/ppanel.yaml"
                echo "- ppanel-script/ppanel-server.yml"
                prompt "After modification, press Enter to continue... "
            fi
            read
            docker compose -f ppanel-server.yml up -d
            ;;
        3)
            if [ "$LANGUAGE" == "CN" ]; then
                info "开始部署管理端..."
            else
                info "Starting deployment of the admin dashboard..."
            fi
            set_next_public_api_url_in_yml "ppanel-admin-web.yml"
            # Prompt user to modify configuration files
            if [ "$LANGUAGE" == "CN" ]; then
                warning "请根据实际需求修改以下配置文件，然后再继续部署："
                echo "- ppanel-script/ppanel-admin-web.yml"
                prompt "修改完成后，按回车键继续... "
            else
                warning "Please modify the following configuration files according to your needs before continuing:"
                echo "- ppanel-script/ppanel-admin-web.yml"
                prompt "After modification, press Enter to continue... "
            fi
            read
            docker compose -f ppanel-admin-web.yml up -d
            ;;
        4)
            if [ "$LANGUAGE" == "CN" ]; then
                info "开始部署用户端..."
            else
                info "Starting deployment of the user dashboard..."
            fi
            set_next_public_api_url_in_yml "ppanel-user-web.yml"
            # Prompt user to modify configuration files
            if [ "$LANGUAGE" == "CN" ]; then
                warning "请根据实际需求修改以下配置文件，然后再继续部署："
                echo "- ppanel-script/ppanel-user-web.yml"
                prompt "修改完成后，按回车键继续... "
            else
                warning "Please modify the following configuration files according to your needs before continuing:"
                echo "- ppanel-script/ppanel-user-web.yml"
                prompt "After modification, press Enter to continue... "
            fi
            read
            docker compose -f ppanel-user-web.yml up -d
            ;;
        5)
            if [ "$LANGUAGE" == "CN" ]; then
                info "开始部署前端（管理端和用户端）..."
            else
                info "Starting deployment of the front-end (Admin and User dashboards)..."
            fi
            set_next_public_api_url_in_yml "ppanel-web.yml"
            # Prompt user to modify configuration files
            if [ "$LANGUAGE" == "CN" ]; then
                warning "请根据实际需求修改以下配置文件，然后再继续部署："
                echo "- ppanel-script/ppanel-web.yml"
                prompt "修改完成后，按回车键继续... "
            else
                warning "Please modify the following configuration files according to your needs before continuing:"
                echo "- ppanel-script/ppanel-web.yml"
                prompt "After modification, press Enter to continue... "
            fi
            read
            docker compose -f ppanel-web.yml up -d
            ;;
        6)
            if [ "$LANGUAGE" == "CN" ]; then
                info "正在更新正在运行的服务..."
            else
                info "Updating running services..."
            fi
            # Get a list of running containers and their compose project names
            mapfile -t running_projects < <(docker ps --format '{{.Label "com.docker.compose.project"}}' | sort | uniq)
            if [ ${#running_projects[@]} -eq 0 ]; then
                if [ "$LANGUAGE" == "CN" ]; then
                    warning "未检测到正在运行的服务。"
                else
                    warning "No running services detected."
                fi
            else
                for project in "${running_projects[@]}"; do
                    if [ -z "$project" ]; then
                        continue
                    fi
                    if [ "$LANGUAGE" == "CN" ]; then
                        info "正在更新项目中的服务：$project"
                    else
                        info "Updating services in project: $project"
                    fi
                    docker compose -p "$project" pull
                    docker compose -p "$project" up -d
                done
                if [ "$LANGUAGE" == "CN" ]; then
                    info "所有正在运行的服务已更新。"
                else
                    info "All running services have been updated."
                fi
            fi
            ;;
        7)
            if [ "$LANGUAGE" == "CN" ]; then
                info "正在重启正在运行的服务..."
            else
                info "Restarting running services..."
            fi
            # Get a list of running containers and their compose project names
            mapfile -t running_projects < <(docker ps --format '{{.Label "com.docker.compose.project"}}' | sort | uniq)
            if [ ${#running_projects[@]} -eq 0 ]; then
                if [ "$LANGUAGE" == "CN" ]; then
                    warning "未检测到正在运行的服务。"
                else
                    warning "No running services detected."
                fi
            else
                for project in "${running_projects[@]}"; do
                    if [ -z "$project" ]; then
                        continue
                    fi
                    if [ "$LANGUAGE" == "CN" ]; then
                        info "正在重启项目中的服务：$project"
                    else
                        info "Restarting services in project: $project"
                    fi
                    docker compose -p "$project" restart
                done
                if [ "$LANGUAGE" == "CN" ]; then
                    info "所有正在运行的服务已重启。"
                else
                    info "All running services have been restarted."
                fi
            fi
            ;;
        8)
            if [ "$LANGUAGE" == "CN" ]; then
                info "查看日志..."
                warning "您可以按 Ctrl+C 退出日志查看。"
            else
                info "Viewing logs..."
                warning "You can press Ctrl+C to exit log viewing."
            fi
            docker compose logs -f
            ;;
        9)
            if [ "$LANGUAGE" == "CN" ]; then
                info "退出安装脚本。"
            else
                info "Exiting the installation script."
            fi
            exit 0
            ;;
        *)
            if [ "$LANGUAGE" == "CN" ]; then
                error "无效的选项，请重新运行脚本并选择正确的数字（1-9）。"
            else
                error "Invalid option, please rerun the script and select a valid number (1-9)."
            fi
            exit 1
            ;;
    esac

    # Deployment completion information (for deployment options)
    if [[ "$choice" -ge 1 && "$choice" -le 5 ]]; then
        if [ "$LANGUAGE" == "CN" ]; then
            info "部署完成！"
        else
            info "Deployment completed!"
        fi

        # Prompt access addresses
        echo ""
        if [ "$LANGUAGE" == "CN" ]; then
            bold_echo "请使用以下地址访问已部署的服务："
        else
            bold_echo "Please use the following addresses to access the deployed services:"
        fi

        if [ "$choice" == "1" ] || [ "$choice" == "2" ]; then
            if [ "$LANGUAGE" == "CN" ]; then
                echo -e "服务端（API）：${CYAN}http://$SERVER_IP:8080${NC}"
            else
                echo -e "Server (API): ${CYAN}http://$SERVER_IP:8080${NC}"
            fi
        fi
        if [ "$choice" == "1" ] || [ "$choice" == "3" ]; then
            if [ "$LANGUAGE" == "CN" ]; then
                echo -e "管理端：${CYAN}http://$SERVER_IP:3000${NC}"
            else
                echo -e "Admin Dashboard: ${CYAN}http://$SERVER_IP:3000${NC}"
            fi
        fi
        if [ "$choice" == "1" ] || [ "$choice" == "4" ]; then
            if [ "$LANGUAGE" == "CN" ]; then
                echo -e "用户端：${CYAN}http://$SERVER_IP:3001${NC}"
            else
                echo -e "User Dashboard: ${CYAN}http://$SERVER_IP:3001${NC}"
            fi
        fi
        if [ "$choice" == "5" ]; then
            if [ "$LANGUAGE" == "CN" ]; then
                echo -e "管理端：${CYAN}http://$SERVER_IP:3000${NC}"
                echo -e "用户端：${CYAN}http://$SERVER_IP:3001${NC}"
            else
                echo -e "Admin Dashboard: ${CYAN}http://$SERVER_IP:3000${NC}"
                echo -e "User Dashboard: ${CYAN}http://$SERVER_IP:3001${NC}"
            fi
        fi

        # Display default admin account information (only for options 1 or 2)
        if [ "$choice" == "1" ] || [ "$choice" == "2" ]; then
            echo ""
            if [ "$LANGUAGE" == "CN" ]; then
                bold_echo "默认管理员账户："
                echo -e "用户名: ${CYAN}admin@ppanel.dev${NC}"
                echo -e "密码: ${CYAN}password${NC}"
                warning "请在首次登录后及时修改默认密码以确保安全。"
            else
                bold_echo "Default Admin Account:"
                echo -e "Username: ${CYAN}admin@ppanel.dev${NC}"
                echo -e "Password: ${CYAN}password${NC}"
                warning "Please change the default password after the first login to ensure security."
            fi
        fi

        # Display service status
        echo ""
        if [ "$LANGUAGE" == "CN" ]; then
            bold_echo "您可以使用以下命令查看服务运行状态："
        else
            bold_echo "You can check the service status using the following command:"
        fi
        echo -e "${CYAN}docker compose ps${NC}"
    fi
}

# ===========================
# Execute the Main Function
# ===========================
main
