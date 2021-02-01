#!/bin/bash 
#record all bash commands to syslog (available in bash4+). Use "history 1" to pull
# the last command from history and strip the numbers from the front of it
export PROMPT_COMMAND='RETURN_VAL=$?;logger -p local6.debug "$(whoami) [$$]: $(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//" ) [$RETURN_VAL]"'

# vi: syntax=sh ts=2 expandtab shiftwidth=2
