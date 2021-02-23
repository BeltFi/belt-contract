const BeltToken = artifacts.require("BELT")
const MasterBelt = artifacts.require("MasterBelt")

module.exports = function (deployer, network, accounts) {
    deployer.then(async function () {
        const belt = await deployer.deploy(BeltToken)
        const masterBelt = await deployer.deploy(MasterBelt, belt.address)

        await belt.transferOwnership(masterBelt.address)
    })
}