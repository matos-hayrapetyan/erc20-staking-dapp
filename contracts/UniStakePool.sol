pragma solidity >=0.6.0 <0.8.0;

// tokens
import "./TokenA.sol";
import "./RewardToken.sol";

// libs
import "openzeppelin-solidity/contracts/access/Ownable.sol";

// WETH
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

// Uniswap v2
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract UniStakePool is Ownable {

    using SafeMath for uint;

    TokenA public _TokenA;
    RewardToken public _RewardToken;

    IWETH public _wETH;
    IUniswapV2Factory public _uniswapV2Factory;
    IUniswapV2Router02 public _uniswapV2Router02;

    address _TKA_TOKEN;
    address _REWARD_TOKEN;
    address _WETH_TOKEN;
    address _UNISWAP_V2_FACTORY;
    address _UNISWAP_V2_ROUTER_02;

    address[] public _stakers;
    mapping(address => uint) public _stakingBalance;
    mapping(address => uint) public _stakedBalance;
    mapping(address => bool) public _hasStaked;
    mapping(address => bool) public _isStaking;

    uint _totalStakedLPTokenAmount;        /// Total staked UNI-LP tokens (TKA-ETH) amount during whole period
    uint _currentlyStakedLPTokenAmount;    /// Total staked UNI-LP tokens (TKA-ETH) amount at the moment

    constructor(
        TokenA TokenA_,
        RewardToken RewardToken_,
        IUniswapV2Factory uniswapV2Factory_,
        IUniswapV2Router02 uniswapV2Router02_
    ) public {
        _TokenA = TokenA_;
        _RewardToken = RewardToken_;
        _uniswapV2Factory = uniswapV2Factory_;
        _uniswapV2Router02 = uniswapV2Router02_;
        _wETH = IWETH(uniswapV2Router02_.WETH());

        _TKA_TOKEN = address(TokenA_);
        _REWARD_TOKEN = address(RewardToken_);
        _UNISWAP_V2_FACTORY = address(uniswapV2Factory_);
        _UNISWAP_V2_ROUTER_02 = address(uniswapV2Router02_);
        _WETH_TOKEN = address(uniswapV2Router02_.WETH());
    }

    function createPairWithETH() public returns (IUniswapV2Pair pair) {
        address pair_ = _uniswapV2Factory.createPair(_TKA_TOKEN, _WETH_TOKEN);
        /// [Note]: WETH is treated as ETH
        return IUniswapV2Pair(pair_);
    }

    function addLiquidityWithETH(
        IUniswapV2Pair pair_,
        uint erc20AmountDesired_
    ) public payable returns (bool) {
        _TokenA.transferFrom(msg.sender, address(this), erc20AmountDesired_);
        uint ETHAmountMin = msg.value;

        /// Convert ETH (msg.value) to WETH (ERC20)
        /// [Note]: Converted amountETH is equal to "msg.value"
        _wETH.deposit();

        /// Approve token for UniswapV2Routor02
        _TokenA.approve(_UNISWAP_V2_ROUTER_02, erc20AmountDesired_);

        /// Add liquidity and pair
        uint erc20Amount;
        uint ETHAmount;
        uint liquidity;
        (erc20Amount, ETHAmount, liquidity) = _addLiquidityWithETH(erc20AmountDesired_, ETHAmountMin);

        /// Back LPtoken to a staker
        return pair_.transfer(msg.sender, liquidity);
    }

    function _addLiquidityWithETH(/// [Note]: This internal method is added for avoiding "Stack too deep"
        uint erc20AmountDesired_,
        uint ETHAmountMin_
    ) internal returns (uint _erc20Amount, uint _ETHAmount, uint _liquidity) {
        uint erc20Amount;
        uint ETHAmount;
        uint liquidity;

        address to = msg.sender;
        uint deadline = now.add(300 seconds);
        (erc20Amount, ETHAmount, liquidity) = _uniswapV2Router02.addLiquidityETH(_TKA_TOKEN,
            erc20AmountDesired_,
            erc20AmountDesired_,
            ETHAmountMin_,
            to,
            deadline);

        return (erc20Amount, ETHAmount, liquidity);
    }

    function removeLiquidityWithETH(address payable staker_, uint lpTokenAmountUnStaked_) public {
        /// Remove liquidity that a staker was staked
        uint erc20TokenAmount;
        uint ETHAmount;
        /// WETH
        uint erc20TokenMin = 0;
        uint ETHAmountMin = 0;
        /// WETH
        address to = staker_;
        uint deadline = now.add(15 seconds);
        (erc20TokenAmount, ETHAmount) = _uniswapV2Router02.removeLiquidityETH(_TKA_TOKEN,
            lpTokenAmountUnStaked_,
            erc20TokenMin,
            ETHAmountMin,
            to,
            deadline);

        /// Convert WETH to ETH
        _wETH.withdraw(ETHAmount);

        /// Transfer Token A and ETH + fees earned (into a staker)
        _TokenA.transfer(staker_, erc20TokenAmount);
        return staker_.transfer(ETHAmount);
    }

    function stakeLPToken(IUniswapV2Pair pair_, uint amount_) public {
        // Require amount greater than 0
        require(amount_ > 0, "amount cannot be 0");

        // Trasnfer LP tokens to this contract for staking
        pair_.transferFrom(msg.sender, address(this), amount_);

        // Update staked balance
        _stakedBalance[msg.sender] = _stakedBalance[msg.sender] + amount_;

        // Add user to stakers array *only* if they haven't staked already
        if (!_hasStaked[msg.sender]) {
            _stakers.push(msg.sender);
        }

        // Update staking status
        _isStaking[msg.sender] = true;
        _hasStaked[msg.sender] = true;

        // update totals
        _totalStakedLPTokenAmount = _totalStakedLPTokenAmount + amount_;
        _currentlyStakedLPTokenAmount = _currentlyStakedLPTokenAmount + amount_;
    }

    function issueRewards() public onlyOwner {
        // Issue tokens to all stakers
        for (uint i = 0; i < _stakers.length; i++) {
            address recipient = _stakers[i];
            uint balance = _stakedBalance[recipient];
            if (balance > 0) {
                _stakingBalance[recipient] = _stakingBalance[recipient] + balance;
            }
        }
    }

    function unstakeTokens(IUniswapV2Pair pair_) public {
        // Fetch staking balance
        uint balance = _stakedBalance[msg.sender];

        // Require amount greater than 0
        require(balance > 0, "staking balance cannot be 0");

        // Transfer LP Tokens back to staker
        pair_.transfer(msg.sender, balance);

        // Transfer unclaimed reward tokens
        uint rewardBalance = _stakingBalance[msg.sender];
        if (rewardBalance > 0) {
            _RewardToken.transfer(msg.sender, _stakingBalance[msg.sender]);
        }

        // Reset staking balance
        _stakingBalance[msg.sender] = 0;
        _stakedBalance[msg.sender] = 0;

        // Update staking status
        _isStaking[msg.sender] = false;

        // update current total
        _currentlyStakedLPTokenAmount = _currentlyStakedLPTokenAmount - balance;
    }
}
