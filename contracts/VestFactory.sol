pragma solidity >=0.4.22 <0.9.0;
import "./interfaces/i2SV.sol";

import "./VestDAIDO.sol";


contract VestFactory  is i2SVstruct {
        

    function deployVest( 
        bytes32 _typeContract, 
        Rule[] calldata _rules, 
        uint256 _amount, 
        address _tokenTeam,
        address _tokenInvest,
        address _teamWallet)   public {
            
        if (_typeContract == "DAIDO") {
            VestDAIDO vsd = new VestDAIDO();
            vsd.setVesting ( _rules, 
                 _amount, 
                _tokenTeam,
                _tokenInvest,
                _teamWallet);

        }
    }
}