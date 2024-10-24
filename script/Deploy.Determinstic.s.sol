// SPDX-License-Identifier: UNLICENSED

// Usage: source .env && forge script ./script/Deploy.Deterministic.s.sol --rpc-url=$SEPOLIA_RPC_URL --broadcast --etherscan-api-key=$ETHERSCAN_API_KEY --verify

pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { WrappedVault } from "../src/WrappedVault.sol";
import { WrappedVaultFactory } from "../src/WrappedVaultFactory.sol";
import { Points } from "../src/Points.sol";
import { PointsFactory } from "../src/PointsFactory.sol";
import { VaultMarketHub } from "../src/VaultMarketHub.sol";
import { RecipeMarketHub } from "../src/RecipeMarketHub.sol";
import { WeirollWallet } from "../src/WeirollWallet.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";
import { MockERC4626 } from "test/mocks/MockERC4626.sol";

// Deployer
address constant CREATE2_FACTORY_ADDRESS = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

// Deployment Salts
string constant POINTS_FACTORY_SALT = "ROYCO_POINTS_FACTORY_458371a243a7299e99f3fbfb67799eaaf734ccaf"; // 0xB9a6e049bc617242ECF62e6c856F5e88B9E9a876
string constant WRAPPED_VAULT_FACTORY_SALT = "ROYCO_WRAPPED_VAULT_FACTORY_458371a243a7299e99f3fbfb67799eaaf734ccaf"; // 0x64eF0CF35ED8393cd676Ec483073D762313c5D71
string constant WEIROLL_WALLET_SALT = "ROYCO_WEIROLL_WALLET_458371a243a7299e99f3fbfb67799eaaf734ccaf"; // 0x40a1c08084671E9A799B73853E82308225309Dc0
string constant VAULT_MARKET_HUB_SALT = "ROYCO_VAULT_MARKET_HUB_458371a243a7299e99f3fbfb67799eaaf734ccaf"; // 0x42Dc944A9663D380e614Dcb7b1C4bAd466FDE065
string constant RECIPE_MARKET_HUB_SALT = "ROYCO_RECIPE_MARKET_HUB_458371a243a7299e99f3fbfb67799eaaf734ccaf"; // 0xCE2e775C1D53eD4E0f5a12cFf297f271a08404F8

// Deployment Configuration
address constant ROYCO_OWNER = 0x1000000000000000000000000000000000000000;
address constant PROTOCOL_FEE_RECIPIENT = 0x2000000000000000000000000000000000000000;
uint256 constant PROTOCOL_FEE = 0.01e18;
uint256 constant MINIMUM_FRONTEND_FEE = 0.001e18;

contract DeployDeterministic is Script {
    error Create2DeployerNotDeployed();

    error DeploymentFailed(bytes reason);
    error NotDeployedToExpectedAddress(address expected, address actual);
    error AddressDoesNotContainBytecode(address addr);

    error PointsFactoryOwnerIncorrect(address expected, address actual);

    error WrappedVaultFactoryProtocolFeeRecipientIncorrect(address expected, address actual);
    error WrappedVaultFactoryProtocolFeeIncorrect(uint256 expected, uint256 actual);
    error WrappedVaultFactoryMinimumFrontendFeeIncorrect(uint256 expected, uint256 actual);
    error WrappedVaultFactoryPointsFactoryIncorrect(address expected, address actual);

    error VaultMarketHubOwnerIncorrect(address expected, address actual);

    error RecipeMarketHubWeirollWalletImplementationIncorrect(address expected, address actual);
    error RecipeMarketHubProtocolFeeIncorrect(uint256 expected, uint256 actual);
    error RecipeMarketHubMinimumFrontendFeeIncorrect(uint256 expected, uint256 actual);
    error RecipeMarketHubOwnerIncorrect(address expected, address actual);
    error RecipeMarketHubPointsFactoryIncorrect(address expected, address actual);

    function _generateUint256SaltFromString(string memory _salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_salt)));
    }

    function _generateDeterminsticAddress(string memory _salt, bytes memory _creationCode) internal pure returns (address) {
        uint256 salt = _generateUint256SaltFromString(_salt);
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), CREATE2_FACTORY_ADDRESS, salt, keccak256(_creationCode)));
        return address(uint160(uint256(hash)));
    }

    function _checkDeployer() internal view {
        if (CREATE2_FACTORY_ADDRESS.code.length == 0) {
            revert Create2DeployerNotDeployed();
        }
    }

    function _deploy(string memory _salt, bytes memory _creationCode) internal returns (address deployedAddress) {
        (bool success, bytes memory data) = CREATE2_FACTORY_ADDRESS.call(abi.encodePacked(_generateUint256SaltFromString(_salt), _creationCode));

        if (!success) {
            revert DeploymentFailed(data);
        }

        assembly ("memory-safe") {
            deployedAddress := shr(0x60, mload(add(data, 0x20)))
        }
    }

    function _deployWithSanityChecks(string memory _salt, bytes memory _creationCode) internal returns (address) {
        address expectedAddress = _generateDeterminsticAddress(_salt, _creationCode);

        address addr = _deploy(_salt, _creationCode);

        if (addr != expectedAddress) {
            revert NotDeployedToExpectedAddress(expectedAddress, addr);
        }

        if (address(addr).code.length == 0) {
            revert AddressDoesNotContainBytecode(addr);
        }

        return addr;
    }

    function _verifyPointsFactoryDeployment(PointsFactory _pointsFactory) internal view {
        if (_pointsFactory.owner() != ROYCO_OWNER) revert PointsFactoryOwnerIncorrect(ROYCO_OWNER, _pointsFactory.owner());
    }

    function _verifyWrappedVaultFactoryDeployment(WrappedVaultFactory _wrappedVaultFactory, PointsFactory _pointsFactory) internal view {
        if (_wrappedVaultFactory.protocolFeeRecipient() != PROTOCOL_FEE_RECIPIENT) {
            revert WrappedVaultFactoryProtocolFeeRecipientIncorrect(PROTOCOL_FEE_RECIPIENT, _wrappedVaultFactory.protocolFeeRecipient());
        }
        if (_wrappedVaultFactory.protocolFee() != PROTOCOL_FEE) {
            revert WrappedVaultFactoryProtocolFeeIncorrect(PROTOCOL_FEE, _wrappedVaultFactory.protocolFee());
        }
        if (_wrappedVaultFactory.minimumFrontendFee() != MINIMUM_FRONTEND_FEE) {
            revert WrappedVaultFactoryMinimumFrontendFeeIncorrect(MINIMUM_FRONTEND_FEE, _wrappedVaultFactory.minimumFrontendFee());
        }
        if (_wrappedVaultFactory.pointsFactory() != address(_pointsFactory)) {
            revert WrappedVaultFactoryPointsFactoryIncorrect(address(_pointsFactory), _wrappedVaultFactory.pointsFactory());
        }
    }

    function _verifyVaultMarketHubDeployment(VaultMarketHub _vaultMarketHub) internal view {
        if (_vaultMarketHub.owner() != ROYCO_OWNER) revert VaultMarketHubOwnerIncorrect(ROYCO_OWNER, _vaultMarketHub.owner());
    }

    function _verifyRecipeMarketHubDeployment(RecipeMarketHub _recipeMarketHub, WeirollWallet _weirollWallet, PointsFactory _pointsFactory) internal view {
        if (_recipeMarketHub.WEIROLL_WALLET_IMPLEMENTATION() != address(_weirollWallet)) {
            revert RecipeMarketHubWeirollWalletImplementationIncorrect(address(_weirollWallet), _recipeMarketHub.WEIROLL_WALLET_IMPLEMENTATION());
        }
        if (_recipeMarketHub.protocolFee() != PROTOCOL_FEE) {
            revert RecipeMarketHubProtocolFeeIncorrect(PROTOCOL_FEE, _recipeMarketHub.protocolFee());
        }
        if (_recipeMarketHub.minimumFrontendFee() != MINIMUM_FRONTEND_FEE) {
            revert RecipeMarketHubMinimumFrontendFeeIncorrect(MINIMUM_FRONTEND_FEE, _recipeMarketHub.minimumFrontendFee());
        }
        if (_recipeMarketHub.owner() != ROYCO_OWNER) {
            revert RecipeMarketHubOwnerIncorrect(ROYCO_OWNER, _recipeMarketHub.owner());
        }
        if (_recipeMarketHub.POINTS_FACTORY() != address(_pointsFactory)) {
            revert RecipeMarketHubPointsFactoryIncorrect(address(_pointsFactory), _recipeMarketHub.POINTS_FACTORY());
        }
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console2.log("Deploying with address: ", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        _checkDeployer();
        console2.log("Deployer is ready");

        // Deploy PointsFactory
        console2.log("Deploying PointsFactory");
        bytes memory pointsFactoryCreationCode = abi.encodePacked(vm.getCode("PointsFactory"), abi.encode(ROYCO_OWNER));
        PointsFactory pointsFactory = PointsFactory(_deployWithSanityChecks(POINTS_FACTORY_SALT, pointsFactoryCreationCode));
        console2.log("Verifying PointsFactory deployment");
        _verifyPointsFactoryDeployment(pointsFactory);
        console2.log("PointsFactory deployed at: ", address(pointsFactory));

        // Deploy WrappedVaultFactory
        console2.log("Deploying WrappedVaultFactory");
        bytes memory wrappedVaultFactoryCreationCode =
            abi.encodePacked(vm.getCode("WrappedVaultFactory"), abi.encode(PROTOCOL_FEE_RECIPIENT, PROTOCOL_FEE, MINIMUM_FRONTEND_FEE, address(pointsFactory)));
        WrappedVaultFactory wrappedVaultFactory = WrappedVaultFactory(_deployWithSanityChecks(WRAPPED_VAULT_FACTORY_SALT, wrappedVaultFactoryCreationCode));
        console2.log("Verifying WrappedVaultFactory deployment");
        _verifyWrappedVaultFactoryDeployment(wrappedVaultFactory, pointsFactory);
        console2.log("WrappedVaultFactory deployed at: ", address(wrappedVaultFactory));

        // Deploy WeirollWallet
        console2.log("Deploying WeirollWallet");
        bytes memory weirollWalletCreationCode = abi.encodePacked(vm.getCode("WeirollWallet"));
        WeirollWallet weirollWallet = WeirollWallet(payable(_deployWithSanityChecks(WEIROLL_WALLET_SALT, weirollWalletCreationCode)));
        console2.log("WeirollWallet deployed at: ", address(weirollWallet));

        // Deploy VaultMarketHub
        console2.log("Deploying VaultMarketHub");
        bytes memory vaultMarketHubCreationCode = abi.encodePacked(vm.getCode("VaultMarketHub"), abi.encode(ROYCO_OWNER));
        VaultMarketHub vaultMarketHub = VaultMarketHub(_deployWithSanityChecks(VAULT_MARKET_HUB_SALT, vaultMarketHubCreationCode));
        console2.log("Verifying VaultMarketHub deployment");
        _verifyVaultMarketHubDeployment(vaultMarketHub);
        console2.log("VaultMarketHub deployed at: ", address(vaultMarketHub));

        // Deploy RecipeMarketHub
        console2.log("Deploying RecipeMarketHub");
        bytes memory recipeMarketHubCreationCode = abi.encodePacked(
            vm.getCode("RecipeMarketHub"), abi.encode(address(weirollWallet), PROTOCOL_FEE, MINIMUM_FRONTEND_FEE, ROYCO_OWNER, address(pointsFactory))
        );
        RecipeMarketHub recipeMarketHub = RecipeMarketHub(_deployWithSanityChecks(RECIPE_MARKET_HUB_SALT, recipeMarketHubCreationCode));
        console2.log("Verifying RecipeMarketHub deployment");
        _verifyRecipeMarketHubDeployment(recipeMarketHub, weirollWallet, pointsFactory);
        console2.log("RecipeMarketHub deployed at: ", address(recipeMarketHub));

        vm.stopBroadcast();
    }
}