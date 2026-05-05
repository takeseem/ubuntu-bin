#!/bin/bash
myid=$1
[[ -z "$myid" ]] && exit 0

echo "ls /proc/$myid/fd | wc -l"
ls /proc/$myid/fd | wc -l

echo "lsof -p $myid | head -n 20"
lsof -p $myid 2>/dev/null | head -n 20

echo "anon_inode:inotify"
find /proc/$myid/fd -lname "anon_inode:inotify" 2>/dev/null | wc -l
