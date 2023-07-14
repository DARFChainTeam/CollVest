/* eslint-disable no-undef */
const { ethers } = require('hardhat');

const mainnets = {
	1: 'mainnet',
	137: 'matic',
  56: 'BSC'
};


async function main() {

  const VestFactory = await ethers.getContractFactory("VestFactory")
  const VestDAIDO = await ethers.getContractFactory("VestDAIDO")
  const VestCollateral = await ethers.getContractFactory("VestCollateral")
  const VestCollateralNFT121 = await ethers.getContractFactory("VestNFTasCollateral1to1")
  
  const Token1 = await ethers.getContractFactory("Token1");
  const Token2 = await ethers.getContractFactory("Token2");

  const [deployer] = await ethers.getSigners();
  const network = await deployer.provider.getNetwork();

  const vestFactory = await VestFactory.deploy();
  await vestFactory.deployed();
  const vestDAIDO = await VestDAIDO.deploy();
  await vestDAIDO.deployed();
  const vestCollateralNFT121 = await VestCollateralNFT121.deploy();
  await vestCollateralNFT121.deployed();
  const vestCollateral = await VestCollateral.deploy();
  await vestCollateral.deployed();
  await vestFactory.setContracts (web3.utils.asciiToHex("DAIDO"), vestDAIDO.address);
  await vestFactory.setContracts (web3.utils.asciiToHex("Collateral"), vestCollateral.address);
  await vestFactory.setContracts (web3.utils.asciiToHex("NFTCollateral121"), vestCollateralNFT121.address);

  if (mainnets[network] === undefined ){  
    const token1 = await Token1.deploy();
    await token1.deployed()
    const token2 = await Token1.deploy();
    await token2.deployed()
    // const tokenNFT = await Token1.deploy();

  }

};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});