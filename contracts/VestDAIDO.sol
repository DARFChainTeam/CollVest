pragma solidity >=0.4.22 <0.9.0;
import "./interfaces/i2SV.sol";
contract VestDAIDO is i2SV {

    function setVesting (
        Rule[] calldata _rules, 
        uint256 _amount, 
        address _tokenTeam, 
        address _tokenInvest, 
        address _teamWallet) public override {

        }
    function putVesting (uint256 _amount) public override  payable {
            
        }
    function claimWithdraw(uint256 _amount) public override {
            
        }

    function claimWithdrawEth(uint256 _amount) public override {
        
    }
    
    function stopWithdraw() public override {
        
    }

    function voteAbort(bool _vote) public override {
        
    }


}