pragma solidity 0.6.4;

import "sortition-sum-tree-factory/contracts/SortitionSumTreeFactory.sol";
import "@pooltogether/uniform-random-number/contracts/UniformRandomNumber.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@pooltogether/fixed-point/contracts/FixedPoint.sol";

import "./Meta777.sol";
import "./ControlledToken.sol";
import "../prize-pool/PrizePoolInterface.sol";
import "./TokenControllerInterface.sol";

/* solium-disable security/no-block-members */
contract Ticket is Meta777, TokenControllerInterface, IERC777Recipient {
  using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;

  SortitionSumTreeFactory.SortitionSumTrees sortitionSumTrees;
  PrizePoolInterface public prizePool;
  ControlledToken public timelock;

  mapping(address => uint256) unlockTimestamps;

  bytes32 constant private TREE_KEY = keccak256("PoolTogether/Ticket");
  uint256 constant private MAX_TREE_LEAVES = 5;

  function initialize (
    string memory _name,
    string memory _symbol,
    PrizePoolInterface _prizePool,
    ControlledToken _timelock,
    address _trustedForwarder
  ) public initializer {
    require(address(_timelock) != address(0), "timelock must not be zero");
    require(address(_timelock.controller()) == address(this), "timelock controller does not match");
    require(address(_prizePool) != address(0), "prize pool cannot be zero");
    super.initialize(_name, _symbol, _trustedForwarder);
    sortitionSumTrees.createTree(TREE_KEY, MAX_TREE_LEAVES);
    prizePool = _prizePool;
    _ERC1820_REGISTRY.setInterfaceImplementer(address(this), ERC1820_TOKEN_CONTROLLER_INTERFACE_HASH, address(this));
  }

  function calculateExitFee(address, uint256 tickets) public view returns (uint256) {
    uint256 totalSupply = totalSupply();
    if (totalSupply == 0) {
      return 0;
    }
    return FixedPoint.multiplyUintByMantissa(
      prizePool.calculateRemainingPreviousPrize(),
      FixedPoint.calculateMantissa(tickets, totalSupply)
    );
  }

  function mint(uint256 amount) external nonReentrant {
    _transferAndMint(_msgSender(), amount);
  }

  function mintTo(address to, uint256 amount) external nonReentrant {
    _transferAndMint(to, amount);
  }

  function mintTicketsWithTimelock(uint256 amount) external {
    // Subtract timelocked funds
    timelock.burn(_msgSender(), amount);

    // Mint tickets
    _mint(_msgSender(), amount, "", "");
  }

  function _transferAndMint(address to, uint256 amount) internal {
    // Transfer deposit
    IERC20 token = prizePool.token();
    require(token.allowance(_msgSender(), address(this)) >= amount, "insuff");
    token.transferFrom(_msgSender(), address(this), amount);

    // Mint tickets
    _mint(to, amount, "", "");

    // Deposit into pool
    token.approve(address(prizePool), amount);
    prizePool.mintSponsorship(amount);
  }

  function draw(uint256 randomNumber) public view returns (address) {
    uint256 bound = totalSupply();
    address selected;
    if (bound == 0) {
      selected = address(0);
    } else {
      uint256 token = UniformRandomNumber.uniform(randomNumber, bound);
      selected = address(uint256(sortitionSumTrees.draw(TREE_KEY, token)));
    }
    return selected;
  }

  function _beforeTokenTransfer(address, address from, address to, uint256 tokenAmount) internal virtual override {
    if (from != address(0)) {
      uint256 fromBalance = balanceOf(from);
      sortitionSumTrees.set(TREE_KEY, fromBalance.sub(tokenAmount), bytes32(uint256(from)));
    }

    if (to != address(0)) {
      uint256 toBalance = balanceOf(to);
      sortitionSumTrees.set(TREE_KEY, toBalance.add(tokenAmount), bytes32(uint256(to)));
    }
  }

  function redeemTicketsInstantly(uint256 tickets) external nonReentrant returns (uint256) {
    uint256 exitFee = calculateExitFee(_msgSender(), tickets);

    // burn the tickets
    _burn(_msgSender(), tickets, "", "");

    // redeem the collateral
    prizePool.redeemSponsorship(tickets);

    // transfer tickets less fee
    uint256 balance = tickets.sub(exitFee);
    IERC20(prizePool.token()).transfer(_msgSender(), balance);

    // return the amount that was transferred
    return balance;
  }

  function redeemTicketsWithTimelock(uint256 tickets) external nonReentrant returns (uint256) {
    // burn the tickets
    _burn(_msgSender(), tickets, "", "");

    uint256 unlockTimestamp = prizePool.calculateUnlockTimestamp(_msgSender(), tickets);
    uint256 transferChange;

    // See if we need to sweep the old balance
    uint256 balance = timelock.balanceOf(_msgSender());
    if (unlockTimestamps[_msgSender()] <= block.timestamp && balance > 0) {
      transferChange = balance;
      timelock.burn(_msgSender(), balance);
    }

    // if we are locking these funds for the future
    if (unlockTimestamp > block.timestamp) {
      // time lock new tokens
      timelock.mint(_msgSender(), tickets);
      unlockTimestamps[_msgSender()] = unlockTimestamp;
    } else { // add funds to change
      transferChange = transferChange.add(tickets);
    }

    // if there is change, withdraw the change and transfer
    if (transferChange > 0) {
      prizePool.redeemSponsorship(transferChange);
      IERC20(prizePool.token()).transfer(_msgSender(), transferChange);
    }

    // return the block at which the funds will be available
    return unlockTimestamp;
  }

  function timelockBalanceAvailableAt(address user) external view returns (uint256) {
    return unlockTimestamps[user];
  }

  function beforeTokenTransfer(address from, address to, uint256) external override {
    if (
      _msgSender() == address(timelock)
    ) {
      require(from == address(0) || to == address(0), "only minting or burning is allowed");
    }
  }

  function mintTicketsWithSponsorshipTo(address to, uint256 amount) external {
    _mintTicketsWithSponsorship(to, amount);
  }

  function _mintTicketsWithSponsorship(address to, uint256 amount) internal {
    // Transfer sponsorship
    prizePool.sponsorship().transferFrom(_msgSender(), address(this), amount);

    // Mint draws
    _mint(to, amount, "", "");
  }

  function tokensReceived(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes calldata userData,
    bytes calldata operatorData
  ) external override {
    if (_msgSender() == address(prizePool.sponsorship())) {
      _mintTicketsWithSponsorship(from, amount);
    }
  }
}