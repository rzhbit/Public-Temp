#!/bin/bash
echo "=== 系统概览 ==="
uptime
echo -e "\n=== CPU状态 ==="
mpstat -P ALL 1 1
echo -e "\n=== 内存状态 ==="
free -h
echo -e "\n=== I/O等待 ==="
iostat -x 1 3 | grep -A1 "^avg"
echo -e "\n=== 进程状态统计 ==="
ps aux | awk '{print $8}' | sort | uniq -c
echo -e "\n=== 最耗资源进程 ==="
ps aux --sort=-%cpu | head -10
