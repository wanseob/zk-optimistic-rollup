#!/bin/bash

BASEDIR=$(dirname "$0")
CIRCUIT_PATH="build/circuits.test"
VK_ARTIFACTS="build/vks.test"
PK_ARTIFACTS="build/pks.test"
MAX_JOB=4
cd $BASEDIR/..
mkdir -p $VK_ARTIFACTS
mkdir -p $PK_ARTIFACTS

i=0
for circuit in "$CIRCUIT_PATH"/*.json;
do
    i=$(($i+1))
    echo "Running setup $circuit"
    circuit_name="$(basename "$circuit" ".json")"
    NODE_OPTIONS="--max-old-space-size=4096" ./node_modules/.bin/snarkjs setup -c "$circuit" -o --pk "$PK_ARTIFACTS/$circuit_name.pk.json" --vk "$VK_ARTIFACTS/$circuit_name.vk.json" --protocol groth &
    if (( $i % $MAX_JOB == 0 )); then wait; fi
done
wait