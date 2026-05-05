#!/bin/bash
echo "ulimit -n: $(ulimit -n)"

echo -e "\tlsof\tcommand\tpid"
lsof -u $USER 2>/dev/null | awk 'NR>1 {print $1, $2}' | sort | uniq -c | sort -rn | head -n 10

echo -e "\nsysctl fs.inotify"
sysctl fs.inotify

echo -e "\tinotify\tpid\tuser\tcomm"
find /proc/*/fd -lname "anon_inode:inotify" 2>/dev/null | cut -d/ -f3 | xargs -I '{}' ps --no-headers -o "pid,user,comm" -p '{}' 2>/dev/null | sort | uniq -c | sort -rn | head -n 25

