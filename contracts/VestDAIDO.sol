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
    /// @notice setVesting sets parameters of vesting 
    function setVesting (
        Vesting calldata _vest,
        Rule[] calldata _rules
        ) public override { 
    
        require(_vest.isNative && _vest.token2 == address(0x1), "Error in config native token");
        vest = _vest;
            
        for (uint8 i=0; i<_rules.length; i++) {
            rules.push (_rules[i]);
        }
        
        }
    
    
    function putVesting (address _token, uint256 _amount) public override  payable {
    /// @notice accepts vesting payments from both sides 
    /// @dev divides for native and ERC20 flows
    /// @param  _token - address of payment token ,  _amount - sum of payment in wei

    /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
    require(vest.isNative && _token == address(0x1), "Error in config native token");
        if (vest.isNative) {
            // payments with native token        
            require(_amount == msg.value, "amount must be equal to sent ether");
            vested[_token][msg.sender].tryAdd(_amount);
            vest.raisedToken2.tryAdd(_amount);
            require(vest.raisedToken1 <= vest.amount1, "Native token capped");
        } else {
            // payments with ERC20 token        
            require(vest.token1 == _token || vest.token2 == _token, "No this token in vestings" );
            vested[_token][msg.sender].tryAdd(_amount);
            if (_token == vest.token1) {
                vest.raisedToken1.tryAdd( _amount);
                require(vest.raisedToken1 <= vest.amount1, "Token1 capped");
            } else if (_token == vest.token2)  {
                vest.raisedToken2.tryAdd( _amount);
                require(vest.raisedToken2 <= vest.amount2, "Token2 capped");
            }
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
            }
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