library tick_delta_math;

use core::num::*;
use std::{
    u128::*,
    assert::assert,
    math::*,
};

// Returns the delta sum for given liquidity
// need to create I128 lib if we are going to use this
fn delta_math (liquidity: U128, delta: U128) -> U128 {
    let delta_sum = liquidity + delta;
    let delta_sub = liquidity - delta;

    if delta < (U128{upper:0,lower:0}) {
    //Panic if condition not met    
        assert(delta_sub < liquidity);
        return delta_sub;
    } 

    else {
    //Panic if condition not met
        assert((delta_sum > liquidity) || (delta_sum == liquidity));
        return delta_sum;
    }
}
    
