// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;
import {Test, console} from "forge-std/Test.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork, Register} from "lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/interfaces/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool, RateLimiter} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CrossChainTest is Test {
    address public owner = makeAddr("OWNER");
    address public user = makeAddr("USER");
    uint256 SEND_VALUE = 1e5;
    uint256 sepoliaFork;
    uint256 arbitriumFork;
    CCIPLocalSimulatorFork cciplocalSimulatorFork;

    Vault private vault;
    RebaseToken private sepoliaRebaseToken;
    RebaseToken private arbitriumRebaseToken;

    RebaseTokenPool private sepoliaRebaseTokenPool;
    RebaseTokenPool private arbitriumRebaseTokenPool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbitriumNetworkDetails;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbitriumFork = vm.createSelectFork("arb-sepolia");

        cciplocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(cciplocalSimulatorFork));

        // Deploy and configure on sepolia
        vm.startPrank(owner);
        sepoliaRebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaRebaseToken)));
        sepoliaNetworkDetails = cciplocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        sepoliaRebaseTokenPool = new RebaseTokenPool(
            IERC20(address(sepoliaRebaseToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaRebaseToken.grantMintAndBurnRole(address(vault));
        sepoliaRebaseToken.grantMintAndBurnRole(
            address(sepoliaRebaseTokenPool)
        );
        RegistryModuleOwnerCustom(
            sepoliaNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(sepoliaRebaseToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(sepoliaRebaseToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(
                address(sepoliaRebaseToken),
                address(sepoliaRebaseTokenPool)
            );
        vm.stopPrank();

        // Deploy and configure on arbitrum
        vm.selectFork(arbitriumFork);
        vm.startPrank(owner);
        arbitriumRebaseToken = new RebaseToken();
        arbitriumNetworkDetails = cciplocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        arbitriumRebaseTokenPool = new RebaseTokenPool(
            IERC20(address(arbitriumRebaseToken)),
            new address[](0),
            arbitriumNetworkDetails.rmnProxyAddress,
            arbitriumNetworkDetails.routerAddress
        );
        arbitriumRebaseToken.grantMintAndBurnRole(address(vault));
        arbitriumRebaseToken.grantMintAndBurnRole(
            address(arbitriumRebaseTokenPool)
        );
        RegistryModuleOwnerCustom(
            arbitriumNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(arbitriumRebaseToken));
        TokenAdminRegistry(arbitriumNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(arbitriumRebaseToken));
        TokenAdminRegistry(arbitriumNetworkDetails.tokenAdminRegistryAddress)
            .setPool(
                address(arbitriumRebaseToken),
                address(arbitriumRebaseTokenPool)
            );
        vm.stopPrank();
        configureTokenPool(
            sepoliaFork,
            address(sepoliaRebaseTokenPool),
            arbitriumNetworkDetails.chainSelector,
            address(arbitriumRebaseTokenPool),
            address(sepoliaRebaseToken)
        );
        configureTokenPool(
            arbitriumFork,
            address(arbitriumRebaseTokenPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaRebaseTokenPool),
            address(arbitriumRebaseToken)
        );
    }

    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteTokenAddress
    ) public {
        console.log("ConfigureTokenPool called for fork", fork);
        vm.selectFork(fork);
        vm.prank(owner);
        TokenPool.ChainUpdate[]
            memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddress: abi.encode(remotePool),
            allowed: true,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });

        TokenPool(localPool).applyChainUpdates(chainsToAdd);
        console.log("ConfigureTokenPool finished for fork", fork);
    }

    function brigdeTokens(
        uint256 amountToBrigde,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork);
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountToBrigde
        });
        vm.selectFork(localFork);
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 100_000})
            )
        });
        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(
            remoteNetworkDetails.chainSelector,
            evm2AnyMessage
        );
        cciplocalSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank((user));
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress,
            fee
        );
        vm.prank((user));
        IERC20(address(localToken)).approve(
            localNetworkDetails.routerAddress,
            amountToBrigde
        );
        uint256 localBalanceBefore = IERC20(address(localToken)).balanceOf(
            user
        );
        vm.prank((user));
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(
            remoteNetworkDetails.chainSelector,
            evm2AnyMessage
        );
        uint256 localBalanceAfter = IERC20(address(localToken)).balanceOf(user);
        assertEq(localBalanceBefore, localBalanceAfter + amountToBrigde);
        uint256 localUserInterestRate = localToken.getUserInterestRate(user);

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 20 minutes);
        uint256 remoteBalanceBefore = IERC20(address(remoteToken)).balanceOf(
            user
        );
        cciplocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
        uint256 remoteBalanceAfter = IERC20(address(remoteToken)).balanceOf(
            user
        );
        assertEq(localBalanceBefore, localBalanceAfter + amountToBrigde);
        uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);

        assertEq(remoteBalanceBefore, remoteBalanceAfter - amountToBrigde);
        assertEq(remoteUserInterestRate, localUserInterestRate);
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(sepoliaRebaseToken.balanceOf(user), SEND_VALUE);
        brigdeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbitriumFork,
            sepoliaNetworkDetails,
            arbitriumNetworkDetails,
            sepoliaRebaseToken,
            arbitriumRebaseToken
        );
    }
}
