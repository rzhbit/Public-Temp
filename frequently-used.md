
### 常用code

将25个文件分成5批，避免内存错误
```shell
split -n l/5 $file -d -a 1 features_ && ls | grep -E "^features_" | xargs -n1 -I {} mv {} {}.txt
```

awk分割字符串，输出字符串的第三个字符
```shell
less $file | awk '{print substr($1, 3, 1)}'
```

管理gcc版本安装切换gcc版本
```shell
#ls /opt/rh
scl enable devtoolset-8 bash
gcc -v
```

linux设置代理
```shell
export proxy="http://127.0.0.1:7897"
export http_proxy=$proxy
export https_proxy=$proxy
export ftp_proxy=$proxy
export no_proxy="localhost, 127.0.0.1, ::1"
```

```shell
#git全局设置代理
git config --global http.proxy $proxy
git config --global https.proxy $proxy
#git取消代理设置
git config --global --unset http.proxy
git config --global --unset https.proxy
#git验证代理是否生效
git config --global --get http.proxy
git config --global --get https.proxy
```

查看服务日志
```
journalctl -u mihomo -o cat
```
