#!/bin/sh
# Fails on any formatting or style issue. Fix with: swift format format --in-place --recursive <paths>
set -eu
cd "$(dirname "$0")/.."
swift format lint --strict --recursive Quicknote QuicknoteKit/Sources QuicknoteKit/Tests QuicknoteTests
