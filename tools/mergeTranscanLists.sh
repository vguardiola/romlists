#!/usr/bin/env bash

rm -rf Transcan/
git clone https://github.com/Arley4d/Transcan.git
rm -rf Transcan/.git
./compare.sh
sleep 5
./generateTranscanLists.sh
