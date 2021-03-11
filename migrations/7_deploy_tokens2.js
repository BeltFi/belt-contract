const aBTCB = artifacts.require("aBTCB");
const aETH = artifacts.require("aETH");
const aWBNB = artifacts.require("aWBNB");
const bBETH = artifacts.require("bBETH");

const BeltToken = artifacts.require("BELT");

const aBTCBStrategy = artifacts.require("aBTCBStratAUTO");
const aETHStrategy = artifacts.require("aETHStratAUTO");
const aWBNBStrategy = artifacts.require("aWBNBStratAuto");
const bBETHStrategy = artifacts.require("bBETHStratVLEV");

// mainnet
const tokens = {
    BTCB: "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c",
    ETH: "0x2170ed0880ac9a755fd29b2688956bd959f933f8",
    WBNB: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
    BETH: "0x250632378e573c6be1ac2f97fcdf00515d0aa91b"
};

// // testnet
// const tokens = {
//     BUSD: '0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47',
//     USDT: '0xA11c8D9DC9b66E209Ef60F0C8D969D3CD988782c',
//     USDC: '0x16227D60f7a0e586C66B005219dfc887D13C9531'
// }

//mainnet
const venusBETH = "0x972207a639cc1b374b893cc33fa251b55ceb7c07";



// mainnet
const pancakeRouter = '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F'

// // testnet
// const pancakeRouter = '0x07d090e7FcBC6AFaA507A3441C7c5eE507C457e6'

module.exports = function (deployer, network, accounts) {
    deployer.then(async function () {
        // router
        const beltToken = (await BeltToken.deployed()).address

        // const makeParams = (wantAddress, vTokenAddress) => {
        //     return [
        //         beltToken,
        //         wantAddress,
        //         vTokenAddress,
        //         pancakeRouter
        //     ]
        // }


        {
            let constructorParams = [
                beltToken,
                tokens.BTCB,
                pancakeRouter
            ]
            const strategyBTCB = await deployer.deploy(aBTCBStrategy, ...constructorParams);
            const aBTCBDeployed = await deployer.deploy(aBTCB, tokens.BTCB, strategyBTCB.address);
            await strategyBTCB.transferOwnership(aBTCBDeployed.address)
        }
        {
            let constructorParams = [
                beltToken,
                tokens.ETH,
                pancakeRouter
            ]
            const strategyETH = await deployer.deploy(aETHStrategy, ...constructorParams);
            const aETHBDeployed = await deployer.deploy(aETH, tokens.ETH, strategyETH.address);
            await strategyETH.transferOwnership(aETHBDeployed.address)  
        }
        {
            let constructorParams = [
                beltToken,
                pancakeRouter
            ]
            const strategyWBNB = await deployer.deploy(aWBNBStrategy, ...constructorParams);
            const aWBNBDeployed = await deployer.deploy(aWBNB, tokens.WBNB, strategyWBNB.address);
            await strategyWBNB.transferOwnership(aWBNBDeployed.address);
        }
        
        {
            let constructorParams = [
                beltToken,
                tokens.BETH,
                venusBETH,
                pancakeRouter
            ]
            const strategyBETH = await deployer.deploy(bBETHStrategy, ...constructorParams);
            const bBETHDeployed = await deployer.deploy(bBETH, tokens.BETH, strategyBETH.address);
            await strategyBETH.transferOwnership(bBETHDeployed.address);
        }


        const strategybBUSD = await deployer.deploy(bBUSDStrategy, ...makeParams(tokens.BUSD, vTokens.vBUSD))
        const bBUSDDeployed = await deployer.deploy(bBUSD, tokens.BUSD, strategybBUSD.address)
        await strategybBUSD.transferOwnership(bBUSDDeployed.address)
    })
}