contract;

dep libs;

use core::num::*;

use std::{
    revert::require,
    identity::ContractId,
    token::transfer,
    identity::Identity,
    U128::u128,
    storage::StorageMap,
};

use concentrated_liquidity_libs::I24;
use concentrated_liquidity_libs::Q64x64;

pub enum TridentErrors {
    Locked: (),
    ZeroAddress: (),
    InvalidToken: (),
    InvalidSwapFee: (),
    LiquidityOverflow: (),
    Token0Missing: (),
    Token1Missing: (),
    InvalidTick: (),
    LowerEven: (),
    UpperOdd: (),
    MaxTickLiquidity: (),
    Overflow: (),
}

struct Tick {
    previous_tick: I24,
    next_tick: I24,
    liquidity: U128,
    fee_growth_outside0: u64,
    fee_growth_outside1: u64,
    seconds_growth_outside: U128
}

struct Position {
    liquidity: U128,
    fee_growth_inside0: u64,
    fee_growth_inside1: u64,
}

abi ConcentratedLiquidityPool {
    // Core functions
    #[storage(read, write)]
    fn set_price(price : U128);

    #[storage(read, write)]
    fn mint(lower_old: I24, lower: I24, upper_old: I24, upper: I24, amount0_desired: u64, amount1_desired: u64) -> U128;

    #[storage(read, write)]
    fn collect(tickLower: I24, tickUpper: I24) -> (u64, u64);

    #[storage(read, write)]
    fn burn(lower: I24, upper: I24, amount: u64) -> (u64, u64, u64, u64);
}

// Should be all storage variables
storage {
    token0: ContractId = ~ContractId::from(0x0000000000000000000000000000000000000000000000000000000000000000),
    token1: ContractId = ~ContractId::from(0x0000000000000000000000000000000000000000000000000000000000000000),

    max_fee: u32 = 100000,
    tick_spacing: u32 = 10, // implicitly a u24
    swap_fee: u32 = 2500,
    
    bar_fee_too: Identity = ~Identity::ContractId::from(0x0000000000000000000000000000000000000000000000000000000000000000),

    liquidity: U128 = 0;

    seconds_growth_global: U128 = ~U128::from(0, 0);
    last_observation: u32 = 0,

    fee_growth_global0: u64 = 0,
    fee_growth_global1: u64 = 0,

    bar_fee: u64 = 0,

    token0_protocol_fee: u64 = 0,
    token1_protocol_fee: u64 = 0,

    reserve0: u64 = 0,
    reserve1: u64 = 0,

    price: Q64x64 = ~Q64x64::from_uint; // Orginally Sqrt of price aka. √(y/x), multiplied by 2^64.
    neatest_tick: I24 = ~I24::from_uint(0); 

    unlocked: bool = false,

    ticks: StorageMap<I24, Tick> = (),
    positions: StorageMap<Identity, StorageMap<I24, Position>> = (),
}

impl ConcentratedLiquidityPool for contract {

}


