// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
interface i2SVstruct {
    /// @title interface describes structures in vesting
    /// @author stanta
    /// @dev nesting in VestDAIDO contract
    struct Rule {        
        uint256 amount1; //amount tokens of 1st side  that sends to  2nd side for this period,  f.e. amount of team's token for this period that sends to investors
        uint256 amount2; //amount tokens of 2st side  that sends to  1nd side for this period,  f.e  amount of invested  token  that sends to team
        uint256 claimTime; // block.timestamp marks end of vesting period
    }

    struct Withdrawpauses {
        address initiator; //who pauses withdrawing
        uint256 pauseTime; //time pauses withdrawing
    }

    struct Vesting {
        uint256 amount1; //total amount tokens of 1st side  that sends to  2nd side,  f.e. amount of team's token for this period that sends to investors
        uint256 amount2; // total amount tokens of 2st side  that sends to  1nd side,  f.e  amount of invested  token  that sends to team            
        address token1; //bought tokens
        address token2; //vested tokens,  if isNative ==true, must set to "0x1"
        uint256 raisedToken1; // sum raised in  token1
        uint256 raisedToken2;  // sum raised in  token2
/*         uint256 startDate; 
 */        uint256 pausePeriod; // period that withdrawing cab be pauseped until voting;
        uint8 vestShare4pauseWithdraw; //share in percents of raised,  needed to be vested to  pause (to avoid greenmailer' dust attacks)
        uint8 voteShareAbort; //share in percents of stakes needed to approve voting in this vesting
        bool isNative; // true if this vesting uses blockchain native token to vest, f.e. ETH in Ethereum mainnet
        uint8 status ; // (0- created, 10- capped , 20 - started, 100 - paused 200 - aborted, 255 - finished )
        address teamWallet; //        
        
    } 
}
