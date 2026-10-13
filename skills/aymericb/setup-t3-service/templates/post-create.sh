#!/usr/bin/env bash
set -euo pipefail

exec > >(tee /tmp/post-create.log) 2>&1
set -x

npm install --global t3
