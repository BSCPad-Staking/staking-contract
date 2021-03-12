pragma solidity 0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";

// import "@nomiclabs/buidler/console.sol";

interface IMigratorPad {
    function migrate(IBEP20 token) external returns (IBEP20);
}

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
    // The SYRUP TOKEN!
    IBEP20 public poolBar;
    // Dev address.
    address public devaddr;
    // Minter address.
    address payable public minter;
    // BSCPAD tokens created per block.
    uint256 public bscpadPerBlock;
    // Bonus muliplier for early bscpad makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorPad public migrator;

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

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        IBEP20 _bscpad,
        IBEP20 _poolBar,
        address _devaddr,
        uint256 _bscpadPerBlock,
        uint256 _startBlock
    ) public {
        bscpad = _bscpad;
        poolBar = _poolBar;
        devaddr = _devaddr;
        bscpadPerBlock = _bscpadPerBlock;
        startBlock = _startBlock;
        minter = msg.sender;

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

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IBEP20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accBSCPADPerShare: 0
            })
        );
        updateStakingPool();
    }

    // Update the given pool's BSCPAD allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(
                _allocPoint
            );
            updateStakingPool();
        }
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

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorPad _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IBEP20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IBEP20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
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
    function pendingBscpad(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
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

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
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
        updatePool(0);
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

        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw BSCPAD tokens from STAKING.
    function leaveStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
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
        emit Withdraw(msg.sender, 0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
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
