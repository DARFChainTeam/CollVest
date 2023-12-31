/* eslint-disable no-undef */
const timeMachine = require('ganache-time-traveler');
const VestFactory = artifacts.require("VestFactory");
const VestContract = artifacts.require("VestDAIDO");
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

const vestRules2 = [{amount1: 100, amount2: 500, claimTime: Math.floor(now + monthSecs*4)},
                  {amount1: 100, amount2: 500, claimTime: Math.floor(now + monthSecs*5)},
                  {amount1: 100, amount2: 500, claimTime: Math.floor(now + monthSecs*6)}
               ];


contract('dSV 2side vesting contract both ERC20 tokens', (accounts) => {

const borrowerWallet  = accounts[9];

var vestContractAddr;
var vestContractAddr2;
var  startVestConf;
let snapshot;
let snapshotId;

  it('Deploy test  2side vesting contract round 1 ', async () => {
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
        token2Id: 0, 
        vestType: web3.utils.asciiToHex("DAIDO")        
        },
    vest2: {      
        pausePeriod:monthSecs,
        borrowerWallet: borrowerWallet,
        vestShare4pauseWithdraw: 5,
        voteShareAbort:75, 
        isNative: false,
        prevRound:ETHCODE ,//noprevround
        penalty: 0,
        penaltyPeriod: 0,
        capFinishTime: 0

       }
        }

    await t2.transfer(borrowerWallet, startVestConf.vest1.amount2);
        const balance = (await t2.balanceOf(borrowerWallet)).toNumber();
        assert.equal(balance, startVestConf.vest1.amount2, "didn't transfer startVestConf.vest1.amount2");
    
    
        const balanceT2_9= (await t2.balanceOf(accounts[9])).toNumber();;
    
        await t2.approve(dSVFact.address,startVestConf.vest1.amount2, {from:borrowerWallet});
    
        const txDepl = await dSVFact.deployVest (
          t2.address, 
          borrowerWallet,
          startVestConf.vest1.amount2,
          vestRules,
          startVestConf,
          {from:borrowerWallet}
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
  it('Deploy test  2side vesting contract round 2 ', async () => {
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
        token2: t2.address ,
        token2Id: 0, 
        vestType: web3.utils.asciiToHex("DAIDO")        
        },
    vest2: {      
        pausePeriod:monthSecs,
        borrowerWallet: borrowerWallet,
        vestShare4pauseWithdraw: 5,
        voteShareAbort:75, 
        isNative: false,
        prevRound:vestContractAddr,
        penalty: 0,
        penaltyPeriod: 0,              
        capFinishTime: 0

       }
        }

   
        await t2.transfer(borrowerWallet, startVestConf.vest1.amount2);
        const balance = (await t2.balanceOf(borrowerWallet)).toNumber();
        assert.equal(balance, startVestConf.vest1.amount2, "didn't transfer startVestConf.vest1.amount2");
    
    
        const balanceT2_9= (await t2.balanceOf(accounts[9])).toNumber();;
    
        await t2.approve(dSVFact.address,startVestConf.vest1.amount2, {from:borrowerWallet});
    
        const txDepl = await dSVFact.deployVest (
          t2.address, 
          borrowerWallet,
          startVestConf.vest1.amount2,
          vestRules,
          startVestConf,
          {from:borrowerWallet}
        );
        
            
    vestContractAddr2 = txDepl.logs[0].args[0];
    const eventConf  = txDepl.logs[0].args[1];
    const eventRules = txDepl.logs[0].args[2]

    assert.equal(eventRules[0].amount1,  vestRules2[0].amount1, "vestRules");
    assert.equal(eventConf.vest1.amount2,  startVestConf.vest1.amount2, "vestConf");

    const vestContract = await VestContract.at(vestContractAddr2);

    const vestConf = await vestContract.vest();
        
    assert.equal(vestConf.vest2.prevRound, vestContractAddr, "wrong prev round");

  });



  it(' try to  send amount1 of token1 to  vesting contract 2 (not)', async () => {
    const t1 = await Token1.deployed();


    await t1.transfer(accounts[1], startVestConf.vest1.amount1 /3, {from:accounts[0]});

    await t1.approve(vestContractAddr2, startVestConf.vest1.amount1 /3, {from:accounts[1]});

    const vestContract = await VestContract.at(vestContractAddr2);

    try {
      await vestContract.putVesting(startVestConf.vest1.token1, accounts[1], startVestConf.vest1.amount1 /3, {from:accounts[1]} )

    } catch (e) {
      //// console.log(e)
      assert.equal(e.data.reason, "Didn't finished previous round", "Didn't finished previous round" );
    }

  });


   it('should send amount1 of token1 to  vesting contract 1', async () => {
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



  it('vesting funded', async () => {
    const vestContract = await VestContract.at(vestContractAddr);
    const t2 =  await Token2.deployed();

    const status2SV = await vestContract.status();
    const balt1_c =  await web3.eth.getBalance(vestContractAddr);
    const balt2_c = (await  t2.balanceOf(vestContractAddr)).toNumber();
    

    assert.equal(10, status2SV.toNumber(), "vested status");

  });

  it('withdraw t1 once approved amount 1period time', async () => {

     // time shift 
    var block = await web3.eth.getBlock("latest");
    const timeShift =  monthSecs; // openingTime - block.timestamp 
    await timeMachine.advanceTimeAndBlock(timeShift + 100);
    block = await web3.eth.getBlock("latest");
    assert (block.timestamp > new Date().getTime() / 1000 ,block.timestamp,  "time machine didn't works" )
    // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )

    const vestContract = await VestContract.at(vestContractAddr);
    const t1 =  await Token1.deployed();

    const balt1before1 =  (await t1.balanceOf(borrowerWallet)).toNumber();
    
    let av2claimt1 =  (await vestContract.availableClaimToken1()).toNumber();
    assert.equal (av2claimt1, startVestConf.vest1.amount1 /3, "amount t1 1st month ")

    await vestContract.claimWithdrawToken1( av2claimt1 ) ;
    
    const balt1after1 =  (await t1.balanceOf(borrowerWallet)).toNumber();

    assert.equal (balt1after1 - balt1before1,  av2claimt1, "balt1before1+ av2claimt1" );

    av2claimt1 = (await vestContract.availableClaimToken1()).toNumber();

    assert.equal (av2claimt1, 0, "not all claimed ")
    const raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    const raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    const withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    const withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();

    // console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  )



    });
  it('withdraw t2 once approved amount 1 period time', async () => {

    // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
      
    const vestContract = await VestContract.at(vestContractAddr);
    //const t1 =  await Token1.deployed();
    const t2 =  await Token2.deployed();


    const balt2before1 =  (await  t2.balanceOf(accounts[1])).toNumber();
    const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
    let av2claimt2 =  (await vestContract.availableClaimToken2({from:accounts[1]})).toNumber();

    await vestContract.claimWithdrawToken2( av2claimt2, {from:accounts[1]} ) ;

    assert.equal (av2claimt2, Math.floor(startVestConf.vest1.amount2 /periods * vested1 / startVestConf.vest1.amount1), "amount t2 1st month ")

    const balt2after1 = (await  t2.balanceOf(accounts[1])).toNumber();

    assert.equal (balt2after1 - balt2before1,  av2claimt2, "balt1before1+ av2claimt1" );

    av2claimt2 = (await vestContract.availableClaimToken2()).toNumber();

    assert.equal (av2claimt2, 0, "not all claimed T2")
    const raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    const raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    const withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    const withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();

    // console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  )


  
    });

  it('withdraw t1 once approved amount 2nd period time', async () => {

    // time shift 
    var block = await web3.eth.getBlock("latest");
    const timeShift =  monthSecs; // openingTime - block.timestamp 
    await timeMachine.advanceTimeAndBlock(timeShift + 100);
    block = await web3.eth.getBlock("latest");
    assert (block.timestamp > new Date().getTime() / 1000 ,block.timestamp,  "time machine didn't works" )
    // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )

    const vestContract = await VestContract.at(vestContractAddr);
    const t1 =  await Token1.deployed();

    const balt1before1 =  (await t1.balanceOf(borrowerWallet)).toNumber();
    
    let av2claimt1 =  (await vestContract.availableClaimToken1()).toNumber();
    assert.equal (av2claimt1, startVestConf.vest1.amount1 /3, "amount t1 2nd month ")

    await vestContract.claimWithdrawToken1( av2claimt1 ) ;
    
    const balt1after1 =  (await t1.balanceOf(borrowerWallet)).toNumber();

    assert.equal (balt1after1 - balt1before1,  av2claimt1, "balt1before1+ av2claimt1" );

    av2claimt1 = (await vestContract.availableClaimToken1()).toNumber();

    assert.equal (av2claimt1, 0, "not all claimed ")
    const raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    const raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    const withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    const withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();

    // console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  )


    });
  it('withdraw t2 once approved amount 2nd period time', async () => {

    // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
      
    const vestContract = await VestContract.at(vestContractAddr);
    // const t1 =  await Token1.deployed();
    const t2 =  await Token2.deployed();


    const balt2before1 =  (await  t2.balanceOf(accounts[1])).toNumber();
    const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
    let av2claimt2 =  (await vestContract.availableClaimToken2({from:accounts[1]})).toNumber();


    await vestContract.claimWithdrawToken2( av2claimt2, {from:accounts[1]} ) ;
    const balt2after1 = (await  t2.balanceOf(accounts[1])).toNumber();


    assert.equal (av2claimt2, Math.round(startVestConf.vest1.amount2 /periods * vested1 / startVestConf.vest1.amount1), "amount t2 1st month ")
    assert.equal (balt2after1 - balt2before1,  av2claimt2, "balt1before1+ av2claimt1" );

    av2claimt2 = (await vestContract.availableClaimToken2()).toNumber();

    assert.equal (av2claimt2, 0, "not all claimed T2")
    const raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    const raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    const withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    const withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();

    // console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  )


    });
  it('withdraw t1 once approved amount 3d period time', async () => {

    // time shift 
    var block = await web3.eth.getBlock("latest");
    const timeShift =  monthSecs; // openingTime - block.timestamp 
    await timeMachine.advanceTimeAndBlock(timeShift + 100);
    block = await web3.eth.getBlock("latest");
    assert (block.timestamp > new Date().getTime() / 1000 ,block.timestamp,  "time machine didn't works" )
    // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )

    const vestContract = await VestContract.at(vestContractAddr);
    const t1 =  await Token1.deployed();

    const balt1before1 =  (await t1.balanceOf(borrowerWallet)).toNumber();
    
    let av2claimt1 =  (await vestContract.availableClaimToken1()).toNumber();
    assert.equal (av2claimt1, startVestConf.vest1.amount1 /3, "amount t1 3d month ")

    await vestContract.claimWithdrawToken1( av2claimt1 ) ;
    
    const balt1after1 =  (await t1.balanceOf(borrowerWallet)).toNumber();

    assert.equal (balt1after1 - balt1before1,  av2claimt1, "balt1before1+ av2claimt1" );

    av2claimt1 = (await vestContract.availableClaimToken1()).toNumber();

    assert.equal (av2claimt1, 0, "not all claimed ")
    const raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    const raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    const withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    const withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();

    // console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  )


    });
  it('withdraw t2 once approved amount 3d  period time', async () => {

    // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
    
    const vestContract = await VestContract.at(vestContractAddr);
  // const t1 =  await Token1.deployed();
     const t2 =  await Token2.deployed();


    const balt2before1 =  (await  t2.balanceOf(accounts[1])).toNumber();
    const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
    let av2claimt2 =  (await vestContract.availableClaimToken2({from:accounts[1]})).toNumber();

    
    await vestContract.claimWithdrawToken2( av2claimt2, {from:accounts[1]} ) ;
    const balt2after1 = (await  t2.balanceOf(accounts[1])).toNumber();

    assert.equal (balt2after1 - balt2before1,  av2claimt2, "balt1before1+ av2claimt1" );
    assert.equal (av2claimt2, Math.round(startVestConf.vest1.amount2 /periods * vested1 / startVestConf.vest1.amount1), "amount t2 1st month ")

    av2claimt2 = (await vestContract.availableClaimToken2()).toNumber();

    assert.equal (av2claimt2, 0, "not all claimed T2")

    const raisedToken1 = (await vestContract.raisedToken1()).toNumber();
    const raisedToken2 = (await vestContract.raisedToken2()).toNumber();
    const withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
    const withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();

    // console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  )

    });


    it('should send amount1 of token1 to  vesting contract 2', async () => {
      const t1 = await Token1.deployed();
  
  
      await t1.transfer(accounts[1], startVestConf.vest1.amount1 /3, {from:accounts[0]});
      await t1.transfer(accounts[2], startVestConf.vest1.amount1 /3, {from:accounts[0]});
      await t1.transfer(accounts[3], startVestConf.vest1.amount1 /3, {from:accounts[0]});
      
      await t1.approve(vestContractAddr2, startVestConf.vest1.amount1 /3, {from:accounts[1]});
      await t1.approve(vestContractAddr2, startVestConf.vest1.amount1 /3, {from:accounts[2]});
      await t1.approve(vestContractAddr2, startVestConf.vest1.amount1 /3, {from:accounts[3]});
  
      const vestContract = await VestContract.at(vestContractAddr2);
  
      await vestContract.putVesting(startVestConf.vest1.token1, accounts[1], startVestConf.vest1.amount1 /3, {from:accounts[1]} )
      await vestContract.putVesting(startVestConf.vest1.token1, accounts[2], startVestConf.vest1.amount1 /3, {from:accounts[2]})
      await vestContract.putVesting(startVestConf.vest1.token1, accounts[3], startVestConf.vest1.amount1 /3, {from:accounts[3]} )
    
      const vested1 = await vestContract.getVestedTok1( {from: accounts[1]} ); 
      const vested2 = await vestContract.getVestedTok1( {from: accounts[2]} ); 
      const vested3 = await vestContract.getVestedTok1( {from: accounts[3]} ); 
  
      assert.equal(startVestConf.vest1.amount1/periods, vested1.toNumber(), "vested1");
      assert.equal(startVestConf.vest1.amount1/periods, vested2.toNumber(), "vested2");
      assert.equal(startVestConf.vest1.amount1/periods, vested3.toNumber(), "vested3");
  
    });
  
      
  

  
  
    it('vesting funded 2', async () => {
      const vestContract = await VestContract.at(vestContractAddr2);
      const t2 =  await Token2.deployed();
  
      const status2SV = await vestContract.status();
      const balt1_c =  await web3.eth.getBalance(vestContractAddr2);
      const balt2_c = (await  t2.balanceOf(vestContractAddr2)).toNumber();
      const raisedToken1 = (await vestContract.raisedToken1()).toNumber();
      const raisedToken2 = (await vestContract.raisedToken2()).toNumber();
      const withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
      const withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();
  
      // console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  )
  
  
      assert.equal(10, status2SV.toNumber(), "vested status");
  
    });


  it('withdraw t1 once approved amount 1period time vest2', async () => {

    // time shift 
   var block = await web3.eth.getBlock("latest");
   const timeShift =  monthSecs; // openingTime - block.timestamp 
   await timeMachine.advanceTimeAndBlock(timeShift + 100);
   block = await web3.eth.getBlock("latest");
   assert (block.timestamp > new Date().getTime() / 1000 ,block.timestamp,  "time machine didn't works" )
   // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )

   const vestContract = await VestContract.at(vestContractAddr2);
   const t1 =  await Token1.deployed();

   const balt1before1 =  (await t1.balanceOf(borrowerWallet)).toNumber();
   
   let av2claimt1 =  (await vestContract.availableClaimToken1()).toNumber();
   
   await vestContract.claimWithdrawToken1( av2claimt1 ) ;

   const raisedToken1 = (await vestContract.raisedToken1()).toNumber();
   const raisedToken2 = (await vestContract.raisedToken2()).toNumber();
   const withdrawedToken1 = (await vestContract.withdrawedToken1()).toNumber();
   const withdrawedToken2 = (await vestContract.withdrawedToken2()).toNumber();

   // console.log (raisedToken1, raisedToken2,withdrawedToken1, withdrawedToken2  )

   assert.equal (av2claimt1, startVestConf.vest1.amount1  /3, "amount t1 1st month ")

   
   const balt1after1 =  (await t1.balanceOf(borrowerWallet)).toNumber();

   assert.equal (balt1after1 - balt1before1,  av2claimt1, "balt1before1+ av2claimt1" );

   av2claimt1 = (await vestContract.availableClaimToken1()).toNumber();

   assert.equal (av2claimt1, 0, "not all claimed ")

   });
 it('withdraw t2 once approved amount 1 period time', async () => {

   // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
     
   const vestContract = await VestContract.at(vestContractAddr2);
   //const t1 =  await Token1.deployed();
   const t2 =  await Token2.deployed();


   const balt2before1 =  (await  t2.balanceOf(accounts[1])).toNumber();
   const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
   let av2claimt2 =  (await vestContract.availableClaimToken2({from:accounts[1]})).toNumber();

   await vestContract.claimWithdrawToken2( av2claimt2, {from:accounts[1]} ) ;

   assert.equal (av2claimt2, Math.floor(startVestConf.vest1.amount2 /periods * vested1 / startVestConf.vest1.amount1), "amount t2 1st month ")

   const balt2after1 = (await  t2.balanceOf(accounts[1])).toNumber();

   assert.equal (balt2after1 - balt2before1,  av2claimt2, "balt1before1+ av2claimt1" );

   av2claimt2 = (await vestContract.availableClaimToken2()).toNumber();

   assert.equal (av2claimt2, 0, "not all claimed T2")
 
   });

 it('withdraw t1 once approved amount 2nd period time vest2', async () => {

   // time shift 
   var block = await web3.eth.getBlock("latest");
   const timeShift =  monthSecs; // openingTime - block.timestamp 
   await timeMachine.advanceTimeAndBlock(timeShift + 100);
   block = await web3.eth.getBlock("latest");
   assert (block.timestamp > new Date().getTime() / 1000 ,block.timestamp,  "time machine didn't works" )
   // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )

   const vestContract = await VestContract.at(vestContractAddr2);
   const t1 =  await Token1.deployed();

   const balt1before1 =  (await t1.balanceOf(borrowerWallet)).toNumber();
   
   let av2claimt1 =  (await vestContract.availableClaimToken1()).toNumber();
   assert.equal (av2claimt1, startVestConf.vest1.amount1 /3, "amount t1 2nd month ")

   await vestContract.claimWithdrawToken1( av2claimt1 ) ;
   
   const balt1after1 =  (await t1.balanceOf(borrowerWallet)).toNumber();

   assert.equal (balt1after1 - balt1before1,  av2claimt1, "balt1before1+ av2claimt1" );

   av2claimt1 = (await vestContract.availableClaimToken1()).toNumber();

   assert.equal (av2claimt1, 0, "not all claimed ")

   });
 it('withdraw t2 once approved amount 2nd period time vest2', async () => {

   // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
     
   const vestContract = await VestContract.at(vestContractAddr2);
   // const t1 =  await Token1.deployed();
   const t2 =  await Token2.deployed();


   const balt2before1 =  (await  t2.balanceOf(accounts[1])).toNumber();
   const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
   let av2claimt2 =  (await vestContract.availableClaimToken2({from:accounts[1]})).toNumber();


   await vestContract.claimWithdrawToken2( av2claimt2, {from:accounts[1]} ) ;
   const balt2after1 = (await  t2.balanceOf(accounts[1])).toNumber();


   assert.equal (av2claimt2, Math.round(startVestConf.vest1.amount2 /periods * vested1 / startVestConf.vest1.amount1), "amount t2 1st month ")
   assert.equal (balt2after1 - balt2before1,  av2claimt2, "balt1before1+ av2claimt1" );

   av2claimt2 = (await vestContract.availableClaimToken2()).toNumber();

   assert.equal (av2claimt2, 0, "not all claimed T2")

   });
 it('withdraw t1 once approved amount 3d period time vest2', async () => {

   // time shift 
   var block = await web3.eth.getBlock("latest");
   const timeShift =  monthSecs; // openingTime - block.timestamp 
   await timeMachine.advanceTimeAndBlock(timeShift + 100);
   block = await web3.eth.getBlock("latest");
   assert (block.timestamp > new Date().getTime() / 1000 ,block.timestamp,  "time machine didn't works" )
   // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )

   const vestContract = await VestContract.at(vestContractAddr2);
   const t1 =  await Token1.deployed();

   const balt1before1 =  (await t1.balanceOf(borrowerWallet)).toNumber();
   
   let av2claimt1 =  (await vestContract.availableClaimToken1()).toNumber();
   assert.equal (av2claimt1, startVestConf.vest1.amount1 /3, "amount t1 3d month ")

   await vestContract.claimWithdrawToken1( av2claimt1 ) ;
   
   const balt1after1 =  (await t1.balanceOf(borrowerWallet)).toNumber();

   assert.equal (balt1after1 - balt1before1,  av2claimt1, "balt1before1+ av2claimt1" );

   av2claimt1 = (await vestContract.availableClaimToken1()).toNumber();

   assert.equal (av2claimt1, 0, "not all claimed ")
   });
 it('withdraw t2 once approved amount 3d  period time vest2', async () => {

   // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
   
   const vestContract = await VestContract.at(vestContractAddr2);
 // const t1 =  await Token1.deployed();
    const t2 =  await Token2.deployed();


   const balt2before1 =  (await  t2.balanceOf(accounts[1])).toNumber();
   const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
   let av2claimt2 =  (await vestContract.availableClaimToken2({from:accounts[1]})).toNumber();

   
   await vestContract.claimWithdrawToken2( av2claimt2, {from:accounts[1]} ) ;
   const balt2after1 = (await  t2.balanceOf(accounts[1])).toNumber();

   assert.equal (balt2after1 - balt2before1,  av2claimt2, "balt1before1+ av2claimt1" );
   assert.equal (av2claimt2, Math.round(startVestConf.vest1.amount2 /periods * vested1 / startVestConf.vest1.amount1), "amount t2 1st month ")

   av2claimt2 = (await vestContract.availableClaimToken2()).toNumber();

   assert.equal (av2claimt2, 0, "not all claimed T2")

   
   });


    
    it('restoring chain ', async () => {
      await timeMachine.revertToSnapshot(snapshotId);
    })
   
    

});
