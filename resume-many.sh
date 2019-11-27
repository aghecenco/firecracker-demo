#!/bin/bash

#Usage 
## ./resume-many.sh 0 100 # Will resume VM#0 to VM#99. 

start="${1:-0}"
upperlim="${2:-1}"

for ((i=start; i<upperlim; i++)); do
    ./resume-firecracker.sh "$i" &>/dev/null
    sleep 0.05
done
