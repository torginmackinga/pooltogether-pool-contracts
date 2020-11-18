// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";

import "../utils/ExtendedSafeCast.sol";


/// @title Time Minted ERC20 Token
/// @notice ERC20 Tokens that are minted at a rate per second, up to a cap, to a 
/// specified address

contract TimeMintedToken is ERC20, ERC20Capped {
  using SafeMath for uint256;
  using SafeCast for uint256;
  using ExtendedSafeCast for uint256;

  address private _mintToAddress;
  uint32 private _timestamp;
  uint32 private _dripRatePerSecond;

  ///@notice Initializes the name, symbol, cap and mintToAddress of the token.
  constructor (string memory name_, string memory symbol_,uint256 cap_, address mintToAddress_) 
  public
  ERC20(name_,symbol_) 
  ERC20Capped(cap_) 
  {
  _mintToAddress = mintToAddress_;
  }

  /// @notice Mints all available Tokens and sends them to the mintToAddress
  function mint() external {
    uint256 currentTime = _currentTime();
    _mint(_mintToAddress, _drip(currentTime, ERC20Capped.cap().sub(ERC20.totalSupply())));
  }

  /// @notice Drips new tokens
  /// @param timestamp The current time
  /// @param maxNewTokens Maximum new tokens that can be dripped
  function _drip(
    uint256 timestamp,
    uint256 maxNewTokens
  ) internal returns (uint256) {
    // this should only run once per block.
    if (_timestamp == uint32(timestamp)) {
      return 0;
    }

    uint256 lastTime = _timestamp == 0 ? timestamp : _timestamp;
    uint256 newSeconds = timestamp.sub(lastTime);
    uint256 newTokens;
    if (newSeconds > 0 && _dripRatePerSecond > 0) {
      newTokens = newSeconds.mul(_dripRatePerSecond);
      if (newTokens > maxNewTokens) {
        newTokens = maxNewTokens;
      }
    }

    _timestamp = timestamp.toUint32();

    return newTokens;
  }

  /// @notice returns the current time.  Allows for override in testing.
  /// @return The current time (block.timestamp)
  function _currentTime() internal virtual view returns (uint256) {
    return block.timestamp;
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20Capped,ERC20) {
        ERC20Capped._beforeTokenTransfer(from, to, amount);
  }
}