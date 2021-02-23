const bDAI = artifacts.require("bDAI")
const bUSDC = artifacts.require("bUSDC")
const bUSDT = artifacts.require("bUSDT")
const bBUSD = artifacts.require("bBUSD")

const BeltToken = artifacts.require("BELT")

const bDAIStrategy = artifacts.require("bDAIStratVLEV")
const bUSDCStrategy = artifacts.require("bUSDCStratVLEV")
const bUSDTStrategy = artifacts.require("bUSDTStratVLEV")
const bBUSDStrategy = artifacts.require("bBUSDStratVLEV")

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

// mainnet
const vTokens = {
    "vDAI": "0x334b3ecb4dca3593bccc3c7ebd1a1c1d1780fbf1",
    "vUSDC": "0xeca88125a5adbe82614ffc12d0db554e2e2867c8",
    "vUSDT": "0xfd5840cd36d94d7229439859c0112a4185bc0255",
    "vBUSD": "0x95c78222b3d6e262426483d42cfa53685a67ab9d",
}
// // testnet
// const vTokens = {
//     "vUSDC": "0xD5C4C2e2facBEB59D0216D0595d63FcDc6F9A1a7",
//     "vUSDT": "0xb7526572FFE56AB9D7489838Bf2E18e3323b441A",
//     "vBUSD": "0x08e0A5575De71037aE36AbfAfb516595fE68e5e4",
// }

// mainnet
const pancakeRouter = '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F'

// // testnet
// const pancakeRouter = '0x07d090e7FcBC6AFaA507A3441C7c5eE507C457e6'

module.exports = function (deployer, network, accounts) {
    deployer.then(async function () {
        // router
        const beltToken = (await BeltToken.deployed()).address

        const makeParams = (wantAddress, vTokenAddress) => {
            return [
                beltToken,
                wantAddress,
                vTokenAddress,
                pancakeRouter
            ]
        }

        const strategybDAI = await deployer.deploy(bDAIStrategy, ...makeParams(tokens.DAI, vTokens.vDAI))
        const bDAIDeployed = await deployer.deploy(bDAI, tokens.DAI, strategybDAI.address)
        await strategybDAI.transferOwnership(bDAIDeployed.address)

        const strategybUSDC = await deployer.deploy(bUSDCStrategy, ...makeParams(tokens.USDC, vTokens.vUSDC))
        const bUSDCDeployed = await deployer.deploy(bUSDC, tokens.USDC, strategybUSDC.address)
        await strategybUSDC.transferOwnership(bUSDCDeployed.address)

        const strategybUSDT = await deployer.deploy(bUSDTStrategy, ...makeParams(tokens.USDT, vTokens.vUSDT))
        const bUSDTDeployed = await deployer.deploy(bUSDT, tokens.USDT, strategybUSDT.address)
        await strategybUSDT.transferOwnership(bUSDTDeployed.address)

        const strategybBUSD = await deployer.deploy(bBUSDStrategy, ...makeParams(tokens.BUSD, vTokens.vBUSD))
        const bBUSDDeployed = await deployer.deploy(bBUSD, tokens.BUSD, strategybBUSD.address)
        await strategybBUSD.transferOwnership(bBUSDDeployed.address)
    })
}