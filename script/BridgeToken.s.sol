// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import {Script} from "forge-std/Script.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BridgeTokensScript is Script {
    function run(
        address receiverAddress,
        uint64 destinationChainSelector,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        address routerAddress
    ) public {
        vm.startBroadcast();
        // Core bridging logic will be added here
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: tokenToSendAddress,
            amount: amountToSend
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 100_00})
            )
        });
        uint256 ccipFee = IRouterClient(routerAddress).getFee(
            destinationChainSelector,
            message
        );
        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);

        vm.stopBroadcast();
    }
}
