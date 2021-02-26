const BeltToken = artifacts.require("BELT")
const MasterBelt = artifacts.require("MasterBelt")

const VaultCakePool = artifacts.require('VaultCakePool')
const CakeLPToken = '0x481E793d149cB3c7Bba66Cfc52770C1AecFFdb85'

module.exports = function (deployer, network, accounts) {
    deployer.then(async function () {
        const masterBelt = (await MasterBelt.deployed()).address

        const vault = await deployer.deploy(VaultCakePool,
            masterBelt,
            CakeLPToken
        )

        await (await MasterBelt.deployed()).add(
            100, // 1x
            CakeLPToken,
            false,
            vault.address
        )
    })
}
