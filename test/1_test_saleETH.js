/* eslint-disable no-undef */
const timeMachine = require('ganache-time-traveler');
const VestFactory = artifacts.require("VestFactory");
const Token2 = artifacts.require("Token2");

const amount1 = 0; 
const amount2 = 0; 
const token1 = 0;
const token2 = 0; 
const pausePeriod =0 ;
const vestShare4pauseWithdraw =0 ;
const voteShareAbort = 0;
const isNative = 0 ;
const teamWalle = 0;

/*  beforeEach(async() => {
    let snapshot = await timeMachine.takeSnapshot();
    snapshotId = snapshot['result'];
});

 afterEach(async() => {
    await timeMachine.revertToSnapshot(snapshotId);
}); */


contract('dSVCrowdsale', (accounts) => {


  it('should send 1000000 dSVPOS in the crowdsale account', async () => {
    let snapshot = await timeMachine.takeSnapshot();
    snapshotId = snapshot['result'];

    t2 = await Token2.deployed();
    const balance = await t2.balanceOf(accounts[0])

   // await t2.transfer(CSaddr.dSVCrowdsale.address,transferSumSV)
   // assert.equal(web3.utils.fromWei(balance),  web3.utils.fromWei(transferSumSV), web3.utils.fromWei(balance) + "- not right in the [0] account");
    const balanceCS = await t2.balanceOf(CSaddr.dSVCrowdsale.address);
    assert.equal(web3.utils.fromWei(balanceCS),web3.utils.fromWei(transferSumSV), web3.utils.fromWei(balanceCS) + "- not right in the crowdsale contract");
  }); 

/*   it('Deploy test DAI ', async () => {
    DAIi = await DAItest.deployed();
    const balance = await DAIi.balanceOf(accounts[0])
    assert.equal( 700000, web3.utils.fromWei(balance), web3.utils.fromWei(balance) + "- wasn't in the first account");
   
  });  */

  it('Deploy test crowdsale ', async () => {

    CSdepl =  await  dSVCrowdsale.deployed()
    const rateDAI = await CSdepl.rateDAI()
    assert.equal(rateDAI,  rate, rateDAI, " rateDAI - not right ");
    const opTime = await CSdepl.openingTime()
    //assert.equal( openingTime, opTime.toNumber(),  opTime.toNumber() + " opTime not right ");
    const clTime = await CSdepl.closingTime()
    assert.equal(closingTime, clTime.toNumber(), clTime.toNumber() + " clTime not right ");
    const minSV = web3.utils.fromWei (await CSdepl.minAmountdSVs())
    assert.equal( minAmountdSVs, minSV,  minSV + " minSV not right ");
    const maxSV = await web3.utils.fromWei ( CSdepl.maxAmountdSVs())
    assert.equal( maxAmountdSVs, maxSV, maxSV + " maxSV not right ");
    const addrDAI = await CSdepl.addressDAI()
    assert.equal(addrDAI,  DAIi.address, addrDAI + "addrDAI not right ");

  });
    it('Buy once approved amount not right time before starting', async () => {
      block = await web3.eth.getBlock("latest");
      console.log ("new Date: ",   new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )

    const balanceDAIbefore = await DAIi.balanceOf(accounts[0])
    const balanceSVbefore = await t2.balanceOf(accounts[0])
    await DAIi.approve(CSdepl.address, testPurshDAI );
    await CSdepl.buyTokensDAI(accounts[0], testPurshDAI );
   //TODO  add catch of revert
   assert(false, "todo: add test catch not right time")
  });   

  it('Buy once lower then approved amount at crowdsale time time', async () => {
    var block = await web3.eth.getBlock("latest");
    const timeShift = openingTime - block.timestamp + 24*60*60;
    timeMachine.advanceTimeAndBlock(timeShift);
    block = await web3.eth.getBlock("latest");
    console.log (new Date(block.timestamp  * 1000).toLocaleDateString("en-US") )
     
   // assert.equal (block.timestamp,  openingTime +  86400,block.timestamp,  "time machine didn't works" )
    const balanceDAIbefore1 = web3.utils.fromWei  (await DAIi.balanceOf(accounts[1]));
    const balanceSVbefore1 =  web3.utils.fromWei (await CSdepl.balanceOf(accounts[1]));
    //const testPurshDAI =  web3.utils.toWei("2000");
    await DAIi.approve(CSdepl.address, web3.utils.toWei("200") , {from: accounts[1]}  );
    await CSdepl.buyTokensDAI(accounts[1], web3.utils.toWei("200") , {from: accounts[1]} );

/*     const balanceDAI = web3.utils.fromWei (await DAIi.balanceOf(accounts[1]))
    assert.equal(balanceDAIbefore1-web3.utils.fromWei (testPurshDAI), balanceDAI, balanceDAI + " balanceDAI")
    const balanceSV = web3.utils.fromWei ( await CSdepl.balanceOf(accounts[1]))
    assert.equal(balanceSVbefore1 + web3.utils.fromWei(testPurshDAI) * rate, balanceSV, "balanceDAI")
     */
    });

    

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

  }); 

});
