// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  RIPPLEBLADE (RBLD)
  - Total Supply: 10,000,000 * 1e18
  - Transfer tax: 4%
      * 2% -> dev / treasury
      * 1% -> auto liquidity
      * 1% -> burn
  - Auto-liquidity on QuickSwap (Polygon)
  - Fee exemptions for owner, router, treasury, presale addresses
  - Modern OpenZeppelin style
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

contract MyToken is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant TOTAL_SUPPLY = 10_000_000 * 1e18;
    uint256 public constant BPS = 10_000;

    // Fees in BPS
    uint256 public constant BURN_BPS = 100; // 1%
    uint256 public constant LIQ_BPS = 100;  // 1%
    uint256 public constant DEV_BPS = 200;  // 2%

    address public immutable ROUTER;
    address public immutable USDT;
    address public treasury;

    bool public swapEnabled = true;
    uint256 public swapThreshold;
    bool private inSwap;

    // tracking
    uint256 public liquidityTokens;
    uint256 public devTokens;

    mapping(address => bool) public isFeeExempt;

    event SwapAndLiquify(uint256 tokensSwapped, uint256 usdtReceived, uint256 tokensAddedToLP);
    event DevFundsSent(uint256 usdtAmount);
    event TreasuryUpdated(address newTreasury);
    event FeeExemptUpdated(address account, bool exempt);
    event SwapThresholdUpdated(uint256 newThreshold);
    event SwapEnabledUpdated(bool enabled);

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(
        address _router,
        address _usdt,
        address _treasury
    ) ERC20("RIPPLEBLADE", "RBLD") {
        require(_router != address(0), "Router zero");
        require(_usdt != address(0), "USDT zero");
        require(_treasury != address(0), "Treasury zero");

        ROUTER = _router;
        USDT = _usdt;
        treasury = _treasury;

        swapThreshold = TOTAL_SUPPLY / 5000; // 0.02% of total supply

        isFeeExempt[msg.sender] = true;
        isFeeExempt[treasury] = true;
        isFeeExempt[address(this)] = true;
        isFeeExempt[ROUTER] = true;

        _mint(msg.sender, TOTAL_SUPPLY);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "zero");
        treasury = _treasury;
        isFeeExempt[_treasury] = true;
        emit TreasuryUpdated(_treasury);
    }

    function setFeeExempt(address account, bool exempt) external onlyOwner {
        isFeeExempt[account] = exempt;
        emit FeeExemptUpdated(account, exempt);
    }

    function setSwapThreshold(uint256 threshold) external onlyOwner {
        swapThreshold = threshold;
        emit SwapThresholdUpdated(threshold);
    }

    function setSwapEnabled(bool enabled) external onlyOwner {
        swapEnabled = enabled;
        emit SwapEnabledUpdated(enabled);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        if (inSwap || amount == 0 || isFeeExempt[from] || isFeeExempt[to]) {
            super._transfer(from, to, amount);
            return;
        }

        uint256 burnFee = (amount * BURN_BPS) / BPS;
        uint256 liqFee = (amount * LIQ_BPS) / BPS;
        uint256 devFee = (amount * DEV_BPS) / BPS;
        uint256 totalFee = burnFee + liqFee + devFee;
        require(totalFee < amount, "Fee too high");

        uint256 net = amount - totalFee;

        // 1) Burn immediate
        if (burnFee > 0) {
            _burn(from, burnFee);
        }

        // 2) Move fee portion to contract
        uint256 contractFee = liqFee + devFee;
        if (contractFee > 0) {
            super._transfer(from, address(this), contractFee);
            liquidityTokens += liqFee;
            devTokens += devFee;
        }

        // 3) Net transfer
        if (net > 0) {
            super._transfer(from, to, net);
        }

        // 4) Trigger auto-liquidity
        uint256 contractBalance = balanceOf(address(this));
        if (swapEnabled && !inSwap && contractBalance >= swapThreshold && from != ROUTER) {
            _swapAndLiquify(contractBalance);
        }
    }

    function _swapAndLiquify(uint256 contractBalance) internal lockTheSwap {
        uint256 tokensForLiquify = liquidityTokens;
        uint256 tokensForDev = devTokens;

        uint256 totalAcc = tokensForLiquify + tokensForDev;
        if (totalAcc == 0) return;

        if (totalAcc > contractBalance) {
            uint256 scale = (contractBalance * 1e18) / totalAcc;
            tokensForLiquify = (tokensForLiquify * scale) / 1e18;
            tokensForDev = (tokensForDev * scale) / 1e18;
        }

        // Liquidity handling
        if (tokensForLiquify > 0) {
            uint256 half = tokensForLiquify / 2;
            uint256 otherHalf = tokensForLiquify - half;

            _approve(address(this), ROUTER, half + otherHalf);

            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = USDT;

            IUniswapV2Router02(ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                half,
                0,
                path,
                address(this),
                block.timestamp + 600
            );

            uint256 usdtReceived = IERC20(USDT).balanceOf(address(this));
            if (usdtReceived > 0 && otherHalf > 0) {
                IERC20(USDT).approve(ROUTER, usdtReceived);

                IUniswapV2Router02(ROUTER).addLiquidity(
                    address(this),
                    USDT,
                    otherHalf,
                    usdtReceived,
                    0,
                    0,
                    treasury,
                    block.timestamp + 600
                );

                emit SwapAndLiquify(half, usdtReceived, otherHalf);
            }

            liquidityTokens -= tokensForLiquify;
        }

        // Dev tokens to treasury (convert to USDT)
        if (tokensForDev > 0) {
            _approve(address(this), ROUTER, tokensForDev);

            address[] memory path2 = new address[](2);
            path2[0] = address(this);
            path2[1] = USDT;

            IUniswapV2Router02(ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tokensForDev,
                0,
                path2,
                address(this),
                block.timestamp + 600
            );

            uint256 usdtBal = IERC20(USDT).balanceOf(address(this));
            if (usdtBal > 0) {
                IERC20(USDT).safeTransfer(treasury, usdtBal);
                emit DevFundsSent(usdtBal);
            }

            devTokens -= tokensForDev;
        }
    }

    function rescueERC20(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(treasury, amount);
    }
}
