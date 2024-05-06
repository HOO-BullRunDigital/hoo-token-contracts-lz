
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";


contract aAmbrosiaRedeem_Upgradeable is Initializable, ContextUpgradeable {
    using SafeMathUpgradeable for uint256;

    IERC20Upgradeable public AMBR;
    IERC20Upgradeable public aAMBR;

    address public owner;

    modifier onlyOwner() {
        require(_msgSender() == owner, "Owner: caller does not have the the owner role");
        _;
    }

    event ambrRedeemed(address tokenOwner, uint256 amount);

    function initialize (
        address _AMBR,
        address _aAMBR
    ) public initializer {
        __AlphaAmbrRedeemUpgradeable_init(_AMBR, _aAMBR);
        owner = _msgSender();
    }

    function __AlphaAmbrRedeemUpgradeable_init(address _AMBR,
        address _aAMBR) internal initializer {
        AMBR = IERC20Upgradeable(_AMBR);
        aAMBR = IERC20Upgradeable(_aAMBR);
    }

    function migrate(uint256 amount) public {
        require(
            aAMBR.balanceOf(_msgSender()) >= amount,
            "Error: Cannot Redeem More than User Balance"
        );

        aAMBR.transferFrom(_msgSender(), address(this), amount);
        AMBR.transfer(_msgSender(), amount.div(1e9));

        emit ambrRedeemed(_msgSender(), amount);

    }

    function withdraw() external onlyOwner {
        uint256 amount = AMBR.balanceOf(address(this));

        AMBR.transfer(_msgSender(), amount);
    }
}
