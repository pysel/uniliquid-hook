// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";

/// @title Uniliquid
/// @notice A stablecoin liquid representation that is created by the hook
contract Uniliquid is IERC20 {
    /*
    This ERC-20 contract overrides the `balanceOf` function to return the balance based on the shares of the hook. Similarly to lido logic,
    the balance of a user is defined as:
        balance = shares * totalSupply / totalShares
    */
    address public hook;

    uint256 constant internal INFINITE_ALLOWANCE = ~uint256(0);
    uint256 constant internal INITIAL_SUPPLY_AND_SHARES = 1e18;
    address constant internal INITIAL_HOLDER = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;

    mapping(address => uint256) private _shares;
    
    // in tokens
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalShares;
    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    modifier onlyHook() {
        if (msg.sender != hook) {
            revert("Only hook can call this function");
        }
        _;
    }

    constructor(string memory _uname, string memory _usymbol, address _hook) {
        _name = _uname;
        _symbol = _usymbol;
        hook = _hook;

        _initialize();
    }

    // IERC20 functions

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function mint(address to, uint256 shares) external onlyHook {
        _mint(to, shares);
    }

    function burn(address from, uint256 shares) external onlyHook {
        _burn(from, shares);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _transfer(from, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _shares[account] * totalSupply() / _totalShares;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    // Update Functions (only callable by the hook)

    function updateTotalSupply(int256 delta) external onlyHook {
        _totalSupply += uint256(delta);
    }

    function updateTotalShares(int256 delta) external onlyHook {
        _totalShares += uint256(delta);
    }

    // Internal functions

    function _mint(address to, uint256 shares) internal {
        _totalShares += shares;
        _shares[to] += shares;
    }

    function _burn(address from, uint256 shares) internal {
        _totalShares -= shares;
        _shares[from] -= shares;
    }

    function _spendAllowance(address _owner, address _spender, uint256 _amount) internal {
        uint256 currentAllowance = _allowances[_owner][_spender];
        if (currentAllowance != INFINITE_ALLOWANCE) {
            require(currentAllowance >= _amount, "ALLOWANCE_EXCEEDED");
            _approve(_owner, _spender, currentAllowance - _amount);
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        _allowances[owner][spender] = amount;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        uint256 shares = _amountToShares(amount);
        _transferShares(from, to, shares);
    }

    function _transferShares(address from, address to, uint256 shares) internal {
        _shares[from] -= shares;
        _shares[to] += shares;
    }

    function _amountToShares(uint256 amount) internal view returns (uint256) {
        return amount * _totalShares / _totalSupply;
    }

    function _initialize() internal {
        _mint(INITIAL_HOLDER, INITIAL_SUPPLY_AND_SHARES);
        _totalSupply = INITIAL_SUPPLY_AND_SHARES;
    }
}
