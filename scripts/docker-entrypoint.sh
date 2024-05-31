#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
# or there are no args
if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
    set -- cassandra -f "$@"
fi

if [ "$CASSANDRA_CONF" == "" ]; then
    export CASSANDRA_CONF=/etc/cassandra
fi

if [ "$1" = 'mgmtapi' ]; then
    echo "Starting Management API"

    # Copy over any config files mounted at /config
    # cp /config/cassandra.yaml /etc/cassandra/cassandra.yaml
    if [ -d "/config" ] && ! [ "/config" -ef "$CASSANDRA_CONF" ]; then
        cp -R /config/* "${CASSANDRA_CONF:-/etc/cassandra}"
    fi

    MGMT_API_ARGS=""
    # set the listen port to 8080 if not already set
    : ${MGMT_API_LISTEN_TCP_PORT='8080'}
    # Hardcoding these for now
    MGMT_API_CASSANDRA_SOCKET="--cassandra-socket /tmp/cassandra.sock"
    MGMT_API_LISTEN_TCP="--host tcp://0.0.0.0:${MGMT_API_LISTEN_TCP_PORT}"
    MGMT_API_LISTEN_SOCKET="--host file:///tmp/oss-mgmt.sock"

    MGMT_API_ARGS="$MGMT_API_ARGS $MGMT_API_CASSANDRA_SOCKET $MGMT_API_LISTEN_TCP $MGMT_API_LISTEN_SOCKET"

    # These will generally come from the k8s operator
    if [ ! -z "$MGMT_API_EXPLICIT_START" ]; then
        MGMT_API_EXPLICIT_START="--explicit-start $MGMT_API_EXPLICIT_START"
        MGMT_API_ARGS="$MGMT_API_ARGS $MGMT_API_EXPLICIT_START"
    fi

    if [ ! -z "$MGMT_API_TLS_CA_CERT_FILE" ]; then
        MGMT_API_TLS_CA_CERT_FILE="--tlscacert $MGMT_API_TLS_CA_CERT_FILE"
        MGMT_API_ARGS="$MGMT_API_ARGS $MGMT_API_TLS_CA_CERT_FILE"
    fi
    if [ ! -z "$MGMT_API_TLS_CERT_FILE" ]; then
        MGMT_API_TLS_CERT_FILE="--tlscert $MGMT_API_TLS_CERT_FILE"
        MGMT_API_ARGS="$MGMT_API_ARGS $MGMT_API_TLS_CERT_FILE"
    fi
    if [ ! -z "$MGMT_API_TLS_KEY_FILE" ]; then
        MGMT_API_TLS_KEY_FILE="--tlskey $MGMT_API_TLS_KEY_FILE"
        MGMT_API_ARGS="$MGMT_API_ARGS $MGMT_API_TLS_KEY_FILE"
    fi

    if [ ! -z "$MGMT_API_PID_FILE" ]; then
        MGMT_API_PID_FILE="--pidfile $MGMT_API_PID_FILE"
        MGMT_API_ARGS="$MGMT_API_ARGS $MGMT_API_PID_FILE"
    fi

    MGMT_API_CASSANDRA_HOME="--cassandra-home ${CASSANDRA_HOME}"
    MGMT_API_ARGS="$MGMT_API_ARGS $MGMT_API_CASSANDRA_HOME"

    MGMT_API_NO_KEEP_ALIVE="--no-keep-alive true"
    MGMT_API_ARGS="$MGMT_API_ARGS $MGMT_API_NO_KEEP_ALIVE"

    MGMT_API_JAR="${MAAC_PATH}/datastax-mgmtapi-server.jar"

    # use default of 128m heap if env variable not set
    : "${MGMT_API_HEAP_SIZE:=128m}"
    echo "Running" java ${MGMT_API_JAVA_OPTS} -Xms${MGMT_API_HEAP_SIZE} -Xmx${MGMT_API_HEAP_SIZE} -jar "$MGMT_API_JAR" $MGMT_API_ARGS
    java ${MGMT_API_JAVA_OPTS} -Xms${MGMT_API_HEAP_SIZE} -Xmx${MGMT_API_HEAP_SIZE} -jar "$MGMT_API_JAR" $MGMT_API_ARGS
fi

exec "$@"
