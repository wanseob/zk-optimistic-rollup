#!/bin/bash

BASEDIR=$(dirname "$0")
ARTIFACTS="build/circuits.test/"
MAX_JOB=8
cd $BASEDIR/..
mkdir -p $ARTIFACTS

i=0
for circuit in "circuits/tester"/*.circom;
do
    i=$(($i+1))
    echo "Compiling $circuit"
    filename="$ARTIFACTS/$(basename "$circuit" ".circom").json"
    NODE_OPTIONS="--max-old-space-size=4096" ./node_modules/.bin/circom "$circuit" -o $filename &
    if (( $i % $MAX_JOB == 0 )); then wait; fi
done
wait;