ORG_NUMBER=$1
ORG_PORT=$2
local TEMP_PATH=$(dirname "$PWD")
local HOME_PATH=$(dirname "$TEMP_PATH")

export CORE_PEER_LOCALMSPID=Org${ORG_NUMBER}MSP
export CORE_PEER_TLS_ROOTCERT_FILE=${HOME_PATH}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
export CORE_PEER_MSPCONFIGPATH=${HOME_PATH}/organizations/peerOrganizations/org${ORG_NUMBER}.example.com/users/Admin@org${ORGANIZATION}.example.com/msp
export CORE_PEER_ADDRESS=localhost:${ORG_PORT}