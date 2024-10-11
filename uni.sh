#!/bin/bash

# 定义文本格式
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
SUCCESS_COLOR='\033[1;32m'
ERROR_COLOR='\033[1;31m'
INFO_COLOR='\033[1;36m'
MENU_COLOR='\033[1;34m'

# 自定义状态显示函数
show_message() {
    local message="$1"
    local status="$2"
    case $status in
        "error")
            echo -e "${ERROR_COLOR}${BOLD}❌ 错误: ${message}${NORMAL}"
            ;;
        "info")
            echo -e "${INFO_COLOR}${BOLD}ℹ️ 信息: ${message}${NORMAL}"
            ;;
        "success")
            echo -e "${SUCCESS_COLOR}${BOLD}✅ 成功: ${message}${NORMAL}"
            ;;
        *)
            echo -e "${message}"
            ;;
    esac
}

# 定位脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# 安装必要依赖项
install_dependencies() {
    show_message "检查并安装必要的依赖项..." "info"
    apt update -y && apt install -y curl wget git

    # 检查并安装 Foundry
    if command -v forge &> /dev/null; then
        show_message "Foundry 已安装，跳过此步骤。" "success"
    else
        show_message "未找到 Foundry，正在安装..." "info"
        curl -L https://foundry.paradigm.xyz | bash
        source ~/.bashrc
        foundryup
        show_message "Foundry 安装完成。" "success"
    fi
}

# 部署 ERC-20 代币的功能
deploy_token() {
    show_message "开始 ERC-20 代币部署..." "info"
    install_dependencies

    # 收集用户输入
    read -p "请输入您的私钥: " PRIVATE_KEY
    read -p "请输入代币名称（例如：MyToken）: " TOKEN_NAME
    read -p "请输入代币符号（例如：MTK）: " TOKEN_SYMBOL
    read -p "请输入代币的初始供应量（例如：1000000）: " INITIAL_SUPPLY

    # 创建环境配置文件
    mkdir -p "$SCRIPT_DIR/token_deployment"
    cat <<EOF > "$SCRIPT_DIR/token_deployment/.env"
PRIVATE_KEY="$PRIVATE_KEY"
TOKEN_NAME="$TOKEN_NAME"
TOKEN_SYMBOL="$TOKEN_SYMBOL"
INITIAL_SUPPLY="$INITIAL_SUPPLY"
EOF

    # 加载环境变量
    source "$SCRIPT_DIR/token_deployment/.env"

    # 设置智能合约名称
    CONTRACT_NAME="MyTokenContract"

    # 检查并安装 OpenZeppelin 合约库
    if [ -d "$SCRIPT_DIR/lib/openzeppelin-contracts" ]; then
        show_message "OpenZeppelin 合约库已安装，跳过此步骤。" "success"
    else
        show_message "正在安装 OpenZeppelin 合约库..." "info"
        git clone https://github.com/OpenZeppelin/openzeppelin-contracts.git "$SCRIPT_DIR/lib/openzeppelin-contracts"
        show_message "OpenZeppelin 合约库安装完成。" "success"
    fi

    # 创建 ERC-20 代币智能合约
    show_message "创建 ERC-20 代币合约..." "info"
    mkdir -p "$SCRIPT_DIR/src"
    cat <<EOF > "$SCRIPT_DIR/src/$CONTRACT_NAME.sol"
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract $CONTRACT_NAME is ERC20 {
    constructor() ERC20("$TOKEN_NAME", "$TOKEN_SYMBOL") {
        _mint(msg.sender, $INITIAL_SUPPLY * (10 ** decimals()));
    }
}
EOF

    # 编译智能合约
    show_message "正在编译智能合约..." "info"
    forge build

    if [[ $? -ne 0 ]]; then
        show_message "合约编译失败。" "error"
        exit 1
    fi

    # 部署智能合约
    show_message "正在部署智能合约..." "info"

    # 使用 Unichain Sepolia 测试网的 RPC URL
    RPC_URL="https://sepolia.unichain.org"

    DEPLOY_OUTPUT=$(forge create "$SCRIPT_DIR/src/$CONTRACT_NAME.sol:$CONTRACT_NAME" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --chain-id 1301)

    if [[ $? -ne 0 ]]; then
        show_message "合约部署失败。" "error"
        exit 1
    fi

    # 显示合约地址
    CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP 'Deployed to: \K(0x[a-fA-F0-9]{40})')
    show_message "代币部署成功，合约地址: https://sepolia.uniscan.xyz/address/$CONTRACT_ADDRESS" "success"

    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${MENU_COLOR}${BOLD}========= ERC-20 代币管理工具 =========${NORMAL}"
        echo -e "${MENU_COLOR}1. 部署 ERC-20 代币${NORMAL}"
        echo -e "${MENU_COLOR}2. 退出${NORMAL}"
        read -p "请输入选项（1-2）: " OPTION

        case $OPTION in
            1) deploy_token ;;
            2) exit 0 ;;
            *) show_message "无效选项，请重试。" "error" ;;
        esac
    done
}

# 启动主菜单
main_menu
