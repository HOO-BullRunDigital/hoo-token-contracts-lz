// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {BaseDeployer} from "./BaseDeployer.s.sol";
import {AmbrosiaV2} from "../src/AmbrosiaV2.sol";
import { OFT } from "../src/OFT.sol";

import {UUPSProxy} from "../src/UUPSProxy.sol";

contract DeployEsAmbrosiaV2 is Script, BaseDeployer {

    address private create2addrEsAmbrosiaV2;
    address private create2addrProxy;

    bool private deployImplementation = false;

    AmbrosiaV2 private wrappedProxy;

    struct LayerZeroChainDeployment {
        Chains chain;
        address endpoint;
    }

    LayerZeroChainDeployment[] private targetChainsTestnet;

    LayerZeroChainDeployment[] private targetChainsMainnet;

    function setUp() public {
        // Endpoint configuration from: https://docs.layerzero.network/v2/developers/evm/technical-reference/endpoints
        targetChainsTestnet.push(LayerZeroChainDeployment(Chains.Sepolia, 0x6EDCE65403992e310A62460808c4b910D972f10f));
        targetChainsTestnet.push(LayerZeroChainDeployment(Chains.ArbitrumSepolia, 0x6EDCE65403992e310A62460808c4b910D972f10f));
        targetChainsTestnet.push(LayerZeroChainDeployment(Chains.BaseSepolia, 0x6EDCE65403992e310A62460808c4b910D972f10f));

        targetChainsMainnet.push(LayerZeroChainDeployment(Chains.Ethereum, 0x1a44076050125825900e736c501f859c50fE728c));
        targetChainsMainnet.push(LayerZeroChainDeployment(Chains.Arbitrum, 0x1a44076050125825900e736c501f859c50fE728c));
        targetChainsMainnet.push(LayerZeroChainDeployment(Chains.Base, 0x1a44076050125825900e736c501f859c50fE728c));


    }

    function run() public {}

    function deployEsAmbrosiaV2Testnet(uint256 _ambrosiaSalt, uint256 _ambrosiaProxySalt, bool mint) public setEnvDeploy(Cycle.Test) {
        ambrosiaSalt = bytes32(_ambrosiaSalt);
        ambrosiaProxySalt = bytes32(_ambrosiaProxySalt);

        createDeployMultichainTestnet(mint);
    }

    function deployEsAmbrosiaProxyUsingAmbrosiaV2ImplTestnet(uint256 _ambrosiaSalt, uint256 _ambrosiaProxySalt, address ambrosiaImpl) public setEnvDeploy(Cycle.Test) {
        ambrosiaSalt = bytes32(_ambrosiaSalt);
        ambrosiaProxySalt = bytes32(_ambrosiaProxySalt);

        createDeployUUPSMultichainTestnet(ambrosiaImpl);
    }

    function deployEsAmbrosiaV2Mainnet(uint256 _ambrosiaSalt, uint256 _ambrosiaProxySalt, bool mint) public setEnvDeploy(Cycle.Prod) {
        ambrosiaSalt = bytes32(_ambrosiaSalt);
        ambrosiaProxySalt = bytes32(_ambrosiaProxySalt);

        createDeployMultichainMainnet(mint);
    }

    function mintEsAmbrosiaV2TokensTestnet(uint256 amount, address tokenAddress) public setEnvDeploy(Cycle.Test) {
        mintTokens(amount, tokenAddress);
    }

    function createDeployUUPSMultichainTestnet(address ambrosiaImpl) private {
        address[] memory deployedContracts = new address[](targetChainsTestnet.length);
        uint256[] memory forkIds = new uint256[](targetChainsTestnet.length);

        for (uint256 i; i < targetChainsTestnet.length;) {
            console2.log("Deploying to chain:", "\n");

            string memory chainRPC = forks[targetChainsTestnet[i].chain];

            uint256 forkId = vm.createSelectFork(chainRPC);
            forkIds[i] = forkId;

            deployedContracts[i] = deployUUPSProxy(ambrosiaProxySalt, targetChainsTestnet[i].endpoint, ambrosiaImpl);

            ++i;
        }

        wireOApps(deployedContracts, forkIds);

    }

    /// @dev Helper to iterate over chains and select fork.
    function createDeployMultichainTestnet(bool mint) private {
        address[] memory deployedContracts = new address[](targetChainsTestnet.length);
        uint256[] memory forkIds = new uint256[](targetChainsTestnet.length);

        for (uint256 i; i < targetChainsTestnet.length;) {
            console2.log("Deploying to chain:", "\n");

            string memory chainRPC = forks[targetChainsTestnet[i].chain];

            uint256 forkId = vm.createSelectFork(chainRPC);
            forkIds[i] = forkId;

            deployedContracts[i] = chainDeployAmbrosiaV2(targetChainsTestnet[i].endpoint, mint, i);


            ++i;
        }

        wireOApps(deployedContracts, forkIds);
    }

    /// @dev Helper to iterate over chains and select fork.
    function createDeployMultichainMainnet(bool mint) private {
        address[] memory deployedContracts = new address[](targetChainsMainnet.length);
        uint256[] memory forkIds = new uint256[](targetChainsMainnet.length);

        for (uint256 i; i < targetChainsMainnet.length;) {
            console2.log("Deploying to chain:", "\n");

            string memory chainRPC = forks[targetChainsMainnet[i].chain];

            uint256 forkId = vm.createSelectFork(chainRPC);
            forkIds[i] = forkId;

            deployedContracts[i] = chainDeployAmbrosiaV2(targetChainsMainnet[i].endpoint, mint, i);


            ++i;
        }

        wireOApps(deployedContracts, forkIds);
    }

    /// @dev Function to perform actual deployment.
    function chainDeployAmbrosiaV2(address lzEndpoint, bool mint, uint256 i)
    private
    computeCreate2(ambrosiaSalt, ambrosiaProxySalt, lzEndpoint)
    broadcast(deployerPrivateKey)
    returns (address deployedContract)
    {
        //AmbrosiaV2 ambrosia = new AmbrosiaV2{salt: ambrosiaSalt}();

        AmbrosiaV2 ambrosia = AmbrosiaV2(0xAfBDd7381877413a3f66574Fd791b3C9b68624b8);

        require(create2addrEsAmbrosiaV2 == address(ambrosia), "Implementation address mismatch");

        console2.log("EsAmbrosiaV2 implementation address:", address(ambrosia), "\n");

        proxyAmbrosia = new UUPSProxy{salt: ambrosiaProxySalt}(
            address(ambrosia), abi.encodeWithSelector(AmbrosiaV2.initialize.selector,"Escrowed Ambrosia", "esAMBR", lzEndpoint, ownerAddress)
        );

        proxyAmbrosiaAddress = address(proxyAmbrosia);

        require(create2addrProxy == proxyAmbrosiaAddress, "Proxy address mismatch");

        wrappedProxy = AmbrosiaV2(proxyAmbrosiaAddress);

        require(wrappedProxy.owner() == ownerAddress, "Owner role mismatch");

        console2.log("EsAmbrosiaV2 Proxy address:", address(proxyAmbrosia), "\n");


        if(mint && i == 0){
            mintTokens(1_500_000e18, proxyAmbrosiaAddress);
        }

        return address(proxyAmbrosia);
    }

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param ambrosiaSalt The salt for the ambrosia contract.
    /// @param ambrosiaProxySalt The salt for the proxy contract.
    modifier computeCreate2(bytes32 ambrosiaSalt, bytes32 ambrosiaProxySalt, address lzEndpoint) {
        create2addrEsAmbrosiaV2 = vm.computeCreate2Address(ambrosiaSalt, hashInitCode(type(AmbrosiaV2).creationCode));

        create2addrProxy = vm.computeCreate2Address(
            ambrosiaProxySalt,
            hashInitCode(
                type(UUPSProxy).creationCode,
                abi.encode(
                    create2addrEsAmbrosiaV2, abi.encodeWithSelector(AmbrosiaV2.initialize.selector,"Escrowed Ambrosia", "esAMBR", lzEndpoint, ownerAddress)
                )
            )
        );

        _;
    }

    function mintTokens(uint256 amount, address tokenAddress) private {
        console2.log("Minting esAMBR tokens to owner address:", ownerAddress, "\n");
        console2.log("Amount to mint:", amount, "\n");
        AmbrosiaV2(tokenAddress).mint(ownerAddress, amount);

    }

    function deployUUPSProxy(bytes32 ambrosiaProxySalt, address lzEndpoint, address ambrosiaImpl)
    private
    computeCreate2(ambrosiaSalt, ambrosiaProxySalt, lzEndpoint)
    broadcast(deployerPrivateKey)
    returns (address proxyEsAmbrosiaAddress)
    {

        UUPSProxy proxyEsAmbrosia = new UUPSProxy{salt: ambrosiaProxySalt}(
            ambrosiaImpl, abi.encodeWithSelector(AmbrosiaV2.initialize.selector,"Escrowed Ambrosia", "esAMBR", lzEndpoint, ownerAddress)
        );

        proxyEsAmbrosiaAddress = address(proxyEsAmbrosia);

        require(create2addrProxy == proxyEsAmbrosiaAddress, "Proxy address mismatch");

        wrappedProxy = AmbrosiaV2(proxyEsAmbrosiaAddress);

        require(wrappedProxy.owner() == ownerAddress, "Owner role mismatch");

        console2.log("EsAmbrosiaV2 Proxy address:", address(proxyEsAmbrosia), "\n");

        return proxyEsAmbrosiaAddress;

    }

}