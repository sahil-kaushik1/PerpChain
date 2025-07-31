// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

import {TokenPool} from "lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {Pool} from "lib/ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {IRebaseToken} from "src/IRebaseToken.sol";
import {IERC20} from "lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract RebaseTokenPool is TokenPool {
    constructor(
        IERC20 token,
        address[] memory allowlist,
        address rmnProxy,
        address router
    ) TokenPool(token, allowlist, rmnProxy, router) {}


function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnInV1) external override view returns (Pool.LockOrBurnOutV1 memory) {

    
        // This function is not implemented in the original code, so we will return an 
    _validateLockOrBurn(lockOrBurnInV1);
    uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(
            lockOrBurnInV1.originalSender
        );
    }
    IRebaseToken(address(i_token)).burn(
        address(this),
        lockOrBurnInV1.amount
    );
    lockOrBurnOut=Pool.LockOrBurnInV1({
        destTokenAddress:getRemoteTokenAddress(lockOrBurnInV1.remoteChainSelector),
        destPoolData:abi.encode((userInterestRate));
    })


    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata releaseOrMintInV1
    ) external override view returns (Pool.ReleaseOrMintOutV1 memory) {
        // This function is not implemented in the original code, so we will return an empty struct
        _validateReleaseOrMint(releaseOrMintInV1);
        address receiver = releaseOrMintInV1.receiver;
        (uint256 userInterestRate) = abi.decode(releaseOrMintInV1.sourcePoolData, (uint256));
        IRebaseToken(address(i_token)).mint(
            receiver,
            releaseOrMintInV1.amount
        ,userInterestRate);
        return Pool.ReleaseOrMintOutV1({
            destinationAmount: releaseOrMintInV1.amount
        });
    }
}