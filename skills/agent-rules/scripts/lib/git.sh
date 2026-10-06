# shellcheck shell=bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
#
# Git in the analysed project. The scripts read a project they did not write,
# and that project's .git/config can name commands git runs: core.fsmonitor
# when git refreshes the index (git ls-files does), core.hooksPath when it
# reaches a hook, and the signature program (gpg.program, gpg.ssh.program)
# when log.showSignature makes git log verify signed commits. project_git
# turns these off and skips the system config.

project_git() {
    GIT_CONFIG_NOSYSTEM=1 command git -c core.fsmonitor=false -c core.hooksPath=/dev/null \
        -c log.showSignature=false "$@"
}
