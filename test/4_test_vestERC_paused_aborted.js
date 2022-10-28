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
//const teamWallet = 0; //account [0];
 */

const now =  new Date().getTime() / 1000; //secs unix epoch

const vestRules = [{amount1: 100, amount2: 500, claimTime: Math.floor(now + monthSecs)},
                   {amount1: 100, amount2: 500, claimTime: Math.floor(now + monthSecs*2)},
                   {amount1: 100, amount2: 500, claimTime: Math.floor(now + monthSecs*3)}
                ];



contract('dSV 2side vesting contract both ERC20 tokens with pausing and continuing', (accounts) => {

const teamWallet  = accounts[9];

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
      amount1:300,
      amount2:1500,
      token1: t1.address,
      token2: t2.address,
      pausePeriod:monthSecs,
      vestShare4pauseWithdraw: 5,
      voteShareAbort:75, 
      isNative: false,
      teamWallet: teamWallet 
    }
    
    const txDepl = await dSVFact.deployVest (
      vestRules,
      startVestConf
    );
    
    vestContractAddr = txDepl.logs[0].args[0];
    const eventConf  = txDepl.logs[0].args[1];
    const eventRules = txDepl.logs[0].args[2]

    assert.equal(eventRules[0].amount1,  vestRules[0].amount1, "vestRules");
    assert.equal(eventConf.amount2,  startVestConf.amount2, "vestConf");

    const vestContract = await VestContract.at(vestContractAddr);

    const vestConf = await vestContract.vest();
        
    assert.equal(vestConf.pausePeriod,  startVestConf.pausePeriod);

  });


  it('should send amount1 of token1 to  vesting contract', async () => {
    const t1 = await Token1.deployed();


    await t1.transfer(accounts[1], startVestConf.amount1 /3, {from:accounts[0]});
    await t1.transfer(accounts[2], startVestConf.amount1 /3, {from:accounts[0]});
    await t1.transfer(accounts[3], startVestConf.amount1 /3, {from:accounts[0]});
    
    await t1.approve(vestContractAddr, startVestConf.amount1 /3, {from:accounts[1]});
    await t1.approve(vestContractAddr, startVestConf.amount1 /3, {from:accounts[2]});
    await t1.approve(vestContractAddr, startVestConf.amount1 /3, {from:accounts[3]});

    const vestContract = await VestContract.at(vestContractAddr);

    await vestContract.putVesting(startVestConf.token1, accounts[1], startVestConf.amount1 /3, {from:accounts[1], value:startVestConf.amount1 /3} )
    await vestContract.putVesting(startVestConf.token1, accounts[2], startVestConf.amount1 /3, {from:accounts[2], value:startVestConf.amount1 /3} )
    await vestContract.putVesting(startVestConf.token1, accounts[3], startVestConf.amount1 /3, {from:accounts[3], value:startVestConf.amount1 /3} )


    const vested1 = await vestContract.getVestedTok1( {from: accounts[1]} ); 
    const vested2 = await vestContract.getVestedTok1( {from: accounts[2]} ); 
    const vested3 = await vestContract.getVestedTok1( {from: accounts[3]} ); 

    assert.equal(startVestConf.amount1/periods, vested1.toNumber(), "vested1");
    assert.equal(startVestConf.amount1/periods, vested2.toNumber(), "vested2");
    assert.equal(startVestConf.amount1/periods, vested3.toNumber(), "vested3");

  });

    

  it('should send amount2 of token2 to  vesting contract', async () => {
    // let snapshot = await timeMachine.takeSnapshot();
    // snapshotId = snapshot['result'];

    const t2 = await Token2.deployed();
  //  const balance = await t2.balanceOf(accounts[0])

    await t2.transfer(teamWallet, startVestConf.amount2);
    const balance = (await t2.balanceOf(teamWallet)).toNumber();
    assert.equal(balance, startVestConf.amount2, "didn't transfer startVestConf.amount2");


    const vestContract = await VestContract.at(vestContractAddr);
    const balanceT2_9= (await t2.balanceOf(accounts[9])).toNumber();;

    await t2.approve(vestContractAddr,startVestConf.amount2, {from:teamWallet});
    await vestContract.putVesting(t2.address, teamWallet, startVestConf.amount2 /2 , {from:teamWallet} )
    
    // const allowanceT2 =  ( await t2.allowance(accounts[0], vestContractAddr )).toNumber();
    await t2.approve(vestContractAddr,startVestConf.amount2, {from:accounts[0]});

    //TODO - strange bug, cant invest from acc[0]
    await vestContract.putVesting(t2.address, teamWallet, startVestConf.amount2/2, {from: accounts[0]});

    const vested9 = await vestContract.getVestedTok2( {from: teamWallet} ); 
    assert.equal(startVestConf.amount2, vested9/* [1] */.toNumber(), "vested9");


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
    console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )

    const vestContract = await VestContract.at(vestContractAddr);
    const t1 =  await Token1.deployed();

    const balt1before1 =  (await t1.balanceOf(teamWallet)).toNumber();
    
    let av2claimt1 =  (await vestContract.availableClaimToken1()).toNumber();
    assert.equal (av2claimt1, startVestConf.amount1 /3, "amount t1 1st month ")

    await vestContract.claimWithdrawToken1( av2claimt1 ) ;
    
    const balt1after1 =  (await t1.balanceOf(teamWallet)).toNumber();

    assert.equal (balt1after1 - balt1before1,  av2claimt1, "balt1before1+ av2claimt1" );

    av2claimt1 = (await vestContract.availableClaimToken1()).toNumber();

    assert.equal (av2claimt1, 0, "not all claimed ")

    });
  it('withdraw t2 once approved amount 1 period time', async () => {

    // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
      
    const vestContract = await VestContract.at(vestContractAddr);
    //const t1 =  await Token1.deployed();
    const t2 =  await Token2.deployed();


    const balt2before1 =  (await  t2.balanceOf(accounts[1])).toNumber();
    const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
    let av2claimt2 =  (await vestContract.availableClaimToken2({from:accounts[1]})).toNumber();

    await vestContract.claimWithdrawToken2( av2claimt2, {from:accounts[1]} ) ;

    assert.equal (av2claimt2, Math.floor(startVestConf.amount2 /periods * vested1 / startVestConf.amount1), "amount t2 1st month ")

    const balt2after1 = (await  t2.balanceOf(accounts[1])).toNumber();

    assert.equal (balt2after1 - balt2before1,  av2claimt2, "balt1before1+ av2claimt1" );

    av2claimt2 = (await vestContract.availableClaimToken2()).toNumber();

    assert.equal (av2claimt2, 0, "not all claimed T2")
  
    });



  it('Pause and when vested enough and try  to  withdraw (negative) ', async () => {
    var block = await web3.eth.getBlock("latest");
    const timeShift =  monthSecs; // openingTime - block.timestamp 
    await timeMachine.advanceTimeAndBlock(timeShift + 100);
    block = await web3.eth.getBlock("latest");
    assert (block.timestamp > new Date().getTime() / 1000 ,block.timestamp,  "time machine didn't works" )
    console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
    const vestContract = await VestContract.at(vestContractAddr);
    let av2claimt1 =  (await vestContract.availableClaimToken1()).toNumber();
    assert.equal (av2claimt1, startVestConf.amount1 /3, "amount t1 3rd month ")

    await vestContract. pauseWithdraw({from: accounts[1]}) ;
    try {
      await vestContract.claimWithdrawToken1( 1 ) ;

    } catch (e) {
      //console.log(e)
      assert.equal(e.data.reason, "Withdraw paused by participant", "Withdraw paused by participant" )

    }

    try {
      await vestContract.claimWithdrawToken2( 1 ) ;

    } catch (e) {
      //console.log(e)
      assert.equal(e.data.reason, "Withdraw paused by participant", "Withdraw paused by participant" )

    }

  });

  it('Voting for abort - not enough votes for refund (negative) ', async () => {

    const vestContract = await VestContract.at(vestContractAddr);
    
    const tx = await vestContract.voteAbort(true, {from: accounts[1]});

    //console.log(tx)
    const votes = tx.logs[1].args[1];
    assert (votes, 33, "votes acc1 ")

    const statusVest = (await vestContract.status()).toNumber();

    assert (statusVest, 150, "voting");
  
    try {
      await vestContract.refund({from: accounts[1]});
    }
    catch (e) {
      assert.equal(e.data.reason,  "Vesting works normally, can't refund" );
    }

    });

    it('Voting for abort -  enough votes for refund, refunding ', async () => {

      const vestContract = await VestContract.at(vestContractAddr);
      
  
      let tx = await vestContract.voteAbort(true, {from: accounts[2]});
      let  votes = tx.logs[0].args[1];
      assert (votes, 33, "votes acc2 ")
  
      tx = await vestContract.voteAbort(true, {from: accounts[3]});
       votes = tx.logs[0].args[1];
      assert (votes, 33, "votes acc3 ")
  

      const statusVest = (await vestContract.status()).toNumber();
  
      assert (statusVest, 200, "aborted");
    
      
      await vestContract.refund({from: accounts[1]});
      
      await vestContract.refund({from: accounts[2]});

      await vestContract.refund({from: accounts[3]});

  
      });

    it('restoring chain ', async () => {
      await timeMachine.revertToSnapshot(snapshotId);
    })
   
    

});
