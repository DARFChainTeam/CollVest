// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "./i2SVstruct.sol";
/// @title interface describes typical vesting functions
/// @author stanta
/// @dev you have to derive vesting contract signatures from here
interface i2SV is i2SVstruct {
    function initialize (address _owner, address _treasure, uint8 fee ) external;    

    function changeVesting ( 
        Vesting calldata _vest,
        Rule[] calldata _rules) external;
        
    function setVesting ( 
        Vesting calldata _vest,
        Rule[] calldata _rules
        ) external; 
    function putVesting (address _token, address _recipient, uint256 _amount) external payable;

    function availableClaimToken1 () external view returns (uint256 avAmount);
    function availableClaimToken2 () external view returns (uint256 avAmount);

    function claimWithdrawToken1( uint256 _amount) external;
    function claimWithdrawToken2( uint256 _amount) external;
    
    function pauseWithdraw(string calldata _reason) external;
    function isPaused () external view returns (bool);
    function voteAbort(bool _vote) external;
    function refund () external ;
    function  withdraw2Treasury () external;

    function getVestedTok1 () external view returns (uint256);
    function getVestedTok2 () external view returns (uint256); 
    function getAllPauses () external view returns (  WithdrawPauses [] memory) ;
    


}