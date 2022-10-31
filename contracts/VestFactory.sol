pragma solidity >=0.4.22 <0.9.0;
import "./interfaces/i2SVstruct.sol";

import "./VestDAIDO.sol";


contract VestFactory  is i2SVstruct {
    event NewVesting(address, Rule[], Vesting);
    address constant ETHCODE = address(0x0000000000000000000000000000000000000001);

    function deployVest( 
        Rule[] calldata _rules,
        Vesting calldata _vestConf

        
        )   public  {
            /// @notice Explain to an end user what this does
            /// @dev Explain to a developer any extra details
            /// @param Documents a parameter just like in doxygen (must be followed by parameter name)
            /// @return Documents the return variables of a contract’s function state variable
            /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        Vesting memory vest = _vestConf;
        /* Vesting(
          { amount1: _amount1, //total amount tokens of 1st side  that sends to  2nd side,  f.e. amount of team's token for this period that sends to investors.  
          amount2:  _amount2, // total amount tokens of 2st side  that sends to  1nd side,  f.e  amount of invested  token  that sends to team            
          token1:  , //natibve token or address of ERC20 token contract  from vestors , if  isNative ==true, must set to "ETHCODE"
          token2:  , //address of ERC20 token contract vested (selling) tokens , 
           pausePeriod: 
          vestShare4pauseWithdraw: _vestShare4pauseWithdraw, // share in sale to vestor can pause withdraw 
          voteShareAbort: _voteShareAbort, //share of stakes needed to approve voting in this vesting
          isNative:_isNative, // true if this vesting uses blockchain native token to vest, f.e. ETH in Ethereum mainnet
          teamWallet:  address of team's wallet }); */
        //if (/* typeContract == "DAIDO" */true) {


            VestDAIDO vsd = new VestDAIDO();
            if (_vestConf.isNative ) vest.token1 = ETHCODE;
            vsd.setVesting (            
                vest,
                _rules);
    //    }
        
    }
}