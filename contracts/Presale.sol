// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 Presale contract (USDT payments)
 - Accepts USDT payments via buy()
 - Records buyers' token entitlements (token units)
 - After presale, owner calls finalize() to lock buying; buyers can claim purchased tokens
 - Bonus (10% of purchased tokens) is claimable only after owner sets lpCreated = true
 - The presale contract expects the deployer/owner to transfer sufficient token allocation
   (presale allocation and airdrop reserve) to the presale contract prior to distribution.
*/

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

contract Presale is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token; // token to distribute (decimals assumed 18)
    IERC20 public immutable usdt;  // USDT on Polygon (decimals 6)
    uint256 public tokensPerUSDT;  // token units per 1 USDT (considering USDT decimals)
    bool public finalized;
    bool public lpCreated;

    mapping(address => uint256) public purchasedTokens; // token units
    mapping(address => bool) public purchasedClaimed;
    mapping(address => bool) public bonusClaimed;

    uint256 public totalPurchasedTokens;

    event Bought(address indexed buyer, uint256 usdtAmount, uint256 tokenAmount);
    event Finalized();
    event LPCreated();
    event Claimed(address indexed buyer, uint256 tokenAmount);
    event BonusClaimed(address indexed buyer, uint256 bonusAmount);
    event Withdrawn(address to, uint256 usdtAmount);

    constructor(
        address _token,
        address _usdt,
        uint256 _tokensPerUSDT
    ) {
        require(_token != address(0) && _usdt != address(0), "zero");
        token = IERC20(_token);
        usdt = IERC20(_usdt);
        tokensPerUSDT = _tokensPerUSDT;
    }

    // Buy presale tokens by transferring USDT to this contract (buyer must approve USDT)
    function buy(uint256 usdtAmount) external {
        require(!finalized, "Presale finished");
        require(usdtAmount > 0, "Zero USDT");

        // Transfer USDT in (USDT has 6 decimals)
        usdt.safeTransferFrom(msg.sender, address(this), usdtAmount);

        // token amount = usdtAmount * tokensPerUSDT / (10**usdtDecimals)
        // assume USDT decimals = 6 (Polygon USDT)
        uint8 usdtDecimals = 6;
        uint256 tokenAmount = (usdtAmount * tokensPerUSDT) / (10 ** usdtDecimals);

        purchasedTokens[msg.sender] += tokenAmount;
        totalPurchasedTokens += tokenAmount;

        emit Bought(msg.sender, usdtAmount, tokenAmount);
    }

    // Owner finalizes presale (no more buys)
    function finalize() external onlyOwner {
        require(!finalized, "already");
        finalized = true;
        emit Finalized();
    }

    // After finalize, buyers claim their purchased tokens. Presale contract must hold sufficient tokens
    function claimPurchased() external {
        require(finalized, "not finalized");
        uint256 amount = purchasedTokens[msg.sender];
        require(amount > 0, "nothing");
        require(!purchasedClaimed[msg.sender], "claimed");

        purchasedClaimed[msg.sender] = true;
        token.safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }

    // Owner declares LP created (call after adding liquidity)
    function setLPCreated() external onlyOwner {
        require(finalized, "finalize first");
        lpCreated = true;
        emit LPCreated();
    }

    // After LP created, buyers can claim 10% bonus of their purchased tokens from this contract's airdrop reserve
    function claimBonus() external {
        require(lpCreated, "LP not created");
        require(purchasedClaimed[msg.sender], "claim purchased first");
        require(!bonusClaimed[msg.sender], "bonus claimed");

        uint256 purchased = purchasedTokens[msg.sender];
        require(purchased > 0, "no purchase");

        uint256 bonus = purchased / 10; // 10%
        bonusClaimed[msg.sender] = true;
        token.safeTransfer(msg.sender, bonus);

        emit BonusClaimed(msg.sender, bonus);
    }

    // Owner withdraws collected USDT to treasury
    function withdrawUSDT(address to) external onlyOwner {
        uint256 bal = usdt.balanceOf(address(this));
        require(bal > 0, "no usdt");
        usdt.safeTransfer(to, bal);
        emit Withdrawn(to, bal);
    }

    // Emergency withdraw any ERC20 (owner)
    function rescueERC20(address _token, address to) external onlyOwner {
        uint256 bal = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(to, bal);
    }
}
