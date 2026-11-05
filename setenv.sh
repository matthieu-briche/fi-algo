#!/bin/bash
# Usage: from fiapp/, run "source ./setenv.sh"
dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export TORQHOME="$(cd "${dirpath}/../TorQ" && pwd)"   # framework (unmodified)
export TORQAPPHOME="${dirpath}"                        # application (Git repository)
export TORQDATAHOME="$(cd "${dirpath}/../data" && pwd)" # data (outside Git)

export KDBCONFIG=${TORQHOME}/config
export KDBCODE=${TORQHOME}/code
export KDBTESTS=${TORQHOME}/tests
export KDBHTML=${TORQHOME}/html
export KDBLIB=${TORQHOME}/lib

export KDBLOG=${TORQDATAHOME}/logs
export KDBHDB=${TORQDATAHOME}/hdb
export KDBWDB=${TORQDATAHOME}/wdbhdb
export KDBTPLOG=${TORQDATAHOME}/tplogs
export KDBDQCDB=${TORQDATAHOME}/dqe/dqcdb/database
export KDBDQEDB=${TORQDATAHOME}/dqe/dqedb/database
export KDBPCAPS=${TORQAPPHOME}/pcaps

export KDBAPPCONFIG=${TORQAPPHOME}/appconfig
export KDBAPPCODE=${TORQAPPHOME}/code
export TORQPROCESSES=${KDBAPPCONFIG}/process.csv

export KDBBASEPORT=6000
export RLWRAP="rlwrap"
export QCON="qcon"
export QCMD="q"
export DOGSTATSD_PORT=8125

mkdir -p ${KDBLOG} ${KDBHDB} ${KDBTPLOG}

# torq.sh reloads the file named by SETENV: point it here
export SETENV=${TORQAPPHOME}/setenv.sh

# raccourci : "torq start all", "torq summary"...
alias torq="${TORQHOME}/torq.sh"
