set shell := ["bash", "-cu"]

# Run Kurtosis Polygon PoS 
kurtosis count="2":
    @yq -y --in-place "(.polygon_pos_package.participants[0].count) = {{count}}" pos.yml
    kurtosis clean --all
    kurtosis run --enclave pos github.com/0xPolygon/kurtosis-polygon-pos --args-file pos.yml

# Export Genesis and enodes
export-files:
    docker cp $(docker ps | grep bor-heimdall | head -n 1 | awk '{print $1}'):/etc/bor/genesis.json ./genesis.json
    PORTS=$(docker ps | grep bor-heimdall | awk '{for(i=1;i<=NF;i++) if($i~/0.0.0.0.*->30303/) print substr($i,index($i,":")+1,index($i,"-")-index($i,":")-1)}' | tail -r) && docker exec $(docker ps | grep bor-heimdall | head -n1 | awk '{print $1}') cat /etc/bor/config.toml | grep "static-nodes" | sed 's/.*\[\(.*\)\]/\1/' | tr ',' '\n' | sed 's/"//g' | sed 's/@.*$//' | paste - <(echo "$PORTS") | awk '{print $1"@127.0.0.1:"$2}' >> enodes.txt

# Update bor's config.toml
update-config:
    @sed -i '' -E "s|^([[:space:]]*static-nodes[[:space:]]*=).*|\1 $( paste -sd, enodes.txt | sed 's/[^,]*/"&"/g; s/^/[ /; s/$/ ]/' )|"  config.toml
    @HEIM=$(kurtosis port print pos l2-cl-1-heimdall-bor-validator http) && \
    sed -E -i '' "/^\[heimdall]/,/^\[/s|^([[:space:]]*url[[:space:]]*=).*|\1 \"${HEIM}\"|"  config.toml

# Clone and run bor alongside kurtosis enclave
bor:
    @[ -d bor ] || git clone https://github.com/maticnetwork/bor.git && cd bor && git checkout v2.0.3
    cp genesis.json bor/
    cp config.toml bor/
    cd bor && make bor
    tomlq -i -t '.p2p.discovery["static-nodes"] = []'  config.toml
    bor/build/bin/bor server --config bor/config.toml --state.scheme hash

# Clone, update and modify Blockscout. Can be run against local bor or kurtosis l2-el-3-bor-heimdall-rpc 
blockscout with_kurtosis="false":
    if [[ "{{with_kurtosis}}" == "true" ]]; then \
        RPC_PORT=$(docker port $(docker ps -q --filter "name=bor-heimdall-rpc" | head -n1) | grep "8545/tcp" | awk -F: '{print $2}');\
        WS_PORT=$(docker port $(docker ps -q --filter "name=bor-heimdall-rpc" | head -n1) | grep "8546/tcp" | awk -F: '{print $2}');\
        yq -y --in-place \
            "(.services.backend.environment.ETHEREUM_JSONRPC_HTTP_URL  ) |= gsub(\":[0-9]+\";\":$RPC_PORT\") | \
             (.services.backend.environment.ETHEREUM_JSONRPC_TRACE_URL ) |= gsub(\":[0-9]+\";\":$RPC_PORT\") | \
             (.services.backend.environment.ETHEREUM_JSONRPC_WS_URL    ) |= gsub(\":[0-9]+\";\":$WS_PORT\")" \
            blockscout/docker-compose/docker-compose.yml; \
    fi
    @[ -d blockscout ] || git clone https://github.com/blockscout/blockscout.git
    yq -y --in-place 'del(.services."user-ops-indexer")' blockscout/docker-compose/docker-compose.yml
    yq -y --in-place 'del(.services.proxy.ports[] | select(.target == 8081))' blockscout/docker-compose/services/nginx.yml
    @docker compose -f blockscout/docker-compose/docker-compose.yml down
    @docker compose -f blockscout/docker-compose/docker-compose.yml up -d --build

# Clean generated data
clean:
    rm -rf bor/data
    rm -f enodes.txt
    rm -f genesis.json
    rm -f bor/genesis.json
    rm -f bor/config.toml
    yq -y --in-place "(.polygon_pos_package.participants[0].count) = 2" pos.yml

# Clean all docker containers
clean-docker:
    docker kill $(docker ps -qa) >/dev/null 2>&1 || true
    docker rm -f $(docker ps -qa) >/dev/null 2>&1 || true

# Start the party
start count="2" with_kurtosis="false":
    just clean
    just kurtosis {{count}}
    just export-files
    just update-config
    just blockscout {{with_kurtosis}}
    just bor