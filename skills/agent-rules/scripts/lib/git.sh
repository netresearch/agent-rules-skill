# shellcheck shell=bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
#
# Git in the analysed project. The scripts read a project they did not write,
# and that project's .git/config can name commands git runs: core.fsmonitor
# when git refreshes the index (git ls-files does), core.hooksPath when it
# reaches a hook, and the signature program (gpg.program, gpg.ssh.program)
# when log.showSignature makes git log verify signed commits, and the
# transport command of a promisor remote when git fetches a missing object.
# project_git turns these off (no lazy fetch, no transport at all) and skips
# the system config. Inherited variables that point git at another repository
# or index (set when the scripts run from a git hook) are removed, so git
# answers for the analysed project.

project_git() {
    env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY \
        -u GIT_ALTERNATE_OBJECT_DIRECTORIES -u GIT_COMMON_DIR -u GIT_NAMESPACE \
        GIT_CONFIG_NOSYSTEM=1 GIT_NO_LAZY_FETCH=1 \
        git -c core.fsmonitor=false -c core.hooksPath=/dev/null \
        -c log.showSignature=false -c protocol.allow=never "$@"
}
