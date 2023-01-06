library events;

use std::{identity::Identity, contract_id::ContractId, u128::U128};
use cl_libs::Q64x64::Q64x64;
use cl_libs::I24::I24;

pub struct InitEvent {
    pool_id: ContractId,
    token0: ContractId,
    token1: ContractId,
    swap_fee: u64,
    tick_spacing: u32,
    init_price_upper: u64,
    init_price_lower: u64,
    init_tick: u32
}

pub struct SwapEvent {
    pool: ContractId,
    sender: Identity,
    recipient: Identity,
    token0_amount: u64,
    token1_amount: u64,
    liquidity: U128,
    tick: I24,
    sqrt_price: Q64x64
}

pub struct MintEvent {
    pool: ContractId,
    sender: Identity,
    recipient: Identity,
    token0_amount: u64,
    token1_amount: u64,
    liquidity_minted: U128,
    tick_lower: I24,
    tick_upper: I24
}

pub struct BurnEvent {
    pool: ContractId,
    sender: Identity,
    token0_amount: u64,
    token1_amount: u64,
    liquidity_burned: U128,
    tick_lower: I24,
    tick_upper: I24
}

pub struct FlashEvent {
    fee_growth_global0: Q64x64,
    fee_growth_global1: Q64x64
}