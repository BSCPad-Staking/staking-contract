pragma solidity 0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";

// import "@nomiclabs/buidler/console.sol";

contract PadStaking is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 lastStakedTimestamp;
        uint256 totalReward;
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. BSCPADs to distribute per block.
        uint256 lastRewardBlock; // Last block number that BSCPADs distribution occurs.
        uint256 accBSCPADPerShare; // Accumulated BSCPADs per share, times 1e12. See below.
    }

    // The BSCPAD TOKEN!
    IBEP20 public bscpad;
    // Dev address.
    address public devaddr;
    // Rinter address.
    address public rewarder;
    // BSCPAD tokens created per block.
    uint256 public bscpadPerBlock;
    // Bonus muliplier for early bscpad makers.
    uint256 public BONUS_MULTIPLIER = 1;

    // Total Reward
    uint256 public totalReward;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when BSCPAD mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(
        IBEP20 _bscpad,
        address _devaddr,
        address _rewarderaddr,
        uint256 _bscpadPerBlock,
        uint256 _startBlock
    ) public {
        bscpad = _bscpad;
        devaddr = _devaddr;
        bscpadPerBlock = _bscpadPerBlock;
        startBlock = _startBlock;
        rewarder = _rewarderaddr;

        // staking pool
        poolInfo.push(
            PoolInfo({
                lpToken: _bscpad,
                allocPoint: 1000,
                lastRewardBlock: startBlock,
                accBSCPADPerShare: 0
            })
        );

        totalAllocPoint = 1000;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            points = points.div(3);
            totalAllocPoint = totalAllocPoint.sub(poolInfo[0].allocPoint).add(
                points
            );
            poolInfo[0].allocPoint = points;
        }
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending BSCPADs on frontend.
    function pendingBscpad(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][_user];
        uint256 accBSCPADPerShare = pool.accBSCPADPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 bscpadReward =
                multiplier.mul(bscpadPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accBSCPADPerShare = accBSCPADPerShare.add(
                bscpadReward.mul(1e12).div(lpSupply)
            );
        }
        return
            user.amount.mul(accBSCPADPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        PoolInfo storage pool = poolInfo[0];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 bscpadReward =
            multiplier.mul(bscpadPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        totalReward = totalReward.add(bscpadReward);

        pool.accBSCPADPerShare = pool.accBSCPADPerShare.add(
            bscpadReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Stake BSCPAD tokens to PadStaking
    function enterStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool();
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accBSCPADPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            if (pending > 0) {
                addUserReward(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accBSCPADPerShare).div(1e12);

        emit Deposit(msg.sender, _amount);
    }

    // Withdraw BSCPAD tokens from STAKING.
    function leaveStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();
        uint256 pending =
            user.amount.mul(pool.accBSCPADPerShare).div(1e12).sub(
                user.rewardDebt
            );
        if (pending > 0) {
            // safeBscpadTransfer(msg.sender, pending);
            addUserReward(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accBSCPADPerShare).div(1e12);

        // poolBar.burn(msg.sender, _amount);
        addUserReward(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe bscpad transfer function, just in case if rounding error causes pool to not have enough BSCPADs.
    function safeBscpadTransfer(address _to, uint256 _amount) internal {
        bscpad.transfer(_to, _amount);
    }

    function addUserReward(address _sender, uint256 amount) internal {
        UserInfo storage user = userInfo[0][_sender];
        user.totalReward = user.totalReward.add(amount);
    }

    function rewardOf(address _sender) public view returns (uint256) {
        UserInfo storage user = userInfo[0][_sender];
        return user.totalReward;
    }

    function totalRewards() public view returns (uint256) {
        return totalReward;
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}
