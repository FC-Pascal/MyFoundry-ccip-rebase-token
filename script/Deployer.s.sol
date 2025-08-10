// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract TokenAndPoolDeployer is Script {
    function run() external returns (RebaseToken rebaseToken, RebaseTokenPool rebaseTokenPool) {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        rebaseToken = new RebaseToken();
        rebaseTokenPool = new RebaseTokenPool(
            IERC20(address(rebaseToken)), new address[](0), networkDetails.rmnProxyAddress, networkDetails.routerAddress
        );
        rebaseToken.grantMintAndBurnRole(address(rebaseTokenPool));
        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(rebaseToken)
        );
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(rebaseToken));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(
            address(rebaseToken), address(rebaseTokenPool)
        );
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run(address _rebaseToken) external returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(address(_rebaseToken)));
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
