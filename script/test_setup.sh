#!/bin/bash

BASEDIR=$(dirname "$0")
VK_ARTIFACTS="build/vks"
PK_ARTIFACTS="build/pks"
MAX_JOB=4
cd $BASEDIR/..
mkdir -p $VK_ARTIFACTS
mkdir -p $PK_ARTIFACTS

i=0
for circuit in "build/circuits"/*.json;
do
    i=$(($i+1))
    echo "Running setup $circuit"
    circuit_name="$(basename "$circuit" ".json")"
    NODE_OPTIONS="--max-old-space-size=4096" ./node_modules/.bin/snarkjs setup -c "$circuit" -o --pk "$PK_ARTIFACTS/$circuit_name.pk.json" --vk "$VK_ARTIFACTS/$circuit_name.vk.json" --protocol groth &
    if (( $i % $MAX_JOB == 0 )); then wait; fi
done
wait