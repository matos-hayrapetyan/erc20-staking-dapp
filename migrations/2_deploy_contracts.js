const TokenA = artifacts.require("TokenA");
const RewardToken = artifacts.require("RewardToken");
const UniStakePool = artifacts.require("UniStakePool");
const contract = require('@truffle/contract');

const factoryJson = require('@uniswap/v2-core/build/UniswapV2Factory.json')
const routerJson = require('@uniswap/v2-periphery/build/UniswapV2Router02.json')

var contractAddressList = require('./addressesList/contractAddress/contractAddress.js');

module.exports = async function(deployer, network, accounts) {
    let _uniswapV2Factory;
    let _uniswapV2Router02;

    const tkaContract = await deployer.deploy(TokenA, 'Token A', 'TKA', 18);
    const tka = await TokenA.deployed();

    // await tka.transfer(accounts[0], '1000000000000000000000000000');

    const rwdContract = await deployer.deploy(RewardToken, 'Reward Token', 'RWD', 18);
    const rewardToken = await RewardToken.deployed();

    if (network === 'test' || network === 'development') {  /// [Note]: Mainnet-fork approach with Truffle/Ganache-CLI/Infura
        _uniswapV2Factory = contractAddressList["Mainnet"]["Uniswap"]["UniswapV2Factory"];
        _uniswapV2Router02 = contractAddressList["Mainnet"]["Uniswap"]["UniswapV2Router02"];
    } else if (network === 'ropsten') {
        _uniswapV2Factory = contractAddressList["Ropsten"]["Uniswap"]["UniswapV2Factory"];
        _uniswapV2Router02 = contractAddressList["Ropsten"]["Uniswap"]["UniswapV2Router02"];
    }

    await deployer.deploy(UniStakePool, tka.address, rewardToken.address, _uniswapV2Factory, _uniswapV2Router02);
    let pool = await UniStakePool.deployed();

    //transfer 50% of total supply to staking pool
    await rewardToken.transfer(pool.address, '500000000000000000000000000');
};
