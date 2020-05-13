pragma solidity ^0.6.4;

import "./Meta777.sol";

contract ControlledToken is Meta777 {
  address public controller;

  function initialize (
    string memory _name,
    string memory _symbol,
    address _controller,
    address _trustedForwarder
  ) public virtual initializer {
    require(address(_controller) != address(0), "controller cannot be zero");
    super.initialize(_name, _symbol, _trustedForwarder);
    controller = _controller;
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenAmount) internal virtual {
    address tokenController = _ERC1820_REGISTRY.getInterfaceImplementer(controller, ERC1820_TOKEN_CONTROLLER_INTERFACE_HASH);
    if (tokenController != address(0)) {
      TokenControllerInterface(tokenController).beforeTokenTransfer(from, to, tokenAmount);
    }
  }

  function mint(
    address account,
    uint256 amount
  ) external virtual onlyController {
    _mint(account, amount, "", "");
  }

  function burn(
    address from,
    uint256 amount
  ) external virtual onlyController {
    _burn(from, amount, "", "");
  }

  function _msgSender() internal override virtual view returns (address payable) {
    return BaseRelayRecipient._msgSender();
  }

  modifier onlyController() {
    require(_msgSender() == address(controller), "only controller");
    _;
  }
}