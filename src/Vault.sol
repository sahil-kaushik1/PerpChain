pragma solidity ^0.8.26;

import {IRebaseToken} from "src/IRebaseToken.sol";

contract Vault {
    // we need to pass the token address to constructor
    // create a deposit function that mints token  to the user equal to the amount of ETH sent
    // create a redeem function that burns tokens fro the user and send the user Eth
    //  create a way to add rewards to the vault

    IRebaseToken private immutable i_rebaseToken;
    // address private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);

    event Redeem(address indexed user, uint256 amount);

    error Vault_RedeemFailed();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice allows users to deposit Eth into vault and mint rebase tokens in return
     */
    function deposit() external payable {
        // we need to use the amount of Eth user has sent to min tokens to the user
        i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        emit Deposit(msg.sender, msg.value);
    }

    /**
     *
     * @notice allows user to redeem their rebase tokens from eth
     * @param _amount of rebase tokens to redeem
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // emit Redeem(msg.sender, _amount);rere

        i_rebaseToken.burn(msg.sender, _amount);

        // payable(msg.sender).transfer(_amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");

        if (!success) {
            revert Vault_RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice returns address of rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
