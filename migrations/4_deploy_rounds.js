/* eslint-disable no-undef */
const VestFactory = artifacts.require("VestFactory")

const TokenSaleVesting = artifacts.require("TokenSaleVesting")

const Token1 = artifacts.require("Token1");
const Token2 = artifacts.require("Token2");

const monthSecs = 365.25 /12 *60*60*24;
const periods = 3 
const ETHCODE =  web3.utils.toChecksumAddress ('0x0000000000000000000000000000000000000001');

min_order = 5e18
max_order = 5_000e18


const startVestConf = {
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

  const vestRules = [{amount1: 0, amount2: 333, claimTime: 0},
    {amount1: 0, amount2: 333, claimTime: Math.floor(now + monthSecs*1)},
    {amount1: 0, amount2: 334, claimTime: Math.floor(now + monthSecs*2)}
 ];


const names = [
        "Seed",
        "Private",
        "Strategic", 
        "Public",
        "Liquidity",	
        "Giveaways",	
        "Rewards",	
        "Marketing",	
        "Advisors",	
        "EcosystemPartnership",
        "CoreTeam",
        "P2EIngameliquidity"	
    ]
  const total_amounts = [23_000_000e18,
                    33_800_000e18,
                    58_750_000e18,
                    34_450_000e18,
                    55_000_000e18,
                    1_400_000e18,
                    500_000e18,
                    100_000_000e18,
                    75_600_000e18,
                    100_000_000e18,
                    100_000_000e18,
                    417_500_000e18
                     ]
const prices = [10e15, //0,01
          12e15, //0,012
          14e15, //0,014
          20e15 //0,02
]



const percents = [
        [30,0,0,0,81,81,81,80,81,81,81,81,81,81,80,81,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [50,0,0,0,79,79,79,80,79,79,79,79,79,79,80,79,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [70,0,0,0,78,78,78,78,78,78,77,77,77,77,77,77,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [400,100,100,100,100,100,100,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [273,182,182,182,181,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [333,333,334,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [83,83,83,83,83,83,83,83,84,84,84,84,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [50,86,86,86,86,86,86,86,87,87,87,87,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,125,0,0,125,0,0,125,0,0,125,0,0,125,0,0,125,0,0,125,0,0,125,0,0,0],
        [50,59,59,59,59,59,59,59,59,59,59,60,60,60,60,60,60,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,42,41,41,41,41,41,41,41,41],
        [0,0,0,0,0,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,32,32,32,32,32,32,32,32]
    ]
function create_round( r )  {
    unlock_date = rounds_start
    unlocks = []
    for i in range(37) {        unlocks.append(unlock_date + i * mount_step)
}    return unlocks
    }




    
module.exports = async function(deployer,network, addresses) {
  await deployer.deploy(VestFactory);
  const vestFactory = await VestFactory.deployed();
  
  await deployer.deploy(TokenSaleVesting);  
  const tsv = await TokenSaleVesting.deployed();
  
  await vestFactory.setTreasureFee(addresses[0], 0) //TO BE CHANGED TO REAL 
  await vestFactory.setContracts (web3.utils.asciiToHex("TokenSaleVesting"), tsv.address);


  
};
