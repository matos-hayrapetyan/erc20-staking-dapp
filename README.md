# ERC20 Stake Pool

***
## 【Introduction of ERC20 Stake Pool】
- This is a smart contract in order to provide the opportunity of yield farming for TKA token holders. (By staking uniswap-LP tokens that is a pair between TKA and ETH into the stake pool)

***

## 【Workflow】
- ① Create UniswapV2-Pool between TKA token and ETH. (Add Liquidity)
- ② Create UNI-V2 LP tokens (TKA-ETH).
- ③ Stake UNI-V2 LP tokens (TKA-ETH) into the TKA stake pool contract.
- ④ Smart contract (the ERC20 stake pool contract) automatically generate rewards by schedule.
    - The `RewardToken (RWD)` is generated as rewards.
    - Current formula of generating rewards is that:
        - 100% of staked UNI-V2 LP tokens (TKA-ETH) amount in a week is generated each week.
        - Staker can receive rewards ( `RewardToken` ) depends on their `share of pool` when they claim rewards.
- ⑤ Claim rewards and distributes rewards into claimed-staker.
  (or, Un-Stake UNI-V2 LP tokens. At that time, claiming rewards will be executed at the same time)
  
- Diagram of workflow.![scheme](https://user-images.githubusercontent.com/16697678/116536664-4223dd80-a8f6-11eb-8205-8610b4bfafa4.jpg)



***

## 【Technical Stack】
- Solidity (Solc): v0.6.6
- Truffle: v5.3.2
- Node.js: v12.6.3

## 【Setup】
### ① Install modules
```
$ npm install
```

### ② Add `secrets.json` to the root directory.
- Please reference `secrets.example.json` to create `secrets.json`

### ③ Compile & migrate contracts (on Ropsten testnet)
```
$ npm run migrate:ropsten
```
