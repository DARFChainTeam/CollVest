/* eslint-disable no-undef */
const timeMachine = require('ganache-time-traveler');
const VestFactory = artifacts.require("VestFactory");
const VestContract = artifacts.require("VestCollateral");
const Token1 = artifacts.require("Token1");
const Token2 = artifacts.require("Token2");

const monthSecs = 365.25 /12 *60*60*24;
const periods = 3 
const ETHCODE =  web3.utils.toChecksumAddress ('0x0000000000000000000000000000000000000001');
/* const amount1 = 300; toBN
const amount2 = 1500; 

//const token2 = 0; //tbd in test
const pausePeriod =  monthSecs;
const vestShare4pauseWithdraw =5 ;
const voteShareAbort = 75;
const isNative = 1 ;
//const borrowerWallet = 0; //account [0];
 */

const now =  new Date().getTime() / 1000; //secs unix epoch

const vestRules = [{amount1: 100, amount2: 500, claimTime: Math.floor(now + monthSecs)},
                   {amount1: 100, amount2: 500, claimTime: Math.floor(now + monthSecs*2)},
                   {amount1: 100, amount2: 500, claimTime: Math.floor(now + monthSecs*3)}
                ];



contract('dSV 2side vesting contract both ERC20 tokens with collateral', (accounts) => {

const borrowerWallet  = accounts[9];

var vestContractAddr;
var  startVestConf;
let snapshot;
let snapshotId;

  it('Deploy test  2side vesting contract ', async () => {
    snapshot = await timeMachine.takeSnapshot();
    snapshotId = snapshot['result'];
    

    const dSVFact =  await  VestFactory.deployed();
    const t1 =  await Token1.deployed();
    const t2 =  await Token2.deployed();

    startVestConf = {
      vest1: {
        amount1:300,
        amount2:1500,
        softCap1:0,
        minBuy1:0,
        maxBuy1:0,
        token1: t1.address,
        token2: t2.address,
        vestType: web3.utils.asciiToHex('Collateral')
        },
    vest2: {      
        pausePeriod:monthSecs,
        borrowerWallet: borrowerWallet,
        vestShare4pauseWithdraw: 5,
        voteShareAbort:75, 
        isNative: false,
        prevRound:ETHCODE //noprevround
       }
    }
    
    const txDepl = await dSVFact.deployVest (
      vestRules,
      startVestConf
    );
    
    vestContractAddr = txDepl.logs[0].args[0];
    const eventConf  = txDepl.logs[0].args[1];
    const eventRules = txDepl.logs[0].args[2]

    assert.equal(eventRules[0].amount1,  vestRules[0].amount1, "vestRules");
    assert.equal(eventConf.vest1.amount2,  startVestConf.vest1.amount2, "vestConf");

    const vestContract = await VestContract.at(vestContractAddr);

    const vestConf = await vestContract.vest();
        
    assert.equal(vestConf.vest2.pausePeriod,  startVestConf.vest2.pausePeriod);

  });


  it('should send amount1 of token1 to  vesting contract', async () => {
    const t1 = await Token1.deployed();


    await t1.transfer(accounts[1], startVestConf.vest1.amount1 /3, {from:accounts[0]});
    await t1.transfer(accounts[2], startVestConf.vest1.amount1 /3, {from:accounts[0]});
    await t1.transfer(accounts[3], startVestConf.vest1.amount1 /3, {from:accounts[0]});
    
    await t1.approve(vestContractAddr, startVestConf.vest1.amount1 /3, {from:accounts[1]});
    await t1.approve(vestContractAddr, startVestConf.vest1.amount1 /3, {from:accounts[2]});
    await t1.approve(vestContractAddr, startVestConf.vest1.amount1 /3, {from:accounts[3]});

    const vestContract = await VestContract.at(vestContractAddr);

    await vestContract.putVesting(startVestConf.vest1.token1, accounts[1], startVestConf.vest1.amount1 /3, {from:accounts[1], value:startVestConf.vest1.amount1 /3} )
    await vestContract.putVesting(startVestConf.vest1.token1, accounts[2], startVestConf.vest1.amount1 /3, {from:accounts[2], value:startVestConf.vest1.amount1 /3} )
    await vestContract.putVesting(startVestConf.vest1.token1, accounts[3], startVestConf.vest1.amount1 /3, {from:accounts[3], value:startVestConf.vest1.amount1 /3} )


    const vested1 = await vestContract.getVestedTok1( {from: accounts[1]} ); 
    const vested2 = await vestContract.getVestedTok1( {from: accounts[2]} ); 
    const vested3 = await vestContract.getVestedTok1( {from: accounts[3]} ); 

    assert.equal(startVestConf.vest1.amount1/periods, vested1.toNumber(), "vested1");
    assert.equal(startVestConf.vest1.amount1/periods, vested2.toNumber(), "vested2");
    assert.equal(startVestConf.vest1.amount1/periods, vested3.toNumber(), "vested3");

  });

    

  it('should send amount2 of token2 to  vesting contract', async () => {
    // let snapshot = await timeMachine.takeSnapshot();
    // snapshotId = snapshot['result'];

    const t2 = await Token2.deployed();
  //  const balance = await t2.balanceOf(accounts[0])

    await t2.transfer(borrowerWallet, startVestConf.vest1.amount2);
    const balance = (await t2.balanceOf(borrowerWallet)).toNumber();
    assert.equal(balance, startVestConf.vest1.amount2, "didn't transfer startVestConf.vest1.amount2");


    const vestContract = await VestContract.at(vestContractAddr);
    const balanceT2_9= (await t2.balanceOf(accounts[9])).toNumber();;

    await t2.approve(vestContractAddr,startVestConf.vest1.amount2, {from:borrowerWallet});
    await vestContract.putVesting(t2.address, borrowerWallet, startVestConf.vest1.amount2 /2 , {from:borrowerWallet} )
    
    // const allowanceT2 =  ( await t2.allowance(accounts[0], vestContractAddr )).toNumber();
    await t2.approve(vestContractAddr,startVestConf.vest1.amount2, {from:accounts[0]});

    //TODO - strange bug, cant invest from acc[0]
    await vestContract.putVesting(t2.address, borrowerWallet, startVestConf.vest1.amount2/2, {from: accounts[0]});

    const vested9 = await vestContract.getVestedTok2( {from: borrowerWallet} ); 
    assert.equal(startVestConf.vest1.amount2, vested9/* [1] */.toNumber(), "vested9");


  });


  it('vesting funded', async () => {
    const vestContract = await VestContract.at(vestContractAddr);
    const t2 =  await Token2.deployed();

    const status2SV = await vestContract.status();
    const balt1_c =  await web3.eth.getBalance(vestContractAddr);
    const balt2_c = (await  t2.balanceOf(vestContractAddr)).toNumber();
    

    assert.equal(10, status2SV.toNumber(), "vested status");

  });

    

  it('withdraw t1 once all  amount by team', async () => {

    
    const vestContract = await VestContract.at(vestContractAddr);
    const t1 =  await Token1.deployed();

    const balt1before1 =  (await t1.balanceOf(borrowerWallet)).toNumber();
/*     var raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    var raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    var withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    var withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
 
    console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  ) */
    await vestContract.claimWithdrawToken1( startVestConf.vest1.amount1, {from:borrowerWallet} ) ;

/*     raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
 
    console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  ) */

    const balt1after1 =  (await t1.balanceOf(borrowerWallet)).toNumber();

    //assert.equal (balt1after1 - balt1before1,  av2claimt1, "balt1before1+ av2claimt1" );
    raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    refundToken1 = (await vestContract.refundToken1()).toNumber();
    withdrawedRefund1 = (await vestContract.withdrawedRefund1()).toNumber();

    withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
 
    console.log (raisedToken1, raisedToken2, refundToken1 ) 
    console.log (withdrawedToken1, withdrawedToken2,  withdrawedRefund1 ) 

    av2claimt1 = (await vestContract.status()).toNumber();

    assert.equal (av2claimt1, 15, "not in LOANWITHDRAWED ")

    });

    it('team`d to add  annuitet mayment to vesting contract', async () =>  {
      const t1 = await Token1.deployed();
  
  
      await t1.transfer(borrowerWallet, startVestConf.vest1.amount1 /3, {from:accounts[0]});
      
      await t1.approve(vestContractAddr, startVestConf.vest1.amount1 /3, {from:borrowerWallet});
        
      const vestContract = await VestContract.at(vestContractAddr);
  
      await vestContract.putVesting(startVestConf.vest1.token1, borrowerWallet, startVestConf.vest1.amount1 /3, {from:borrowerWallet} )
      
      raisedToken1 = (await vestContract.raisedToken1()).toNumber();
      raisedToken2 = (await vestContract.raisedToken2()).toNumber();
      withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
      withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
   
      console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  ) 
  
    });


  it('withdraw t1 or t2 once approved amount 1 period time', async () => {

    // time shift 
    var block = await web3.eth.getBlock("latest");
    const timeShift =  monthSecs; // openingTime - block.timestamp 
    await timeMachine.advanceTimeAndBlock(timeShift + 100);
    block = await web3.eth.getBlock("latest");
    assert (block.timestamp > new Date().getTime() / 1000 ,block.timestamp,  "time machine didn't works" )
    // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
   
    const vestContract = await VestContract.at(vestContractAddr);
    const t1 =  await Token1.deployed();
    const t2 =  await Token2.deployed();


    const balt1before1 =  (await  t1.balanceOf(accounts[1])).toNumber();
    const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
    let av2claimt2 =  (await vestContract.availableClaimToken2({from:accounts[1]})).toNumber();
    let av2claimt1 =  (await vestContract.availableClaimToken1({from:accounts[1]})).toNumber();

    var raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    var raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    var withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    var withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
    console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  )

    await vestContract.claimWithdrawToken2( 33, {from:accounts[1]} ) ;

    raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
 
    console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  )

 
    const balt1after1 = (await  t1.balanceOf(accounts[1])).toNumber();

    assert.equal (balt1after1 - balt1before1,  33, "balt1before1+ av2claimt1" );

    av2claimt2 = (await vestContract.availableClaimToken2()).toNumber();

     assert.equal (av2claimt2, 0, "not all claimed T2 ", av2claimt2)
  
    });

  it('withdraw t2 once approved amount 2nd period time', async () => {

    // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
      
    const vestContract = await VestContract.at(vestContractAddr);
    // const t1 =  await Token1.deployed();
    const t2 =  await Token2.deployed();


    const balt2before1 =  (await  t2.balanceOf(accounts[1])).toNumber();
    const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
    raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    refundToken1 = (await vestContract.refundToken1()).toNumber();
    withdrawedRefund1 = (await vestContract.withdrawedRefund1()).toNumber();

    withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
 
    console.log (raisedToken1, raisedToken2, refundToken1 ) 
    console.log (withdrawedToken1, withdrawedToken2,  withdrawedRefund1 ) 

    let av2claimt1 =  (await vestContract.availableClaimToken1({from:accounts[1]})).toNumber();

    let av2claimt2 =  (await vestContract.availableClaimToken2({from:accounts[1]})).toNumber();

    await vestContract.claimWithdrawToken2( av2claimt1, {from:accounts[1]} ) ;
    
    assert (withdrawedRefund1- (await vestContract.withdrawedRefund1()).toNumber(), 0, "withdrawedRefund1" );
    assert (withdrawedToken2- (await vestContract.withdrawedToken2()).toNumber(), 165, "withdrawedRefund1" );


    withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
 
    console.log (raisedToken1, raisedToken2, refundToken1 ) 
    console.log (withdrawedToken1, withdrawedToken2,  withdrawedRefund1 ) 

    const balt2after1 = (await  t2.balanceOf(accounts[1])).toNumber();

    });

  it('try to  refund not all investors withdrawed (NO) ', async () => {

    const vestContract = await VestContract.at(vestContractAddr);
    const t1 =  await Token1.deployed();
  


    const statusVest = (await vestContract.status()).toNumber();

    console.log ("statusVest:", statusVest)
  
    try {
      await vestContract.refund({from: borrowerWallet});
    }
    catch (e) {
      //// console.log(e)
      assert.equal(e.data.reason, "not finished yet, can't refund", "not finished yet, can't refund" )

    }

    });

  it('withdraw t2 once all from acc2', async () => {

      // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
        
      const vestContract = await VestContract.at(vestContractAddr);
      // const t1 =  await Token1.deployed();
      const t2 =  await Token2.deployed();
  
  
      const balt2before1 =  (await  t2.balanceOf(accounts[2])).toNumber();
      const vested1 = (await vestContract.getVestedTok1({from:accounts[2]})).toNumber();
      raisedToken1 = (await vestContract.raisedToken1()).toNumber();
      raisedToken2 = (await vestContract.raisedToken2()).toNumber();
      refundToken1 = (await vestContract.refundToken1()).toNumber();
      withdrawedRefund1 = (await vestContract.withdrawedRefund1()).toNumber();
  
      withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
      withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
    
      console.log (raisedToken1, raisedToken2, refundToken1 ) 
      console.log (withdrawedToken1, withdrawedToken2,  withdrawedRefund1 ) 
  
      let av2claimt1 =  (await vestContract.availableClaimToken1({from:accounts[2]})).toNumber();
  
      let av2claimt2 =  (await vestContract.availableClaimToken2({from:accounts[2]})).toNumber();
  
      await vestContract.claimWithdrawToken2( av2claimt1, {from:accounts[2]} ) ;
      
      assert (withdrawedRefund1- (await vestContract.withdrawedRefund1()).toNumber(), 0, "withdrawedRefund1" );
      assert (withdrawedToken2- (await vestContract.withdrawedToken2()).toNumber(), 165, "withdrawedRefund1" );
  
  
      withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
      withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
    
      console.log (raisedToken1, raisedToken2, refundToken1 ) 
      console.log (withdrawedToken1, withdrawedToken2,  withdrawedRefund1 ) 
  
      const balt2after1 = (await  t2.balanceOf(accounts[2])).toNumber();
  
      });
  it('withdraw t2 once all from acc3', async () => {

        // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
          
        const vestContract = await VestContract.at(vestContractAddr);
        // const t1 =  await Token1.deployed();
        const t2 =  await Token2.deployed();
    
    
        const balt2before1 =  (await  t2.balanceOf(accounts[3])).toNumber();
        const vested1 = (await vestContract.getVestedTok1({from:accounts[3]})).toNumber();
        raisedToken1 = (await vestContract.raisedToken1()).toNumber();
        raisedToken2 = (await vestContract.raisedToken2()).toNumber();
        refundToken1 = (await vestContract.refundToken1()).toNumber();
        withdrawedRefund1 = (await vestContract.withdrawedRefund1()).toNumber();
    
        withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
        withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
      
        console.log (raisedToken1, raisedToken2, refundToken1 ) 
        console.log (withdrawedToken1, withdrawedToken2,  withdrawedRefund1 ) 
    
        let av2claimt1 =  (await vestContract.availableClaimToken1({from:accounts[3]})).toNumber();
    
        let av2claimt2 =  (await vestContract.availableClaimToken2({from:accounts[3]})).toNumber();
    
        await vestContract.claimWithdrawToken2( av2claimt1, {from:accounts[3]} ) ;
        const withdrawedRefund1after =  (await vestContract.withdrawedRefund1()).toNumber()
        const withdrawedToken2after =  (await vestContract.withdrawedToken2()).toNumber()
        assert (withdrawedRefund1, withdrawedRefund1after, "withdrawedRefund1" );
        assert (withdrawedToken2- withdrawedToken2after, 165, "withdrawedRefund1" );
    
    
        withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
        withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
      
        console.log (raisedToken1, raisedToken2, refundToken1 ) 
        console.log (withdrawedToken1, withdrawedToken2,  withdrawedRefund1 ) 
    
        const balt2after1 = (await  t2.balanceOf(accounts[3])).toNumber();
    
        });

  it('try to  refund  all investors withdrawed () ', async () => {

      const vestContract = await VestContract.at(vestContractAddr);
      const t1 =  await Token1.deployed();
    
  
  

      const statusVest = (await vestContract.status()).toNumber();
  
      assert (statusVest, 255, "finished");
    
      let balt1contr =  (await t1.balanceOf(vestContractAddr)).toNumber();
      const balt1acc1 =  (await t1.balanceOf(borrowerWallet)).toNumber();
      // console.log("balt1contr,balt1acc1", balt1contr,balt1acc1)
  
      await vestContract.refund({from: borrowerWallet});
      const balt1accAft1 =  (await t1.balanceOf(borrowerWallet)).toNumber();

      balt1contr =  (await t1.balanceOf(vestContractAddr)).toNumber();
      const balt1acc2 =  (await t1.balanceOf(accounts[2])).toNumber();
      // console.log("balt1accAft1, balt1contr,balt1acc2, ", balt1accAft1, balt1contr,balt1acc2)

      });

  it('restoring chain ', async () => {
    await timeMachine.revertToSnapshot(snapshotId);
  })
   
    

});
