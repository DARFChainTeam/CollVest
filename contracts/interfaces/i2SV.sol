// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "./i2SVstruct.sol";
/// @title interface describes typical vesting functions
/// @author stanta
/// @dev you have to derive vesting contract signatures from here
interface i2SV is i2SVstruct {
    
    function setVesting (    
        Vesting calldata _vest,
        Rule[] calldata _rules) external;

    function putVesting (address _token, address _recepient, uint256 _amount) external payable;

    function claimWithdrawToken1( uint256 _amount) external;
    function claimWithdrawToken2( uint256 _amount) external;
    
    function pauseWithdraw() external;

    function voteAbort(bool _vote) external;

}