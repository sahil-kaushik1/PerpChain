// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

import {Scipt} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/IRebaseToken.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/TokenAdminRegistry.sol";

contract TokenAndPoolDeployer is Script {
    function run() public {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork
            .getNetworkDetails(block.chainid);
        vm.startBroadcast();
        RebaseToken token = new RebaseToken();
        RebaseTokenPool pool = new RebaseTokenPool(
            IERC20(address(token)),
            new address[](0),
            networkDetails.rmnProxyAddress,
            networkDetails.routerAddress
        );
        pool.grantMintAndBurnRole(address(pool));
        RegistryModuleOwnerCustom(
            networkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(
            address(token),
            address(pool)
        );
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run(address _rebaseToken) public returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(address(_rebaseToken)));
        IRebaseToken(address(_rebaseToken)).grantMintAndBurnRole(
            address(vault)
        );
        vm.stopBroadcast();
    }
}
