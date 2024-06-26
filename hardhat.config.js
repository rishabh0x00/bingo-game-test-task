require("@nomicfoundation/hardhat-toolbox");
require("solidity-coverage");
require("hardhat-gas-reporter");
/** @type import('hardhat/config').HardhatUserConfig */

module.exports = {
  solidity: "0.8.24",
  gasReporter: {
    enabled: true,
    currency: "CHF",
    gasPrice: 21,
  },
};
