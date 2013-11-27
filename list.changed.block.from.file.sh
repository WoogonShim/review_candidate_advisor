#!/bin/bash

# SHOW DIFF
# -W (function context)
# git diff $(git rev-list -n1 --before="1 day ago" master)
# git diff -W master master@{"one month ago"} -- filepath

# SHOW LOG
# git whatchanged --since="one month ago" -- filepath

# SHOW BLAME
#  git blame -n -c --date=short --since="one month ago" -- filepath

# 한달 동안 수정한 함수 목록과 수정 횟수 가져오기
# git log -p --since="one month ago" -- $1 | grep -E '^(@@)' | sed 's/@@.*@@\s*//' | grep -E '[^\s*:]$' | grep -oE ' (\w+)\(' | grep -oE '(\w+)' | sort | uniq -c | sort -rn
git log -p --since="one month ago" -- src/pbs_interface_json_parser.c | grep -E '^(@@)' | sed 's/@@.*@@\s*//' | grep -E '[^\s*:]$' | sort | uniq -c | sort -rn
# https://coderwall.com/p/v1r8jq
# 한달 동안 가장 커밋을 많이 한 사람
# git log --pretty=format:%an --since="one month ago" | sort | uniq -c | sort -n | tac | head -30
