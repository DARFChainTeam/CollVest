//SPDX-License-Identifier: GPL

pragma solidity >=0.4.22 <0.9.0;
import "./DoubleSideVesting.sol";
import "./interfaces/IERC20.sol";
import "./libs/SafeMath.sol";
/// @title Typical DAIDO  vesting contract
/// @author @Stanta
/// @notice The team has issued tokens on TGE first time  and wants to sell them to a group of investors. Investors want to control the progress of the project. Thats why unlock for both sides goes step-by-step.

contract VestDAIDO is DoubleSideVesting {
    using SafeMath for uint256;

      
    function putVesting (address _token, address _recipient, uint256 _amount) public override  payable {
    /// @notice accepts vesting payments from both sides 
    /// @dev divides for native and ERC20 flows
    /// @param  _token - address of payment token,  "0x01" for native blockchain tokens 
    /// @param  _recipient - address of wallet, who can claim tokens
    /// @param  _amount - sum of vesting payment in wei 

    /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
    {   

        uint256 curVest =  vested[_token][_recipient] +_amount;
        
        if (curVest == _amount) vestors.push(_recipient);                      
        if (_token == vest.vest1.token1) {       
            if (vest.vest2.prevRound != address(ETHCODE) ) {
                require (VestDAIDO(vest.vest2.prevRound).status() >=CAPPED, "Didn't finished previous round"); 
            }            
            if (vest.vest1.maxBuy1 > 0) require(curVest <= vest.vest1.maxBuy1, "limit of vesting overquoted for this address" );
            if (vest.vest2.isNative){ // payments with native token                     
                require(_amount == msg.value, "amount must be equal to sent ether");
                if (vest.vest1.minBuy1 > 0)  require(msg.value >= vest.vest1.minBuy1, "amount must be greater minBuy");
            } else {
                if (vest.vest1.minBuy1 > 0) require(_amount >= vest.vest1.minBuy1, "amount must be greater minBuy");
                IERC20(_token).transferFrom(msg.sender, address(this), _amount);
            }
            raisedToken1 = raisedToken1.add( _amount);
            require(raisedToken1 <= vest.vest1.amount1, "Token1 capped");
        } else if (_token == vest.vest1.token2)  {
            raisedToken2 = raisedToken2.add( _amount);
            require(raisedToken2 <= vest.vest1.amount2, "Token2 capped");
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        }
         
        vested[_token][_recipient] = curVest;
        emit Vested(address(this), _token, _recipient, _amount);
    } 
    {
        if (vest.vest1.softCap1 >0 && //softCap case
            raisedToken1 >= vest.vest1.softCap1 &&             
            ((vest.vest2.isNative && address(this).balance >=  vest.vest1.softCap1) ||
            (!vest.vest2.isNative && IERC20(vest.vest1.token1).balanceOf(address(this)) >= vest.vest1.softCap1))
            ) {
                status = SOFTCAPPED;
                emit VestStatus(address(this),status);

            }
        

        if (raisedToken1 >= vest.vest1.amount1 && 
            raisedToken2 >= vest.vest1.amount2 &&
            ((vest.vest2.isNative && address(this).balance >=  vest.vest1.amount1) ||
            (!vest.vest2.isNative && IERC20(vest.vest1.token1).balanceOf(address(this)) >= vest.vest1.amount1)) &&
             IERC20(vest.vest1.token2).balanceOf(address(this)) >= vest.vest1.amount2
            ) {
                status = CAPPED;
                emit VestStatus(address(this),status);

            }
        
    }
        }
    
    function startSoftCapped (bool _start )  public {
        require(vested[vest.vest1.token1][msg.sender] > 0 || vested[vest.vest1.token2][msg.sender]>0 , "only vestor can start " );
        if (status >= SOFTCAPPED && _start ) status = STARTED;
        emit VestStatus(address(this),status);

    }

    function availableClaimToken1 () public view override returns (uint256 avAmount) {
        /// @notice calculates  available amount of token1 for claiming by team
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if ( isPaused() ||  status == ABORTED || status < CAPPED)  return 0;
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                uint256 inc = rules[i].amount1.mul(raisedToken1).div(vest.vest1.amount1);
                avAmount = avAmount.add(inc);
           }
        }
          avAmount =  avAmount.sub(withdrawed[vest.vest1.token1][vest.vest2.borrowerWallet]);        
    }


    function claimWithdrawToken1(uint256 _amount) public override nonReentrant  {
        /// @notice withdraw _amount of ERC20 or native tokens 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 desired amount of  claiming token , 

        require(!isPaused(), "Withdraw paused by participant");
        require(status != ABORTED , "Vesting aborted");
        require(status >= CAPPED,  "Vesting not capped");
//        require(msg.sender == vest.borrowerWallet, "just call from borrowerWallet"); //tbd is necessary or not?
       
        uint256 avAmount = availableClaimToken1();
        require(_amount <= avAmount, "No enough amount for withdraw");
        
        withdrawed[vest.vest1.token1][vest.vest2.borrowerWallet] =  withdrawed[vest.vest1.token1][vest.vest2.borrowerWallet].add(_amount);
        withdrawedToken1 = withdrawedToken1.add(_amount);
        if (vest.vest2.isNative) {
            payable(vest.vest2.borrowerWallet).transfer(_amount);
        }
        else { 
            IERC20(vest.vest1.token1).transfer(vest.vest2.borrowerWallet, _amount.sub( _amount.mul(fee).div(1000)));            
         }
        emit Claimed(address(this), vest.vest1.token1, msg.sender, _amount);
        if (raisedToken1 == withdrawedToken1 && raisedToken2 == withdrawedToken2) { 
            status = FINISHED;
            emit Finished (address(this));
        }
    }

    function availableClaimToken2 () public view override  returns (uint256 avAmount) {
        /// @notice calculates  available amount of token2 for claiming by vestors
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if ( isPaused() ||  status == ABORTED || status < CAPPED)  return 0;
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                uint256 inc = rules[i].amount2.mul(raisedToken2).div(vest.vest1.amount2);
                avAmount = avAmount.add(inc); 
                
           }
        }
            avAmount = avAmount.mul(vested[vest.vest1.token1][msg.sender]).div(raisedToken1);
            avAmount = avAmount.sub(withdrawed[vest.vest1.token2][msg.sender]);        
    } 

    function  claimWithdrawToken2 (uint256 _amount) public  override  { 
        /// @notice withdraw _amount of ERC20 or native tokens 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 desired amount of  claiming token , 

        require(!isPaused(), "Withdraw paused by participant");
        require(status != ABORTED , "Vesting aborted");
        require(status >= CAPPED,  "Vesting not capped");
       
        uint256 avAmount = availableClaimToken2();
        require(_amount <= avAmount, "No enough amount for withdraw");
        withdrawed[vest.vest1.token2][msg.sender] = withdrawed[vest.vest1.token2][msg.sender].add(_amount);
        withdrawedToken2 = withdrawedToken2.add(_amount);
        //TODO calculate fee in Token1 for pledger 
        uint256 feeSum = uint256(fee).mul(_amount).mul (vest.vest1.amount2).div(vest.vest1.amount1).div (1000);
        
        if (vest.vest2.isNative) {
            //todo if vesting made in native coins of chain - have some issues with inheritance of  claimWithdrawToken2 to charge as payable function - need solve
            // now using old-style of charging in vested token2
            IERC20(vest.vest1.token2).transfer( msg.sender, _amount.sub( _amount.mul(fee).div(1000)));           

        }
        else {
            IERC20(vest.vest1.token1).transferFrom( msg.sender, address(this), feeSum);
            IERC20(vest.vest1.token2).transfer( msg.sender, _amount);
        }
        
        emit Claimed(address(this), vest.vest1.token2, msg.sender, _amount);
        if (raisedToken1 == withdrawedToken1 && raisedToken2 == withdrawedToken2) { 
            status = FINISHED;
            emit Finished (address(this));
        }
        
    }
    
}
