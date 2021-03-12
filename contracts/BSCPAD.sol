// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";
import "./BEP20UpgradeSafe.sol";

contract BSCPAD is BEP20UpgradeSafe, OwnableUpgradeSafe {
    using SafeCast for int256;
    using SafeMath for uint256;
    using Address for address;

    uint256 public _launchBlock;
    uint256 public _launchTimestamp;

    uint256 public _whiteListSeconds;

    mapping(address => uint256) public _whiteListAmounts;
    mapping(address => uint256) public _whiteListPurchases;

    mapping(address => bool) public _isExchanger;

    function initialize(uint256 totalSupply) public initializer {
        __BEP20_init("BSCPAD.com", "BSCPAD");
        __Ownable_init();

        _whiteListSeconds = 300; //5 min

        _mint(_msgSender(), totalSupply);
    }

    function setExchanger(address account, bool exchanger) public onlyOwner() {
        _isExchanger[account] = exchanger;
    }

    function setLaunchWhiteList(
        uint256 whiteListSeconds,
        address[] calldata whiteListAddresses,
        uint256[] calldata whiteListAmounts
    ) external onlyOwner() {
        require(
            whiteListAddresses.length == whiteListAmounts.length,
            "Invalid whitelist"
        );

        _whiteListSeconds = whiteListSeconds;

        for (uint256 i = 0; i < whiteListAddresses.length; i++) {
            _whiteListAmounts[whiteListAddresses[i]] = whiteListAmounts[i];
        }
    }

    function _beforeTokenTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (amount == 0) return;

        if (
            _launchBlock == 0 &&
            !_isExchanger[sender] &&
            _isExchanger[recipient]
        ) {
            _launchBlock = block.number;
            _launchTimestamp = now;
        }

        if (_isExchanger[sender] && !_isExchanger[recipient]) {
            //buying
            if (now - _launchTimestamp <= _whiteListSeconds) {
                uint256 whiteListRemaining = 0;
                if (
                    _whiteListPurchases[recipient] <
                    _whiteListAmounts[recipient]
                )
                    whiteListRemaining = _whiteListAmounts[recipient].sub(
                        _whiteListPurchases[recipient]
                    );

                require(
                    amount <= whiteListRemaining,
                    "Initial launch is whitelisted, please check if eligible or try after initial period"
                );
                _whiteListPurchases[recipient] = _whiteListPurchases[recipient]
                    .add(amount);
            }
        }
    }
}
