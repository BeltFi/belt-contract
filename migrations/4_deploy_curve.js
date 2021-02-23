const bDAI = artifacts.require("bDAI")
const bUSDC = artifacts.require("bUSDC")
const bUSDT = artifacts.require("bUSDT")
const bBUSD = artifacts.require("bBUSD")

const StableSwapB = artifacts.require('StableSwapB')
const DepositB = artifacts.require('DepositB')
const BeltLPToken = artifacts.require('BeltLPToken')

const poolData = require('../contracts/swap/pooldata.json')

// mainnet
const tokens = {
    DAI: '0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3',
    BUSD: '0xe9e7cea3dedca5984780bafc599bd69add087d56',
    USDT: '0x55d398326f99059ff775485246999027b3197955',
    USDC: '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d'
}
// // testnet
// const tokens = {
//     BUSD: '0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47',
//     USDT: '0xA11c8D9DC9b66E209Ef60F0C8D969D3CD988782c',
//     USDC: '0x16227D60f7a0e586C66B005219dfc887D13C9531'
// }

module.exports = function (deployer, network, accounts) {
    deployer.then(async function () {
        const bDAIDeployed = (await bDAI.deployed()).address
        const bUSDCDeployed = (await bUSDC.deployed()).address
        const bUSDTDeployed = (await bUSDT.deployed()).address
        const bBUSDDeployed = (await bBUSD.deployed()).address

        const underlyingCoins = [
            tokens.DAI, tokens.USDC, tokens.USDT, tokens.BUSD
        ]

        const coins = [
            bDAIDeployed, bUSDCDeployed, bUSDTDeployed, bBUSDDeployed
        ]

        const poolInfo = poolData.lp_constructor
        const swapInfo = poolData.swap_constructor

        const pool = await deployer.deploy(BeltLPToken, poolInfo.name, poolInfo.symbol, poolInfo.decimals, poolInfo.supply)
        const swap = await deployer.deploy(StableSwapB, coins, underlyingCoins, pool.address, swapInfo._A, swapInfo._fee, swapInfo._buyback_fee)

        await pool.set_minter(swap.address)

        await deployer.deploy(DepositB, coins, underlyingCoins, swap.address, pool.address)
    })
}