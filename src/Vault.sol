// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {

    // errors
    error Vault__RedeemFailed();

    // events
    event Deposited(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);

    IRebaseToken private immutable i_rebaseToken;

    constructor (address _rebaseToken) {
        i_rebaseToken = IRebaseToken(_rebaseToken);
    }

    receive() external payable {}


    function deposit() external payable {
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposited(msg.sender, msg.value);
    }


    /**
     * @dev redeems rebase token for the underlying asset
     * @param _amount the amount being redeemed
     *
     */

    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Deposited(msg.sender, _amount);
    }




    // External view functions
    function getRebaseTokenAddress() external view returns (address)  {
        return address(IRebaseToken(i_rebaseToken));
    }
}