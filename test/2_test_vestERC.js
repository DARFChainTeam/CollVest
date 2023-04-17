/* eslint-disable no-undef */
const timeMachine = require('ganache-time-traveler');
const VestFactory = artifacts.require("VestFactory");
const VestContract = artifacts.require("TokenSaleVesting");
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

const vestRules = [{amount1: 0, amount2: 333, claimTime: 0},
                   {amount1: 0, amount2: 333, claimTime: Math.floor(now + monthSecs*1)},
                   {amount1: 0, amount2: 334, claimTime: Math.floor(now + monthSecs*2)}
                ];



contract('dSV 2side vesting contract both ERC20 tokens', (accounts) => {

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
        vestType: web3.utils.asciiToHex("TokenSaleVesting"),        
        },
    vest2: {      
        borrowerWallet: borrowerWallet,
        isNative: false,
        prevRound:ETHCODE, //noprevround
        capFinishTime: 0,
        roundStartTime: Math.floor(now) - 100,
        nonWhitelisted : true,
        onlyVesting : false
       }
    }
    
    await t2.transfer(accounts[1], startVestConf.vest1.amount2, {from:accounts[0]});
    await t2.approve(dSVFact.address, startVestConf.vest1.amount2, {from:accounts[1]});

    const txDepl = await dSVFact.deployVest (
      t2.address, 
      accounts[1],
      startVestConf.vest1.amount2,
      vestRules,
      startVestConf,
      {from:accounts[1]}
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
    
    await t1.approve(vestContractAddr, startVestConf.vest1.amount1 /3, {from:accounts[1]})
    await t1.approve(vestContractAddr, startVestConf.vest1.amount1 /3, {from:accounts[2]});
    await t1.approve(vestContractAddr, startVestConf.vest1.amount1 /3, {from:accounts[3]});

    const vestContract = await VestContract.at(vestContractAddr);

    await vestContract.swap( startVestConf.vest1.amount1 /3, accounts[1],  {from:accounts[1]} )
    await vestContract.swap( startVestConf.vest1.amount1 /3, accounts[2],  {from:accounts[2]} )
    await vestContract.swap( startVestConf.vest1.amount1 /3, accounts[3],  {from:accounts[3]} )

    const vested1 = await vestContract.getVestedTok1( {from: accounts[1]} ); 
    const vested2 = await vestContract.getVestedTok1( {from: accounts[2]} ); 
    const vested3 = await vestContract.getVestedTok1( {from: accounts[3]} ); 

    assert.equal(startVestConf.vest1.amount1/periods, vested1.toNumber(), "vested1");
    assert.equal(startVestConf.vest1.amount1/periods, vested2.toNumber(), "vested2");
    assert.equal(startVestConf.vest1.amount1/periods, vested3.toNumber(), "vested3");

  });

    



  it('vesting CAPPED', async () => {
    const vestContract = await VestContract.at(vestContractAddr);
    const t2 =  await Token2.deployed();

    const status2SV = await vestContract.status();
    const balt1_c =  await web3.eth.getBalance(vestContractAddr);
    const balt2_c = (await  t2.balanceOf(vestContractAddr)).toNumber();
    

    assert.equal(10, status2SV.toNumber(), "vested not CAPPED status");

  });

    

  
  it('withdraw t2 once approved amount 1 period time', async () => {

    // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
      
    const vestContract = await VestContract.at(vestContractAddr);
    //const t1 =  await Token1.deployed();
    const t2 =  await Token2.deployed();


    const balt2before1 =  (await  t2.balanceOf(accounts[1])).toNumber();
    const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
    let av2claimt2 =  (await vestContract.availableClaim({from:accounts[1]})).toNumber();
    const vested2 = (await vestContract.getVestedTok2({from:accounts[1]})).toNumber();
    const vestConf = await vestContract.vest();
    const withdrawed = (await vestContract.withdrawed(t2.address, accounts[1])).toNumber()

    // await vestContract.claim( av2claimt2, {from:accounts[1]} ) ;

    // assert.equal (av2claimt2, Math.floor(startVestConf.vest1.amount2 /periods * vested1 / startVestConf.vest1.amount1), "amount t2 1st month ")

    const balt2after1 = (await  t2.balanceOf(accounts[1])).toNumber();

    assert.equal (balt2after1 - balt2before1,  av2claimt2, "balt1before1+ av2claimt1" );

    av2claimt2 = (await vestContract.availableClaim()).toNumber();

    assert.equal (av2claimt2, 0, "not all claimed T2")
  
    });

  it('withdraw t2 once approved amount 2nd period time', async () => {

    // time shift 
    var block = await web3.eth.getBlock("latest");
    const timeShift =  monthSecs; // openingTime - block.timestamp 
    await timeMachine.advanceTimeAndBlock(timeShift + 100);
    block = await web3.eth.getBlock("latest");
    assert (block.timestamp > new Date().getTime() / 1000 ,block.timestamp,  "time machine didn't works" )
    console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
   
    // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
      
    const vestContract = await VestContract.at(vestContractAddr);
    // const t1 =  await Token1.deployed();
    const t2 =  await Token2.deployed();


    const balt2before1 =  (await  t2.balanceOf(accounts[1])).toNumber();
    const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
    let av2claimt2 =  (await vestContract.availableClaim({from:accounts[1]})).toNumber();


    await vestContract.claim( av2claimt2, {from:accounts[1]} ) ;
    const balt2after1 = (await  t2.balanceOf(accounts[1])).toNumber();


    assert.equal (av2claimt2, Math.round(startVestConf.vest1.amount2 /periods * vested1 / startVestConf.vest1.amount1), "amount t2 1st month ")
    assert.equal (balt2after1 - balt2before1,  av2claimt2, "balt1before1+ av2claimt1" );

    av2claimt2 = (await vestContract.availableClaim()).toNumber();

    assert.equal (av2claimt2, 0, "not all claimed T2")

    });

  it('withdraw t2 once approved amount 3d  period time', async () => {

    // time shift 
    var block = await web3.eth.getBlock("latest");
    const timeShift =  monthSecs; // openingTime - block.timestamp 
    await timeMachine.advanceTimeAndBlock(timeShift + 100);
    block = await web3.eth.getBlock("latest");
    assert (block.timestamp > new Date().getTime() / 1000 ,block.timestamp,  "time machine didn't works" )
    console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )

    // // console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
    
    const vestContract = await VestContract.at(vestContractAddr);
  // const t1 =  await Token1.deployed();
     const t2 =  await Token2.deployed();


    const balt2before1 =  (await  t2.balanceOf(accounts[1])).toNumber();
    const vested1 = (await vestContract.getVestedTok1({from:accounts[1]})).toNumber();
    let av2claimt2 =  (await vestContract.availableClaim({from:accounts[1]})).toNumber();

    
    await vestContract.claim( av2claimt2, {from:accounts[1]} ) ;
    const balt2after1 = (await  t2.balanceOf(accounts[1])).toNumber();

    assert.equal (balt2after1 - balt2before1,  av2claimt2, "balt1before1+ av2claimt1" );
    assert.equal (av2claimt2, Math.round(startVestConf.vest1.amount2 /periods * vested1 / startVestConf.vest1.amount1), "amount t2 1st month ")

    av2claimt2 = (await vestContract.availableClaim()).toNumber();

    assert.equal (av2claimt2, 0, "not all claimed T2")

    
    });

    it('restoring chain ', async () => {
      await timeMachine.revertToSnapshot(snapshotId);
    })
   
    

});
