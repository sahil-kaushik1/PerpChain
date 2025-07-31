pragma solidity ^0.8.26;
import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRebaseToken} from "../src/IRebaseToken.sol";

contract CrossChainTest is Test {
    uint256 sepoliaFork;
    uint256 arbsepFork;
    CCIPLocalSimulatorFork cciplocalsimulatorFork;
    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;
    Vault vault;
    address owner;
    Register.NetworkDetails sepoliaNetworkDetail;
    Register.NetworkDetails arbSepNetworkDetail;
    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbsepPool;

    function setUp() public {
        owner = vm.makeAddr("owner");
        user = vm.makeAddr("user");
        sepoliaFork = vm.createSelectFork("sepolia");
        sepoliaNetworkDetail = cciplocalsimulatorFork.getNetworkDetails(
            block.chainid
        );
        arbsepFork = vm.CreateFork("arbsep");
        cciplocalsimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(cciplocalsimulatorFork));
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        sepoliaPool = new RebaseTokenPoolI(
            IERC20(address(sepoliaToken)),
            new address[0],
            sepoliaNetworkDetail.rmnProxyAddress,
            sepoliaNetworkDetail.routerAddress
        );

        vault = new Vault(IRebase(adress(sepoliaToken)));
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        sepoliaToken.grantMintAndBurnRole(address(vault));
        RegistryModuleOwnerCustom(
            sepoliaNetworkDetail
                .registryModuleOwnerCustom
                .registerAdminViaOwner(address(sepoliaToken))
        );
        TokenAdminRegistry(sepoliaNetworkDetail.tokenAdminRegistryAddress)
            .acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetail.tokenAdminRegistryAddress)
            .setPool(address(sepoliaToken), address(sepoliaPool));

        vm.stopPrank();
        vm.selectFork(arbsepFork);
        arbSepNetworkDetail = cciplocalsimulatorFork.getNetworkDetails(
            block.chanid
        );

        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        arbsepPool = new RebaseTokenPoolI(
            IERC20(address(arbSepoliaToken)),
            new address[0],
            arbSepNetworkDetail.rmnProxyAddress,
            arbSepNetworkDetail.routerAddress
        );
        arbSepoliaToken.grantMintAndBurnRole(address(arbsepPool));
        RegistryModuleOwnerCustom(
            arbSepNetworkDetail.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepNetworkDetail.tokenAdminRegistryAddress)
            .acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepNetworkDetail.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaToken), address(arbSepPool));
        vm.stopPrank();
        vm.startPrank(owner);
        configureTokenPool(
            sepoliaFork, // Local chain: Sepolia
            address(sepoliaPool), // Local pool: Sepolia's TokenPool
            arbSepNetworkDetail.chainSelector, // Remote chain selector: Arbitrum Sepolia's
            address(arbSepoliaPool), // Remote pool address: Arbitrum Sepolia's TokenPool
            address(arbSepoliaToken) // Remote token address: Arbitrum Sepolia's Token
        );

        // Configure Arbitrum Sepolia Pool to interact with Sepolia Pool
        configureTokenPool(
            arbsepFork, // Local chain: Arbitrum Sepolia
            address(arbSepoliaPool), // Local pool: Arbitrum Sepolia's TokenPool
            sepoliaNetworkDetail.chainSelector, // Remote chain selector: Sepolia's
            address(sepoliaPool), // Remote pool address: Sepolia's TokenPool
            address(sepoliaToken) // Remote token address: Sepolia's Token
        );
        vm.stopPrank();
    }

    function configureTokenPool(
        uint256 forkid,
        address localPoolAddress,
        uint64 remoteChainSelector,
        address remotePoolAddress,
        address remoteTokenAddress
    ) public {
        vm.selectFork(forkid);
        uint64[] memory remoteChainSelectorToRemore = new uint64[](0);
        TokenPool.ChainUpdate[]
            memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        bytes[] memory remotePoolAddressesBytesArray = new bytes[1];
        remotePoolAddressesBytesArray[0] = abi.encode(remotePoolAddress);
        //struct ChainUpdate {
        //     uint64 remoteChainSelector;
        //     bytes remotePoolAddresses; // ABI-encoded array of remote pool addresses
        //     bytes remoteTokenAddress;  // ABI-encoded remote token address
        //     RateLimiter.Config outboundRateLimiterConfig;
        //     RateLimiter.Config inboundRateLimiterConfig;
        // }
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: abi.encode(remotePoolAddressesBytesArray),
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
        vm.prank(owner);
        TokenPool(localPoolAddress).applyChainUpdates(
            (remoteChainSelectorToRemore, chainsToAdd)
        );
    }

    function BridgeToken(
        uint25 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localchainNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork);
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountToBridge
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: avi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localchainNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(
                Client.EVMExtaArgsV1({gasLimit: 100_00, strict: false})
            )
        });
        uint256 fee = IRouterClient(localchainNetworkDetails.routerAddress)
            .getFee(remoteNetworkDetails.chainSelector, message);
        CCIPLocalSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank(user);

        vm.prank(user);
        IERC20(localchainNetworkDetails.linkAddress).approve(
            localchainNetworkDetails.routerAddress,
            fee
        );
        uint256 localBalanceBefore = localToken.balanceOf(user);

        vm.prank(user);
        IERC20(address(localToken)).approve(
            localchainNetworkDetails.routerAddress,
            amountToBridge
        );
        vm.prank(user);
        bytes32 messageId = IRouterClient(
            localchainNetworkDetails.routerAddress
        ).ccipSend(remoteNetworkDetails.chainSelector, message);
        uint256 localBalanceAfter = localToken.balanceOf(user);
        assertEq(
            localBalanceAfter,
            localBalanceBefore - amountToBridge,
            "Local balance incorrect after send"
        );

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 20 minutes);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);
        assertEq(
            remoteBalanceAfter,
            remoteBalanceBefore + amountToBridge,
            "Remote balance incorrect after receive"
        );

        
    }
    function testBridgeAllTokens() public {
         uint256  DEPOSIT_AMOUNT = 1e5;
         vm.selectFork(sepoliaFork);

         vm.deal(user,DEPOSIT_AMOUNT);
         vm.prank(user);
         Vault(payable(address(vault))).deposit(value:DEPOSIT_AMOUNT){};
         assertEq(sepoliaToken.balanceOf(user),DEPOSIT_AMOUNT,"NO Balance");
         BridgeToken(
           DEPOSIT_AMOUNT,
           sepoliaFork,
           arbSepFork,
           sepoliaNetworkDetail,
           arbSepNetworkDetail,
           sepoliaToken,
           arbSepoliaToken
         );
         vm.selectFork(arbSepFork);
    vm.warp(block.timestamp + 20 minutes); 

    uint256 arbBalanceToBridgeBack = arbSepoliaToken.balanceOf(user);
    assertTrue(arbBalanceToBridgeBack > 0, "User Arbitrum balance should be non-zero before bridging back");
 
             BridgeToken(
           arbBalanceToBridgeBack,arbSepFork,
           sepoliaFork,
           arbSepNetworkDetail,
           sepoliaNetworkDetail,
           arbSepoliaToken,
           sepoliaToken
           
         );
         vm.selectFork(sepoliaFork);
    assertEq(sepoliaToken.balanceOf(user), DEPOSIT_AMOUNT, "User Sepolia token balance after bridging back incorrect");

        }
}
