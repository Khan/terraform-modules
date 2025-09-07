#!/bin/bash

# see https://til.simonwillison.net/yaml/yamlfmt

function is_bin_in_path {
  builtin type -P "$1" &> /dev/null
}

export GOBIN="$HOME/go/bin"
mkdir -p "$GOBIN"
# we installed go binaries to $GOBIN
# so we ensure those both are in the PATH and take precedence
export PATH="$GOBIN:$PATH"

! is_bin_in_path yamlfmt && GOBIN=$HOME/go/bin go install -v github.com/google/yamlfmt/cmd/yamlfmt@latest

# -formatter indentless_arrays=true,retain_line_breaks=true
yamlfmt \
  -conf .yamlfmt.yaml .