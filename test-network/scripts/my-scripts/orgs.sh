
function useOrg(){
    USING_ORG=$1
    USING_MSP=$2
    USING_PORT=$3
    USING_HOME_PATH=$4

    echo "USEoRG SCRIPT #################################################";
    echo "USING_ORG: $USING_ORG";
    echo "USING_MSP: $USING_MSP";
    echo "USING_PORT: $USING_PORT";
    echo "USING_HOME_PATH: $USING_HOME_PATH";

    export ORDERER_CA=${USING_HOME_PATH}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
    export CORE_PEER_LOCALMSPID=${USING_MSP}
    export CORE_PEER_TLS_ROOTCERT_FILE=${USING_HOME_PATH}/organizations/peerOrganizations/${USING_ORG}.example.com/users/Admin@${USING_ORG}.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${USING_HOME_PATH}/organizations/peerOrganizations/${USING_ORG}.example.com/users/Admin@${USING_ORG}.example.com/msp
    export CORE_PEER_ADDRESS=localhost:${USING_PORT}
}


