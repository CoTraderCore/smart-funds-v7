/* globals artifacts */

var Migrations = artifacts.require('./Migrations.sol')

// var WEI_TO_GWEI = 1000000000
// var gasPrice = (process.env.GAS_PRICE || 1) * WEI_TO_GWEI

module.exports = function(deployer) {
  deployer.deploy(Migrations /* , { gasPrice } */)
}
