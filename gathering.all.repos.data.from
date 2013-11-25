#!/bin/bash
# Update all git directories below current directory or specified directory
# Skips directories that contain a file called .ignore

STARTING_DIR=`pwd 2>&1`
GIT_REPO_LIST_FILE="${STARTING_DIR}/git-repo-list"

HIGHLIGHT="\e[01;34m"
NORMAL='\e[00m'

echo -e "${HIGHLIGHT}Gathering data from all repos${NORMAL}"
xargs --arg-file=$GIT_REPO_LIST_FILE -I@ ./churn.ccn.analyzer.pl @ "c++ java web" "one month ago"
echo -e "${HIGHLIGHT}Done${NORMAL}"
