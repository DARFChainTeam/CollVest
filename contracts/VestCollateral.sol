//SPDX-License-Identifier: GPL

pragma solidity >=0.4.22 <0.9.0;
import "./DoubleSideVesting.sol";
import "./interfaces/IERC20.sol";
import "./libs/SafeMath.sol";
// import "./libs/OwnableInit.sol";
/// @title Typical DAIDO vesting contract
/// @author The name of the author
/// @notice Explain to an end user what this does 
/// @dev Explain to a developer any extra details
contract VestCollateral is  DoubleSideVesting  {
    using SafeMath for uint256;

    uint256 public refundToken1;  // sum refunded token2 by borrower
    uint256 public withdrawedRefund1; // sum withdrawed by creditor 
    
    function putVesting (address _token, address _recepient, uint256 _amount) public override  payable {
    /// @notice accepts vesting payments from both sides 
    /// @dev divides for native and ERC20 flows
    /// @param  _token - address of payment token,  "0x01" for native blockchain tokens 
    /// @param  _recepient - address of wallet, who can claim tokens
    /// @param  _amount - sum of vesting payment in wei 

    /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
    {   

        (bool ok, uint256 curVest) =  vested[_token][_recepient].tryAdd(_amount);
        require(ok,  "curVest.tryAdd" );
        if (curVest == _amount) vestors.push(_recepient);                      
        if (_token == vest.vest1.token1) {       
            if (vest.vest1.maxBuy1 > 0) require(curVest <= vest.vest1.maxBuy1, "limit of vesting overquoted for this address" );
            if (vest.vest2.isNative){ // payments with native token                     
                require(_amount == msg.value, "amount must be equal to sent ether");
                if (vest.vest1.minBuy1 > 0)  require(msg.value >= vest.vest1.minBuy1, "amount must be greater minBuy");
            } else {
                if (vest.vest1.minBuy1 > 0) require(_amount >= vest.vest1.minBuy1, "amount must be greater minBuy");
                IERC20(_token).transferFrom(msg.sender, address(this), _amount/* .add( _amount.mul(fee).div(1000)) */);
            }
            if (status < CAPPED) { //msg.sender != vest.vest2.borrowerWallet
                
                raisedToken1 = raisedToken1.add( _amount);
                require(raisedToken1 <= vest.vest1.amount1, "Token1 capped");
                }
            else if (status >= LOANWITHDRAWED) {
                refundToken1 = refundToken1.add( _amount);
            }
        } else if (_token == vest.vest1.token2)  {
            raisedToken2 = raisedToken2.add( _amount);
            require(raisedToken2 <= vest.vest1.amount2, "Token2 capped");
            IERC20(_token).transferFrom(msg.sender, address(this), _amount/* .add( _amount.mul(fee).div(1000)) */);
        }
         
        vested[_token][_recepient] = curVest;
        emit Vested(address(this), _token, _recepient, _amount); 
    } 
    {


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

    function availableClaimToken1 () public view override returns (uint256 avAmount) {
        /// @notice calculates  available amount of token1 for claiming by team
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if ( status == ABORTED || status < LOANWITHDRAWED)  return 0;

        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                uint256 inc = rules[i].amount1.mul(refundToken1).div(vest.vest1.amount1);
                avAmount = avAmount.add(inc);
           }
        }
        avAmount = avAmount.sub(refundToken1).mul(vested[vest.vest1.token1][msg.sender]).div(raisedToken1);
        avAmount = avAmount.sub(withdrawed[vest.vest1.token1][msg.sender]);       
    }



    function claimWithdrawToken1(uint256 _amount) public override nonReentrant  { 
        /// @notice withdraw _amount of ERC20 or native tokens. In this version claimWithdrawToken1 uses by borrower to withdraw of loan body , for legacy reasons,  and all amount1 sum will withdrawed for one transaction.
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _amount - uint256 (not used here, saved for legacy ) desired amount of  claiming token , 

        require(msg.sender == vest.vest2.borrowerWallet, "just call from borrowerWallet"); //tbd is necessary or not?
        require(status < LOANWITHDRAWED,  "Loan already  withdrawed");

        uint256 avAmount = _amount;// availableClaimToken1();      
        withdrawed[vest.vest1.token1][vest.vest2.borrowerWallet] =  withdrawed[vest.vest1.token1][vest.vest2.borrowerWallet].add(_amount);
        withdrawedToken1 = withdrawedToken1.add(_amount);
        if (vest.vest2.isNative) {
            payable(vest.vest2.borrowerWallet).transfer(_amount.sub( _amount.mul(fee).div(1000)));
        }
        else { 
            IERC20(vest.vest1.token1).transfer(vest.vest2.borrowerWallet, _amount.sub( _amount.mul(fee).div(1000)));            
         }
                
        emit Claimed(address(this), vest.vest1.token1, msg.sender, _amount);
        if (raisedToken1 == withdrawedToken1) status = LOANWITHDRAWED;

    }
 

 /// @notice  

    function availableClaimToken2 () public view override returns (uint256 avAmount) {
        /// @notice calculates  available amount of token2 for claiming by vestors
        /// @dev in web3-like libs call with {from} key!
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @return uint256- available amount of _token for claiming 
        /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
        if ( status == ABORTED || status < LOANWITHDRAWED)  return 0;
        for (uint8 i=0; i<rules.length; i++) { 
            if (rules[i].claimTime <= block.timestamp){
                uint256 inc = rules[i].amount2.mul(raisedToken2).div(vest.vest1.amount2);
                avAmount = avAmount.add(inc); 
                
           }
        }
            avAmount = avAmount.sub(refundToken1).mul(vested[vest.vest1.token1][msg.sender]).div(raisedToken1); //todo check withdrawedRefund1 or  refundToken1
            avAmount = avAmount.sub(withdrawed[vest.vest1.token2][msg.sender]);        
    } 
    
    /// make integration
    function calcAmountandPenalty () public view returns (uint256 avAmount, uint256 penalty) {
        uint lastPaymentAmount;

        if ( status == ABORTED || status < LOANWITHDRAWED)  return (0, 0);
            for (uint8 i=0; i<rules.length; i++) { 
                if (rules[i].claimTime <= block.timestamp){                
                    avAmount = avAmount.add( rules[i].amount1); 
                    lastPaymentAmount = rules[i].amount1;
            }
            }
            avAmount = avAmount.sub(withdrawedRefund1);
            if (avAmount > lastPaymentAmount) {
                // penalty here
                penalty = vest.vest2.penalty; 
            }
    }
    function claimWithdrawToken2(uint256 _withdrAmount) public   nonReentrant override { 
        /// @notice withdraw _withdrAmount of ERC20 or native tokens.  In this version  uses for creditor's side, for legacy reasons, it try to withdraw to creditor token1 and, in amount is not enough - proportional sum of pledged token2 
        /// @param _token - address of claiming token , "0x01" for native blockchain tokens 
        /// @param _withdrAmount - uint256 desired amount of  claiming token , 

        // require(status >= LOANWITHDRAWED,  "Loan didn't withdrawed");
       
        // uint256 avAmount = availableClaimToken1();
        
        uint256 avAmount = availableClaimToken2();
        require(avAmount >= _withdrAmount, "Not enough amount for withdraw" );
        
        uint256 withdrAmount2 = _withdrAmount.mul(vest.vest1.amount2).div(vest.vest1.amount1);
        if (vest.vest2.isNative ) {
            if (address(this).balance >= _withdrAmount) {
                payable(msg.sender).transfer(_withdrAmount.sub( _withdrAmount.mul(fee).div(1000)));
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);

           } else {
                _withdrAmount = address(this).balance;
                payable(msg.sender).transfer(_withdrAmount.sub( _withdrAmount.mul(fee).div(1000)));
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);
                avAmount = _withdrAmount.mul(vest.vest1.amount2).div(vest.vest1.amount1);
                withdrAmount2 = _withdrAmount.sub(avAmount);
                //TODO calculate fee in Token1 for pledger 
                IERC20(vest.vest1.token2).transfer( msg.sender, withdrAmount2.sub( withdrAmount2.mul(fee).div(1000)));
                emit Claimed(address(this), vest.vest1.token2, msg.sender, withdrAmount2);

           }
        }
        else { 
            if ( IERC20(vest.vest1.token1 ).balanceOf(address(this)) >= _withdrAmount){ 
                IERC20(vest.vest1.token1).transfer(msg.sender, _withdrAmount.sub( _withdrAmount.mul(fee).div(1000)));            
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);


            } else {
                _withdrAmount =  IERC20(vest.vest1.token1 ).balanceOf(address(this));
                IERC20(vest.vest1.token1).transfer(msg.sender, _withdrAmount.sub( _withdrAmount.mul(fee).div(1000)));            
                emit Claimed(address(this), vest.vest1.token1, msg.sender, _withdrAmount);
                avAmount = _withdrAmount.mul(vest.vest1.amount2).div(vest.vest1.amount1);
                withdrAmount2 = withdrAmount2.sub(avAmount);
                IERC20(vest.vest1.token2).transfer( msg.sender, withdrAmount2.sub( withdrAmount2.mul(fee).div(1000)));
                emit Claimed(address(this), vest.vest1.token2, msg.sender, withdrAmount2);



            }
        }

        withdrawed[vest.vest1.token1][msg.sender] = withdrawed[vest.vest1.token1][msg.sender].add(_withdrAmount);
        withdrawedRefund1 = withdrawedRefund1.add(_withdrAmount);
        withdrawed[vest.vest1.token2][msg.sender] = withdrawed[vest.vest1.token2][msg.sender].add(withdrAmount2);
        withdrawedToken2 = withdrawedToken2.add(withdrAmount2);

        if (raisedToken1 <= refundToken1 || raisedToken1 <= refundToken1.add(  withdrawedToken2.mul(vest.vest1.amount1).div(vest.vest1.amount2)) ) { 
            status = FINISHED;
            emit Finished (address(this));
        }
        
    }
    

    function pauseWithdraw(string calldata _reason) public override  {
        revert ("not used here ");
      
    } 
    

    function voteAbort(bool _vote) public override {
 
        revert ("not used here "); //TBD
    }

    function refund () public override {
        require(status == FINISHED , "not finished yet, can't refund" );

        //refund token2 
        uint256 avAmount2;
        if (vested[vest.vest1.token2][msg.sender] > 0) { 
            avAmount2 = raisedToken2 - withdrawedToken2; //IERC20(vest.vest1.token2).balanceOf(address(this));
            avAmount2 = avAmount2.mul(vested[vest.vest1.token2][msg.sender]).div(vest.vest1.amount2);
            IERC20(vest.vest1.token2).transfer( msg.sender, avAmount2);
        } else {
            revert ("no token2 invested from this address");
        }
    }

   
}
