// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";


import "@openzeppelin/contracts-ethereum-package/contracts/utils/SafeCast.sol";

import "../utils/ExtendedSafeCast.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";
/// @title Time Minted ERC20 Token
/// @notice ERC20 Tokens that are minted at a rate per second, up to a cap, to a specified address
contract TimeMintedToken is ERC20UpgradeSafe, ERC20CappedUpgradeSafe {
  using SafeMath for uint256;
  using SafeCast for uint256;
  using ExtendedSafeCast for uint256;

  address private _mintToAddress;
  uint32 private _timestamp;
  uint32 private _dripRatePerSecond;
  uint256 private _totalMinted;
  uint256 private _rateAdjustment;
  uint32 private _rateAdjustmentThreshold;

  ///@notice when the dripRate is changed
  event DripRateChanged(
    uint32 oldDripRatePerSecond,
    uint32 newDripRatePerSecond
  );


  ///@notice Initializes the name, symbol, cap and mintToAddress of the token.
  function __TimeMintedToken_init (
  string memory name_, 
  string memory symbol_, 
  uint256 cap_,
  address mintToAddress_,
  uint32 dripRatePerSecond_,
  uint256 rateAdjustmentNumerator_,
  uint256 rateAdjustmentDenominator_,
  uint32 rateAdjustmentThreshold_
  ) 
  internal initializer {
  __ERC20_init(name_,symbol_);
  __ERC20Capped_init(cap_) ;

  _mintToAddress = mintToAddress_;
  _dripRatePerSecond = dripRatePerSecond_;
  emit DripRateChanged(0,dripRatePerSecond_);
  _rateAdjustment = FixedPoint.calculateMantissa(rateAdjustmentNumerator_,rateAdjustmentDenominator_);
  _rateAdjustmentThreshold = rateAdjustmentThreshold_;
  }

  //TODO: getters, events, change dripRate, change mintToAddress?


  function mintToAddress() external view returns (address){
    return _mintToAddress;
  }

  function dripRatePerSecond() external view returns (uint32){
    return _dripRatePerSecond;
  }

  function timestamp() external view returns (uint32){
    return _timestamp;
  }

  function totalMinted() external view returns (uint256){
    return _totalMinted;
  }

  function rateAdjustmentThreshold() external view returns (uint32){
    return _rateAdjustmentThreshold;
  }
  /// @notice Mints all available Tokens and sends them to the mintToAddress
  function mint() external {
    uint256 currentTime = _currentTime();
    //is explicitly calling the super contracts good practice?
    _mint(_mintToAddress, _drip(currentTime, ERC20CappedUpgradeSafe.cap().sub(ERC20UpgradeSafe.totalSupply())));
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

  ///@notice adjust dripRate after a certain number of coins have been created.
  function _adjustDripRate() internal{
    if(_totalMinted > _rateAdjustmentThreshold){
      //_dripRatePerSecond = 
    }
  }

  /// @notice returns the current time.  Allows for override in testing.
  /// @return The current time (block.timestamp)
  function _currentTime() internal virtual view returns (uint256) {
    return block.timestamp;
  }

  function _mint(address account, uint256 amount) internal virtual override(ERC20UpgradeSafe) {
        _totalMinted = _totalMinted.add(amount);
        ERC20UpgradeSafe._mint(account,amount);
    }

  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20CappedUpgradeSafe,ERC20UpgradeSafe) {
        ERC20CappedUpgradeSafe._beforeTokenTransfer(from, to, amount);
  }
}