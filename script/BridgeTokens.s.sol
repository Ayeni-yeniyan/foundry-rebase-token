// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/interfaces/IERC20.sol";

contract BridgeTokensScript is Script {
    function run(
        address receiverAddress,
        address routerAddress,
        address tokenToSendAddress,
        address linkTokenAddress,
        uint256 amountToSend,
        uint64 destinationSelector
    ) public {
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(tokenToSendAddress),
            amount: amountToSend
        });
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });
        vm.startBroadcast();
        uint256 fee = IRouterClient(routerAddress).getFee(
            destinationSelector,
            evm2AnyMessage
        );
        IERC20(linkTokenAddress).approve(routerAddress, fee);
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);
        IRouterClient(routerAddress).ccipSend(
            destinationSelector,
            evm2AnyMessage
        );
        vm.stopBroadcast();
    }
}
