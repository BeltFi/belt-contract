const HDWalletProvider = require('truffle-hdwallet-provider');

const privateKey = "";

module.exports = {
    contracts_directory: "./contracts",
    compilers: {
        solc: {
            version: "0.6.12",
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200   // Optimize for how many times you intend to run the code
                }
                //,evmVersion: <string> // Default: "istanbul"
            },
        }
    },
    networks: {
        testnet: {
            provider: () => new HDWalletProvider(privateKey, `https://data-seed-prebsc-2-s1.binance.org:8545`),
            network_id: 97,
            confirmations: 3,
            timeoutBlocks: 200,
            skipDryRun: true
        },
        mainnet: {
//            provider: () => new HDWalletProvider(privateKey, `https://bsc-dataseed.binance.org`),
	    provider: () => new HDWalletProvider(privateKey, 'https://api.bsc.ozys.net'),
            network_id: 56,
	    gasPrice: 5000000000,
            confirmations: 3,
            timeoutBlocks: 200,
            skipDryRun: true,

        }
    }
};
