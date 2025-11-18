// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../ERC721SeaDropUpgradeable.sol";

/**
 * @dev Simple extension of ERC721SeaDropUpgradeable used to verify upgrade
 *      safety during testing.
 */
contract ERC721SeaDropUpgradeableV2 is ERC721SeaDropUpgradeable {
    function version() external pure returns (string memory) {
        return "ERC721SeaDropUpgradeable_V2";
    }
}
