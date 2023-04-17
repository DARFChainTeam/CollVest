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

    struct WithdrawPauses {
        address initiator; //who pauses withdrawing
        uint256 pauseTime; //time pauses withdrawing
        string reason; 
    }
    struct Vesting{
        Vesting1 vest1;
        Vesting2 vest2;
        }
    struct Vesting1 {
        uint256 amount1; //total amount tokens of 1st side  that sends to  2nd side,  f.e. amount of team's token for this period that sends to investors
        uint256 amount2; // total amount tokens of 2st side  that sends to  1nd side,  f.e  amount of invested  token  that sends to team            
        uint256 softCap1; //total amount tokens of 1st side  that sends to  2nd side,  f.e. amount of team's token for this period that sends to investors
        uint256 minBuy1; //minimal sum of vesting in token1 per tranzaction
        uint256 maxBuy1; //maximum sum of vesting per address in token1
        address token1; //bought tokens
        address token2; //vested  ERC20 or ERC721 tokens,  if isNative ==true, must set to "0x1"
        bytes vestType; //type of vesting contract for factory
        }
    struct Vesting2 {
        address borrowerWallet; //                
        bool isNative; // true if this vesting uses blockchain native token to vest, f.e. ETH in Ethereum mainnet       
        address prevRound;
        uint256 capFinishTime; // time when cap will be achieved
        uint256 roundStartTime; // time when round starts
        bool nonWhitelisted;
        bool onlyVesting;
    } 

    event CreatedVesting ( address indexed, Vesting, Rule[]); //vesting contract, terms,  conditions
    event Vested(address indexed, address indexed, address indexed, uint256); // vesting contract, token, vestor, amount

    event Claimed(address indexed, address indexed, address indexed, uint256); // vesting contract, token, recipient, amount
    event VestStatus (address indexed,   uint8 indexed);// vesting contract, status
    event Voting (address, uint256); //// vesting contract, voted for abort
    event Refunded (address);
    event Finished (address);
}
