/* eslint-disable no-undef */
const timeMachine = require('ganache-time-traveler');
const VestFactory = artifacts.require("VestFactory");
const VestContract = artifacts.require("VestDAIDO");
const Token2 = artifacts.require("Token2");

const monthSecs = 365.25 /12 *60*60*24;

/* const amount1 = 300; 
const amount2 = 1500; 
const token1 = 0x1;
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


/*  beforeEach(async() => {
    let snapshot = await timeMachine.takeSnapshot();
    snapshotId = snapshot['result'];
});

 afterEach(async() => {
    await timeMachine.revertToSnapshot(snapshotId);
}); */


contract('dSV 2side vesting contract', (accounts) => {

var vestContractAddr;
var teamWallet;
var  startVestConf;
  it('Deploy test  2side vesting contract ', async () => {

    const dSVFact =  await  VestFactory.deployed();
    const t2 =  await Token2.deployed();
    teamWallet = accounts[9];
     startVestConf = {
      amount1:300,
      amount2:1500,
      token1: t2.address,
      token2: t2.address,
      pausePeriod:monthSecs,
      vestShare4pauseWithdraw: 5,
      voteShareAbort:75, 
      isNative: true,
      teamWallet: teamWallet 
    }
    
    const txDepl = await dSVFact.deployVest (
      vestRules,
      startVestConf
    );
    
    vestContractAddr = txDepl.logs[0].args[0];
    const eventRules = txDepl.logs[0].args[1];
    const eventConf = txDepl.logs[0].args[2]

    assert.equal(eventRules[0].amount1,  vestRules[0].amount1, "vestRules");
    assert.equal(eventConf.amount2,  startVestConf.amount2, "vestConf");

    const vestContract = await VestContract.at(vestContractAddr);

    const vestConf = await vestContract.vest();
        
    assert.equal(vestConf.pausePeriod,  startVestConf.pausePeriod);

  });

  it('should send amount2 of token2 in the vesting account', async () => {
    let snapshot = await timeMachine.takeSnapshot();
    snapshotId = snapshot['result'];

    const t2 = await Token2.deployed();
  //  const balance = await t2.balanceOf(accounts[0])

    await t2.transfer(teamWallet, startVestConf.amount2/2);
    const balance = await t2.balanceOf(teamWallet)
    assert.equal(balance, startVestConf.amount2/2, "didn't transfer startVestConf.amount2");

   // assert.equal(web3.utils.fromWei(balance),  web3.utils.fromWei(transferSumSV), web3.utils.fromWei(balance) + "- not right in the [0] account");

  //   const balanceCS = await t2.balanceOf(CSaddr.SVETCrowdsale.address);
  //   assert.equal(web3.utils.fromWei(balanceCS),web3.utils.fromWei(transferSumSV), web3.utils.fromWei(balanceCS) + "- not right in the crowdsale contract");
  // }); 
    const vestContract = await VestContract.at(vestContractAddr);

    await t2.approve(vestContractAddr,startVestConf.amount2/2, {from:teamWallet});
    await vestContract.putVesting(t2.address, teamWallet, startVestConf.amount2 / 2, {from:teamWallet} )
    const balanceT2= await t2.balanceOf(accounts[0]);


    await t2.approve(vestContractAddr,startVestConf.amount2/2, {from: accounts[0]} );
    const allowanceT2 =  ( await t2.allowance(accounts[0], vestContractAddr )).toNumber();

    await vestContract.putVesting(t2.address, teamWallet, startVestConf.amount2/2, {from: accounts[0]});


    const vested9 = await vestContract.getVested( {from: teamWallet} ); 
    assert.equal(startVestConf.amount2, vested9/* [1] */.toNumber(), "vested9");


  });

/* 
    

  it('Buy once approved amount right time', async () => {
    var block = await web3.eth.getBlock("latest");
    const timeShift =  24*60*60; // openingTime - block.timestamp 
    timeMachine.advanceTimeAndBlock(timeShift);
    block = await web3.eth.getBlock("latest");
    console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
     
   // assert.equal (block.timestamp,  openingTime +  86400,block.timestamp,  "time machine didn't works" )
    const balanceDAIbefore1 = web3.utils.fromWei  (await DAIi.balanceOf(accounts[1]));
    const balanceSVbefore1 =  web3.utils.fromWei (await CSdepl.balanceOf(accounts[1]));
    await DAIi.approve(CSdepl.address, testPurshDAI, {from: accounts[1]}  );
    await CSdepl.buyTokensDAI(accounts[1], testPurshDAI, {from: accounts[1]} );

    const balanceDAI = web3.utils.fromWei (await DAIi.balanceOf(accounts[1]))
    assert.equal(balanceDAIbefore1-web3.utils.fromWei (testPurshDAI), balanceDAI, balanceDAI + " balanceDAI")
    const balanceSV = web3.utils.fromWei ( await CSdepl.balanceOf(accounts[1]))
    assert.equal(balanceSVbefore1 + web3.utils.fromWei(testPurshDAI) * rate, balanceSV, "balanceDAI")
    });

    
   it('Buy once approved amount not right time after finish', async () => {
    var block = await web3.eth.getBlock("latest");
    const timeShift = closingTime - block.timestamp   + 86400;
    timeMachine.advanceTimeAndBlock(timeShift);
    //assert (block.timestamp,  closingTime+86400, block.timestamp,  "time machine didn't works" )
    block = await web3.eth.getBlock("latest");
    console.log ("new Date: ",   new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )

      const balanceDAIbefore2 = await DAIi.balanceOf(accounts[0], {from: accounts[0]})
      const balanceSVbefore2 = await t2.balanceOf(accounts[0],  {from: accounts[0]})
      await DAIi.approve(CSdepl.address, testPurshDAI.toString(), {from: accounts[0]} );
      await CSdepl.buyTokensDAI(accounts[0], testPurshDAI.toString(), {from: accounts[0]} );
     //TODO  add catch of revert
     assert(false, "todo add test catch not right time")


    //const dSVPOSBalance = (await t2.getBalance.call(accounts[1])).toNumber();
    //const dSVPOSEthBalance = (await t2.getBalanceInEth.call(accounts[1])).toNumber();

    //assert.equal(dSVPOSEthBalance, 2 * dSVPOSBalance, 'Library function returned unexpected function, linkage may be broken');
  }); 
   it('withdraw bought ', async () => {
    var block = await web3.eth.getBlock("latest");
    const timeShift =  vestingPeriod + 1;
    timeMachine.advanceTimeAndBlock(timeShift);
    
     block = await web3.eth.getBlock("latest");
     console.log ("new Date: ",   new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
     const balanceCS = await CSdepl.balanceOf(accounts[1])
     console.log ("balanceCS:",  web3.utils.fromWei(balanceCS))
     await CSdepl.withdrawTokens(accounts[1], {from: accounts[1]} );
     const balanceSV = await t2.balanceOf(accounts[1]);
     assert.equal( balanceCS, balanceSV, "Not right balances " + balanceSV +" vs "+ balanceCS)
     await timeMachine.revertToSnapshot(snapshotId);

  });  */

});
