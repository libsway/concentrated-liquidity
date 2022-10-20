library ticks;

use core::num::*;
use std::{
    math::*, 
    u128::*, 
    u256::*
};

use I24::*;
use tick_math::*;

//need to create U128 tick cast function in tick_math to clean up implementation
pub fn max_liquidity(tick_spacing: u32) -> U128 {
    //max U128 range
    let max_u128 = ~U128::max();

    //cast max_tick to U128
    let max_tick_i24 = ~I24::max();
    let max_tick_u32 = max_tick_i24.abs();
    let max_tick_u64: u64 = max_tick_u32;
    let max_tick_u128: ~U128::from(0, max_tick_u64);

    //cast tick_spacing to U128
    let tick_spacing_u64: u64 = tick_spacing;
    let tick_spacing_u128: ~U128::from(0, tick_spacing_64);

    //liquidity math
    let double_tick_spacing = tick_spacing_u128 * ~U128::from(0,2);
    let range_math = max_u128 / max_tick_u128;
    let liquidity_math = range_math / double_tick_spacing;

    liquidity_math
}