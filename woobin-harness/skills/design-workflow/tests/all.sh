#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

for test_script in \
  validate-design-md.sh \
  module-contract.sh \
  skill-contract.sh \
  router-contract.sh \
  eval-contract.sh
do
  sh "$SCRIPT_DIR/$test_script"
done

echo ALL-OK
