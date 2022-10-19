pragma solidity >=0.4.22 <0.9.0;
import "./interfaces/i2SV.sol";
import "./interfaces/IERC20.sol";
import "./libs/SafeMath.sol";
/// @title Typical DAIDO vesting contract
/// @author The name of the author
/// @notice Explain to an end user what this does 
/// @dev Explain to a developer any extra details
contract VestDAIDO is i2SV {
    using SafeMath for uint256;


    Vesting vest;
    Rule[] rules; 
    
    mapping(address => mapping (address => uint256)) vested; //token => address of user
    mapping(address => mapping (address => uint256)) withdrawed; //token => address of user

    address constant ETHCODE = address(0x1);
    /// @notice setVesting sets parameters of vesting 
    function setVesting (
        Vesting calldata _vest,
        Rule[] calldata _rules
        ) public override { 
    
        require(_vest.isNative && _vest.token2 == ETHCODE, "Error in config native token");
        
        uint256 amount1;
        uint256 amount2;            
        for (uint8 i=0; i<_rules.length; i++) {
            amount1 += _rules[i].amount1;
            amount2 += _rules[i].amount2;            
            rules.push (_rules[i]); 
        }
        require(amount1 == _vest.amount1 && amount2 == _vest.amount2, "Error in vest schedule"  );
        vest = _vest;
        
        }
    
    
    function putVesting (address _token, address _recepient, uint256 _amount) public override  payable {
    /// @notice accepts vesting payments from both sides 
    /// @dev divides for native and ERC20 flows
    /// @param  _token - address of payment token,  "0x01" for native blockchain tokens 
    /// @param  _recepient - address of wallet, who can claim tokens
    /// @param  _amount - sum of vesting payment in wei 

    /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
    require(vest.isNative && _token == ETHCODE, "Error in config native token");
        if (vest.isNative) {
            // payments with native token        
            require(_amount == msg.value, "amount must be equal to sent ether");
            vested[_token][_recepient].tryAdd(_amount);
            vest.raisedToken2.tryAdd(_amount);
            require(vest.raisedToken1 <= vest.amount1, "Native token capped");
        } else {
            // payments with ERC20 token        
            require(vest.token1 == _token || vest.token2 == _token, "No this token in vestings" );
            vested[_token][_recepient].tryAdd(_amount);
            if (_token == vest.token1) {
                vest.raisedToken1.tryAdd( _amount);
                require(vest.raisedToken1 <= vest.amount1, "Token1 capped");
            } else  {
                vest.raisedToken2.tryAdd( _amount);
                require(vest.raisedToken2 <= vest.amount2, "Token2 capped");
            }
            IERC20(_token).transferFrom(_recepient, address(this), _amount);
            }
        }

     function availableClaim (address _token) public view returns (uint256 avAmount) {
        /// @notice calculates  available amount of _token for claiming 
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)

        require(vest.token1 == _token || vest.token2 == _token, "No this token in vestings" );
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                if (_token == vest.token1) {
                    avAmount.tryAdd(rules[i].amount1);
                } else  {
                    avAmount.tryAdd(rules[i].amount2);
                }   
            }
        }
        if (_token == vest.token1) {
                avAmount.mul(vested[_token][msg.sender]).div(vest.raisedToken1).sub(withdrawed[_token][msg.sender]);
            } else   {
                avAmount.mul(vested[_token][msg.sender]).div(vest.raisedToken2).sub(withdrawed[_token][msg.sender]);
         } 
     }

    function claimWithdraw(address _token, uint256 _amount) public override {
        /// @notice withdraw _amount of ERC20 or native tokens 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 desired amount of  claiming token , 
        
       if (vest.isNative)  _token = ETHCODE ;
        
       uint256 avAmount = availableClaim(_token);
       require(_amount <= avAmount, "No enough amount for withdraw");
       withdrawed[_token][msg.sender].tryAdd(_amount);
       if (vest.isNative) {
           payable(msg.sender).transfer(_amount);
       }
       else { 
            IERC20(_token).transferFrom( address(this), msg.sender, _amount);
        }
    }

  
    function stopWithdraw() public override {
        
    }

    function voteAbort(bool _vote) public override {
        
    }


}