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
#[storage(read, write)]
pub fn max_liquidity(tick_spacing: I24) -> U128 {
    //max U128 range
    let max_range = ~U128::max();

    //cast max_tick to U128
    let max_tick24 = ~I24::max();
    let max_tick_cast32 = ~I24::into(max_tick24);
    let max_tick_cast64: u64 = max_tick_cast32;
    let max_tick_cast128: ~U128::from(0, max_tick_cast64);

    //cast tick_spacing to U128
    let tick_spacing_32 = ~I24::into(tick_spacing);
    let tick_spacing_64: u64 = tick_spacing_32;
    let tick_spacing_128: ~U128::from(0, tick_spacing_64);

    //liquidity math
    let double_tick_spacing = 2 * tick_spacing_128;
    let range_math = max_range / max_tick_cast128;
    let liquidity_math = range_math / double_tick_spacing;
    //assigning value to struct
    U128 {
        upper: liquidity_math,
        lower: 0
    }

}