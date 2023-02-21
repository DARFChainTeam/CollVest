/** @type import('hardhat/config').HardhatUserConfig */
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-waffle");

module.exports = {
  solidity: "0.8.17",
  paths: {
    tests: "./hhtest"
  }
};

