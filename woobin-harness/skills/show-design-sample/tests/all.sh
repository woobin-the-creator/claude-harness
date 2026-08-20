#!/bin/sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

sh "$DIR/init-preview.sh"
sh "$DIR/build-preview.sh"
sh "$DIR/deploy-preview.sh"
sh "$DIR/skill-contract.sh"
echo ALL-OK
