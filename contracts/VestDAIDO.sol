//SPDX-License-Identifier: GPL

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

    //    Statuses:     0-created, 10- capped , 20 - started, 100 - paused 200 - aborted, 255 - finished

    uint8 constant CREATED = 0;
    uint8 constant CAPPED = 10;
    uint8 constant STARTED = 20;
    uint8 constant PAUSED = 100;
    uint8 constant ABORTED = 200;
    uint8 constant FINISHED = 255;


    Vesting public vest;
    uint16 public votesForAbort;
    Rule[] public rules; 
    Withdrawpauses[] public pauses;
    address[] public vestors;
    

    mapping(address => mapping (address => uint256)) public vested; //token => address of user
    mapping(address => mapping (address => uint256)) public withdrawed; //token => address of user

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
            if (vest.raisedToken1 >= vest.amount1 && vest.raisedToken2 >= vest.amount2  ) vest.status = CAPPED;
            IERC20(_token).transferFrom(_recepient, address(this), _amount);
            vestors.push(msg.sender);
            }
        }

    function isPaused () public view returns (bool) {
        for (uint8 i=0; i<pauses.length; i++){            
            if (block.timestamp > pauses[i].pauseTime+vest.pausePeriod) return true;
        }
        return false;
    }

    function availableClaimToken1 () public view returns (uint256 avAmount) {
        /// @notice calculates  available amount of token1 for claiming by team
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if (!isPaused() || vest.status == ABORTED || vest.status < CAPPED)  return 0;
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                avAmount.tryAdd(rules[i].amount1); 
           }
        }
            avAmount.sub(withdrawed[vest.token1][vest.teamWallet]);        
    }


    function claimWithdrawToken1(uint256 _amount) public  {
        /// @notice withdraw _amount of ERC20 or native tokens 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 desired amount of  claiming token , 

        require(!isPaused(), "Withdraw paused by participant");
        require(vest.status != ABORTED , "Vesting aborted");
        require(vest.status >= CAPPED,  "Vesting not capped");
       
        uint256 avAmount = availableClaimToken1();
        require(_amount <= avAmount, "No enough amount for withdraw");
        withdrawed[vest.token1][vest.teamWallet].tryAdd(_amount);
       
        if (vest.isNative) {
            payable(vest.teamWallet).transfer(_amount);
        }
        else { 
            IERC20(vest.token1).transferFrom( address(this), vest.teamWallet, _amount);
         }
    }

    function availableClaimToken2 () public view returns (uint256 avAmount) {
        /// @notice calculates  available amount of token2 for claiming by vestors
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if (!isPaused() || vest.status == ABORTED || vest.status < CAPPED )  return 0;
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                avAmount.tryAdd(rules[i].amount2); 
           }
        }
            avAmount.mul(vested[vest.token1][msg.sender]).div(vest.raisedToken1);
            avAmount.sub(withdrawed[vest.token2][msg.sender]);        
    } 

    function claimWithdrawToken2(uint256 _amount) public override { 
        /// @notice withdraw _amount of ERC20 or native tokens 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 desired amount of  claiming token , 

        require(!isPaused(), "Withdraw paused by participant");
        require(vest.status != ABORTED , "Vesting aborted");
        require(vest.status >= CAPPED,  "Vesting not capped");
       
        uint256 avAmount = availableClaimToken1();
        require(_amount <= avAmount, "No enough amount for withdraw");
        withdrawed[vest.token2][msg.sender].tryAdd(_amount);

        IERC20(vest.token2).transferFrom( address(this), msg.sender, _amount);
    }
    

  
    function pauseWithdraw() public override {
        require(vested[vest.token1][msg.sender] > vest.vestShare4pauseWithdraw * vest.raisedToken1 /100 ||
                vested[vest.token2][msg.sender] > vest.vestShare4pauseWithdraw * vest.raisedToken1 /100, 
                "Didn't vested enough to pause work"
                );
        pauses.push(Withdrawpauses(msg.sender, block.timestamp));
        
    }
    

    function voteAbort(bool _vote) public override {
        if (_vote && isPaused())  {
            votesForAbort+=1;
            if (votesForAbort > vestors.length * vest.voteShareAbort / 100) {
                vest.status = ABORTED ;
            }
        } else if (!isPaused()) {
            votesForAbort =0;
        }
        
    }

    function refund () public {
        require(vest.status == ABORTED , "Vesting works normally, can't refund" );
        uint256 avAmount;
        //refund token1
        if (vested[vest.token1][msg.sender] > 0) { 
            if (vest.isNative) {
                // checking balance of ether
                avAmount = address(this).balance;
                avAmount.mul(vested[vest.token1][msg.sender]).div(vest.amount1);
                payable(msg.sender).transfer(avAmount);
            }
            else { 
                // checking balance of ERc20 token
                avAmount = IERC20(vest.token1).balanceOf(address(this));                
                avAmount.mul(vested[vest.token1][msg.sender]).div(vest.amount1);
                IERC20(vest.token1).transferFrom( address(this), msg.sender, avAmount);
            }
        }
        //refund token2 
        if (vested[vest.token2][msg.sender] > 0) { 
            avAmount = IERC20(vest.token2).balanceOf(address(this));
            avAmount.mul(vested[vest.token2][msg.sender]).div(vest.amount2);
            IERC20(vest.token2).transferFrom( address(this), msg.sender, avAmount);
        }
    }
}
