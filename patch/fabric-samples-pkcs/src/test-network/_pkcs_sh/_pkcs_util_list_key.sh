#!/bin/bash

SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname ${SCRIPT}`
SCRIPTNAME=`basename ${SCRIPT}`

cd ${SCRIPTPATH}

set -x

. ../_pkcs.cfg


pkcs11-tool --list-objects \
  --login \
  --token-label "${_PKCS_TOKEN}" \
  --pin "${_PKCS_PIN}" \
  --module "${_PKCS_LIB_PATH}"

