#!/bin/bash
# Usage : depuis fiapp/, lancer "source ./setenv.sh"
dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export TORQHOME="$(cd "${dirpath}/../TorQ" && pwd)"   # framework (non modifié)
export TORQAPPHOME="${dirpath}"                        # application (dépôt Git)
export TORQDATAHOME="$(cd "${dirpath}/../data" && pwd)" # données (hors Git)

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

# torq.sh recharge le fichier désigné par SETENV : on le fait pointer ici
export SETENV=${TORQAPPHOME}/setenv.sh

# raccourci : "torq start all", "torq summary"...
alias torq="${TORQHOME}/torq.sh"
