const BeltToken = artifacts.require("BELT")
const MasterBelt = artifacts.require("MasterBelt")

const BeltLPToken = artifacts.require('BeltLPToken')
const VaultBPool = artifacts.require('VaultBPool')

module.exports = function (deployer, network, accounts) {
    deployer.then(async function () {
        const lpToken = (await BeltLPToken.deployed()).address

        const masterBelt = (await MasterBelt.deployed()).address
        const beltToken = (await BeltToken.deployed()).address

        const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

        const vault = await deployer.deploy(VaultBPool,
            masterBelt,
            lpToken
        )

        await (await MasterBelt.deployed()).add(
            100, // 1x
            lpToken,
            false,
            vault.address
        )
    })
}
