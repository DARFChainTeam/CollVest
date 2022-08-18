// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
interface i2SVstruct {
    
    struct Rule {
        uint256 amountTeam;
        uint256 amountInvest;
        uint256 finishTime;
    }

    struct Vestors {
        address investor;
        uint256 amount;
    }

    struct Vesting {
        uint256 stopDate;
        address tokenTeam;
        address tokenInvest;
        uint8 voteShare;
        bool isNative;
        Rule[] rules;
        
    }
}
interface i2SV is i2SVstruct {
    

    function setVesting (Rule[] calldata _rules, uint256 _amount, address _tokenTeam, address _tokenInvest, address _teamWallet) external;

    function putVesting (uint256 _amount) external payable;

    function claimWithdraw(uint256 _amount) external;

    function claimWithdrawEth(uint256 _amount) external;
    
    function stopWithdraw() external;

    function voteAbort(bool _vote) external;

}