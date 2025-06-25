

install:; forge install Openzeppelin/openzeppelin-contracts@v5.1.0 --no-commit && forge install smartcontractkit/ccip@v2.17.0-ccip1.5.16 --no-commit && forge install smartcontractkit/chainlink-local@v0.2.5-beta.0 --no-commit
remove:; forge remove openzeppelin-contracts && forge remove ccip && forge remove chainlink-local
