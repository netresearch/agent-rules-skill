# shellcheck shell=bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
#
# Git in the analysed project. The scripts read a project they did not write,
# and that project's .git/config can name commands git runs: core.fsmonitor
# when git refreshes the index (git ls-files does), core.hooksPath when it
# reaches a hook. project_git turns both off and skips the system config, so
# reading the project's history and file list runs nothing from it.

project_git() {
    GIT_CONFIG_NOSYSTEM=1 command git -c core.fsmonitor=false -c core.hooksPath=/dev/null "$@"
}
