#!/bin/bash

HIGHLIGHT="\e[01;34m"
NORMAL='\e[00m'

echo -e "${HIGHLIGHT}================================================================================${NORMAL}"
echo -e "${HIGHLIGHT} Doing batch analysis for all sub git repositories${NORMAL}"
echo -e "${HIGHLIGHT}   > at '$1' ${NORMAL}"
echo -e "${HIGHLIGHT}================================================================================${NORMAL}"
#./listing.all.repos.from.sh $1
./scan.all.repos.at.pl $1
./gathering.all.repos.data.from.sh
./top-risk-list.pl $1 $2 $3
echo -e "${HIGHLIGHT} Batch analysis completed${NORMAL}"
