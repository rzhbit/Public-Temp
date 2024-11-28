
### 常用code


将25个文件分成5批，避免内存错误
```shell
split -n l/5 $file -d -a 1 features_ && ls | grep -E "^features_" | xargs -n1 -I {} mv {} {}.txt
```

awk分割字符串，输出字符串的第三个字符
```shell
less $file | awk '{print substr($1, 3, 1)}'
```
