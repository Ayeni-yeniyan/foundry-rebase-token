// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {TokenPool, RateLimiter} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";

contract ConfigurePoolScript is Script {
    function run(
        address localPool,
        address remotePool,
        uint64 remoteChainSelector,
        address remoteTokenAddress,
        bool outboundRateLimiterEnabled,
        uint128 outboundRateLimiterRate,
        uint128 outboundRateLimiterCapacity,
        bool inboundRateLimiterEnabled,
        uint128 inboundRateLimiterRate,
        uint128 inboundRateLimiterCapacity
    ) public {
        vm.startBroadcast();
        TokenPool.ChainUpdate[]
            memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddress: abi.encode(remotePool),
            allowed: true,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outboundRateLimiterEnabled,  
                capacity: outboundRateLimiterCapacity,
                rate: outboundRateLimiterRate
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inboundRateLimiterEnabled,
                capacity: inboundRateLimiterCapacity,
                rate: inboundRateLimiterRate
            })
        });

        TokenPool(localPool).applyChainUpdates(chainsToAdd);
        vm.stopBroadcast();
    }
}
