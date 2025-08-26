#!/bin/bash

# ==============================================================================
# Mihomo (Clash core) 代理管理脚本
# 作者: (原作者未提供，根据脚本内容整理)
# 日期: 2023-10-27 (整理日期)
# 功能: 提供了开关代理、切换模式、切换节点、显示状态和测试延迟等功能。
# 依赖: jq (用于解析JSON数据)
# ==============================================================================

# ============================ 配置项 ============================
# Mihomo 的配置文件和可执行文件路径
MIHOMO_PATH="/media/AnalysisDisk2/Renzehui/software/mihomo"
# Mihomo 代理服务的监听地址
PROXY_HOST="127.0.0.1"
# Mihomo 代理端口 (HTTP/SOCKS5)
PROXY_PORT="7890"
# Mihomo RESTful API 端口
API_PORT="9090"
# ================================================================

# ----------------------------- 辅助函数 -----------------------------

# 检查依赖：确保系统安装了 jq 命令
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo "错误: 未找到 jq 命令。" >&2
        echo "请运行以下命令安装 jq:" >&2
        echo "sudo apt update && sudo apt install jq" >&2
        exit 1
    fi
}

# 不使用 jq 的备选 JSON 解析函数 (仅在 jq 未安装时使用)
parse_json() {
    local json="$1"
    local key="$2"
    echo "$json" | grep -o "\"$key\":\"[^\"]*\"" | sed "s/\"$key\":\"//g" | sed "s/\"//g"
}

# 显示帮助信息
show_help() {
    echo "Usage: proxy <command> [options]"
    echo
    echo "Commands:"
    echo "  on       开启代理并设置环境变量"
    echo "  off      关闭代理并清除环境变量"
    echo "  status   显示当前代理服务状态、模式和节点"
    echo
    echo "  mode <mode> 切换代理模式"
    echo "    global - 全局模式"
    echo "    direct - 直连模式"
    echo "    rule   - 规则模式"
    echo
    echo "  switch <node> 切换代理节点"
    echo "    auto   - 自动选择（通常是Selector组或URLTest组）"
    echo "    <node> - 指定具体节点名称"
    echo
    echo "  now      显示当前使用的代理节点"
    echo "  delay    显示当前节点的延迟"
    echo "  list     显示所有可用代理节点"
    echo "  test     测试所有节点的延迟"
    echo
    echo "  help     显示本帮助信息"
    echo
    # echo "注意: 本脚本依赖 jq 命令来解析 JSON。如果未安装，请运行:"
    # echo "sudo apt update && sudo apt install jq"
    # echo "注意: 带空格的节点名称需要使用引号，例如:"
    # echo "  proxy switch \"🇭🇰 香港 05\""
}

# ----------------------------- 服务管理函数 -----------------------------

# 检查 Mihomo 代理服务是否正在运行
check_service() {
    pgrep -f "mihomo -d" > /dev/null
    return $?
}

# 启动 Mihomo 代理服务
start_service() {
    if ! check_service; then
        echo "正在启动 Mihomo 代理服务..."
        "$MIHOMO_PATH/start-mihomo.sh" &
        sleep 2 # 等待服务启动
        if check_service; then
            echo "Mihomo 代理服务已启动。"
        else
            echo "错误: Mihomo 代理服务启动失败。" >&2
            exit 1
        fi
    fi
}

# 停止 Mihomo 代理服务
stop_service() {
    if check_service; then
        echo "正在停止 Mihomo 代理服务..."
        pkill -f "mihomo -d"
        sleep 1 # 稍微等待进程终止
        if ! check_service; then
            echo "Mihomo 代理服务已停止。"
        else
            echo "错误: Mihomo 代理服务停止失败。" >&2
            exit 1
        fi
    fi
}

# 设置系统代理环境变量
set_proxy() {
    export http_proxy="http://$PROXY_HOST:$PROXY_PORT"
    export https_proxy="http://$PROXY_HOST:$PROXY_PORT"
    # 可以根据需要添加其他代理变量，如 ALL_PROXY
    echo "代理环境变量已设置。"
}

# 清除系统代理环境变量
unset_proxy() {
    unset http_proxy
    unset https_proxy
    echo "代理环境变量已清除。"
}

# ----------------------------- Mihomo API 交互函数 -----------------------------

get_group() {
    local mode=$(curl -s "http://$PROXY_HOST:$API_PORT/configs" | jq -r '.mode')
    if [[ "$mode" == "global" ]]; then
        echo "GLOBAL"
    elif [[ "$mode" == "rule" ]]; then
        echo "Proxy"
    else
        echo "UNKNOWN"
    fi
}

# 切换代理模式 (global, direct, rule)
switch_mode() {
    local mode="$1"
    curl -s -H "Content-Type: application/json" -X PATCH "http://$PROXY_HOST:$API_PORT/configs" \
         -d "{\"mode\":\"$mode\"}" > /dev/null
    if [ $? -eq 0 ]; then
        echo "成功切换到 '$mode' 模式。"
    else
        echo "错误: 切换模式失败，请检查 Mihomo 服务是否运行或配置。" >&2
        return 1
    fi
}

# 切换代理节点 (通常是XFLTD组，Clash配置中默认的"Proxy"组)
switch_node() {
    local node_name="$1"
    local proxy_group_name=$(get_group)
    # 注意: /proxies/{proxy_group_name} 这个API路径中的proxy_group_name需要和你的Mihomo配置匹配
    curl -s -H "Content-Type: application/json" -X PUT "http://$PROXY_HOST:$API_PORT/proxies/$proxy_group_name" \
         -d "{\"name\":\"$node_name\"}" > /dev/null
    if [ $? -eq 0 ]; then
        echo "成功切换到节点: '$node_name'。"
    else
        echo "错误: 切换节点失败，请检查节点名称或 Mihomo 服务是否运行。" >&2
        return 1
    fi
}

# 获取当前使用的代理节点
get_current_node() {
    local proxy_group_name=$(get_group)
    local response=$(curl -s -H "Content-Type: application/json" -X GET "http://$PROXY_HOST:$API_PORT/proxies/$proxy_group_name")
    if command -v jq &> /dev/null; then
        echo "$response" | jq -r '.now'
    else
        parse_json "$response" "now"
    fi
}

# 获取指定节点的延迟
get_delay() {
    #echo "#------"
    local node="$1"
    # 对节点名称进行URL编码，因为节点名称可能包含空格或特殊字符
    local encoded_node=$(echo "$node" | sed 's/ /%20/g' | sed 's/:/%3A/g' | sed 's/\//%2F/g')

    # 首先获取节点类型，如果是代理组，则获取其当前使用的子节点
    local node_info=$(curl -s -H "Content-Type: application/json" -X GET "http://$PROXY_HOST:$API_PORT/proxies/$encoded_node")
    
    if [ -z "$node_info" ]; then
        echo "错误: 无法获取节点 '$node' 信息。" >&2
        return 1
    fi

    local node_type=$(echo "$node_info" | jq -r '.type' 2>/dev/null) # 2>/dev/null 隐藏jq错误输出
    if [[ "$node_type" == "Selector" || "$node_type" == "URLTest" || "$node_type" == "Fallback" ]]; then
        local actual_node=$(echo "$node_info" | jq -r '.now' 2>/dev/null)
        # echo "debug: 代理组 '$node' 当前使用节点: $actual_node" >&2
        if [ -n "$actual_node" ] && [ "$actual_node" != "null" ]; then
            node="$actual_node"
            encoded_node=$(echo "$actual_node" | sed 's/ /%20/g' | sed 's/:/%3A/g' | sed 's/\//%2F/g')
        else
            echo "错误: 无法获取代理组 '$node' 当前使用的节点。" >&2
            return 1
        fi
    fi

    local curl_proxy="http://$PROXY_HOST:$PROXY_PORT"
    # Mihomo 默认的测试URL
    local urls=("http://www.gstatic.com/generate_204" "http://cp.cloudflare.com/generate_204")

    for test_url in "${urls[@]}"; do
        local encoded_test_url=$(echo "$test_url" | sed 's/:/%3A/g' | sed 's/\//%2F/g')
        # echo "debug: 正在使用 $test_url 测试节点 '$node'" >&2

        local delay_info=$(curl -v -s -x "$curl_proxy" \
            -H "Content-Type: application/json" \
            --connect-timeout 3 \
            -X GET "http://$PROXY_HOST:$API_PORT/proxies/$encoded_node/delay?timeout=5000&url=$encoded_test_url" 2>&1)
        # echo "debug: curl响应: $delay_info" >&2

        if [ -n "$delay_info" ]; then
            local delay=$(echo "$delay_info" | grep -o '"delay":[0-9]*' | cut -d':' -f2)
            if [ -n "$delay" ] && [ "$delay" != "null" ]; then
                # echo "debug: 成功获取延迟: ${delay}ms" >&2
                echo "{\"delay\": $delay}"
                return 0 # 成功获取一个延迟就返回
            fi
        fi
    done

    # echo "debug: 所有URL测试失败" >&2
    echo '{"delay": -1}' # 返回-1表示超时或失败
    return 1
}


# 获取所有代理节点列表
get_all_nodes() {
    curl -s -H "Content-Type: application/json" -X GET "http://$PROXY_HOST:$API_PORT/proxies"
}

# ----------------------------- 主函数 -----------------------------

main() {
    if [ "$1" != "help" ]; then
        check_dependencies
    fi

    case "$1" in
        "on")
            start_service
            set_proxy
            echo "代理已开启。"
            ;;
        "off")
            stop_service
            unset_proxy
            echo "代理已关闭。"
            ;;
        "status")
            if check_service; then
                echo "代理服务: 运行中"
                if command -v jq &> /dev/null; then
                    echo "当前模式: $(curl -s "http://$PROXY_HOST:$API_PORT/configs" | jq -r .mode)"
                    echo "当前节点: $(get_current_node)"
                else
                    echo "当前节点: $(get_current_node)"
                    echo "提示: 安装 jq 可以获取更多信息。"
                fi
            else
                echo "代理服务: 未运行"
            fi
            ;;
        "mode")
            case "$2" in
                "global"|"direct"|"rule")
                    switch_mode "$2"
                    ;;
                *)
                    echo "无效的模式，可用模式: global, direct, rule。" >&2
                    ;;
            esac
            ;;
        "switch")
            if [ -z "$2" ]; then
                echo "请指定节点名称。" >&2
                exit 1
            fi
            local node_name="$*" # 使用 $* 获取所有参数作为节点名，支持带空格的节点名
            node_name="${node_name#switch }" # 移除 "switch " 前缀
            
            # 检查节点是否存在 (使用jq更可靠)
            local all_nodes_json=$(get_all_nodes)
            if ! echo "$all_nodes_json" | jq -e --arg name "$node_name" '.proxies | has($name)' > /dev/null; then
                echo "错误: 节点 '$node_name' 不存在。" >&2
                echo "可用节点列表:"
                echo "$all_nodes_json" | jq -r '.proxies | keys[]' | grep -v "^COMPATIBLE\|^DIRECT\|^GLOBAL\|^PASS\|^REJECT"
                exit 1
            fi
            switch_node "$node_name"
            ;;
        "now")
            echo "当前节点: $(get_current_node)"
            ;;
        "delay")
            local current_node_for_delay=$(get_current_node)
            echo "当前节点: $current_node_for_delay"
            
            local delay_json=$(get_delay "$current_node_for_delay")
            
            local delay_value=$(echo "$delay_json" | jq -r '.delay')
            
            if [[ "$delay_value" == "-1" || "$delay_value" == "null" ]]; then
                echo "延迟测试失败或超时。"
            else
                echo "延迟: ${delay_value}ms"
            fi
            ;;
        "list")
            echo "可用节点列表:"
            get_all_nodes | jq -r '.proxies | keys[]' | grep -v "^COMPATIBLE\|^DIRECT\|^GLOBAL\|^PASS\|^REJECT"
            ;;
        "test")
            echo "测试所有节点延迟..."
            local nodes_info=$(get_all_nodes)
            
            echo "$nodes_info" | jq -r '.proxies | keys[]' | while IFS= read -r node; do
                if [[ "$node" != "GLaDOS"* ]]; then # <-- 这里是新增的条件
                    continue # 如果节点满足以上任何一个条件（包括不以GLaDOS开头），则跳过
                fi
                printf "%-30s" "$node:"
                local delay_json=$(get_delay "$node")
                local delay_value=$(echo "$delay_json" | jq -r '.delay')

                if [[ "$delay_value" == "-1" || "$delay_value" == "null" ]]; then
                    echo "超时"
                else
                    echo "${delay_value}ms"
                fi
            done
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# 运行主函数，传递所有命令行参数
main "$@"
