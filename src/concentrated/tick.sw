library ticks;

dep I24;
dep tick_math;

use core::num::*;
use core::ops::*;

use std::{
    math::*, 
    u128::*, 
    u256::*,
    storage::StorageMap
};

use I24::*;
use tick_math::*;

//modulo for I24
impl core::ops::Mod for I24{
    fn modulo(self, other: I24) -> I24 {
        return (self - other * (self / other));
    }
}

pub struct Tick {
    prev_tick: I24,
    next_tick: I24,
    liquidity: U128,
    fee_growth_outside0: u64,
    fee_growth_outside1: u64,
    seconds_growth_outside: U128
}

fn empty_tick() -> Tick {
    Tick {
        prev_tick: ~I24::from_uint(0),
        next_tick: ~I24::from_uint(0),
        liquidity: ~U128::from(0,0),
        fee_growth_outside0: 0,
        fee_growth_outside1: 0,
        seconds_growth_outside: ~U128::from(0,0)
    }
}

// Downcast from u64 to u32, losing precision
fn u64_to_u32(a: u64) -> u32 {
    let result: u32 = a;
    result
}

//need to create U128 tick cast function in tick_math to clean up implementation
pub fn max_liquidity(tick_spacing: u32) -> U128 {
    //max U128 range
    let max_u128 = ~U128::max();

    //cast max_tick to U128
    let max_tick_i24 = ~I24::max();
    let max_tick_u32 = max_tick_i24.abs();
    let max_tick_u64: u64 = max_tick_u32;
    let max_tick_u128 = ~U128::from(0, max_tick_u64);

    //cast tick_spacing to U128
    let tick_spacing_u64: u64 = tick_spacing;
    let tick_spacing_u128 = ~U128::from(0, tick_spacing_u64);

    //liquidity math
    let double_tick_spacing = tick_spacing_u128 * ~U128::from(0,2);
    let range_math = max_u128 / max_tick_u128;
    let liquidity_math = range_math / double_tick_spacing;

    liquidity_math
}
//TODO: do we need read permission?
#[storage(read, write)]
fn tick_cross(
    ref mut ticks: StorageMap<I24, Tick>,
    ref mut next: I24, 
    fee_growth_time: U256, ref mut liquidity: U128, 
    seconds_growth_global: U256, fee_growth_globalA: U128,
    fee_growth_globalB: U128, 
    tick_spacing: I24, spacing: I24,
    token_zero_to_one: bool
) -> (U128, I24) {
    //get seconds_growth from next in StorageMap
    let mut stored_tick = ticks.get(next);
    let outside_growth = ticks.get(next).seconds_growth_outside;

    //cast outside_growth into U256
    let seconds_growth_outside = ~U256::from(0,0,outside_growth.upper,outside_growth.lower);

    //do the math, downcast to U128, store in ticks
    let outside_math: U256 = seconds_growth_global - seconds_growth_outside;
    let outside_downcast = ~U128::from(outside_math.c, outside_math.d);
    stored_tick.seconds_growth_outside = outside_downcast;
    ticks.insert(next, stored_tick);

    let modulo_re_to24 = ~I24::from_uint(2);
    let i24_zero = ~I24::from_uint(0);

    if token_zero_to_one {
        if ((next / tick_spacing) % modulo_re_to24) == i24_zero {
            liquidity -= ticks.get(next).liquidity;
        } else{
            liquidity += ticks.get(next).liquidity;
        }
        //change fee growth values, push onto storagemap
        let mut new_stored_tick: Tick = ticks.get(next);
        new_stored_tick.fee_growth_outside0 = fee_growth_globalB - new_stored_tick.fee_growth_outside0;
        new_stored_tick.fee_growth_outside1 = fee_growth_globalA - new_stored_tick.fee_growth_outside1;
        ticks.insert(next, new_stored_tick);

        //change input tick to previous tick
        next = ticks.get(next).prev_tick;    
    }
    
    else {
        if ((next / tick_spacing) % modulo_re_to24) == i24_zero {
            liquidity += ticks.get(next).liquidity;
        } else{
            liquidity -= ticks.get(next).liquidity;
        }
        
        //change fee growth values, push onto storagemap
        let mut new_stored_tick: Tick = ticks.get(next);
        new_stored_tick.fee_growth_outside0 = fee_growth_globalB - new_stored_tick.fee_growth_outside1;
        new_stored_tick.fee_growth_outside1 = fee_growth_globalA - new_stored_tick.fee_growth_outside0;
        ticks.insert(next, new_stored_tick);

        //change input tick to previous tick
        next = ticks.get(next).prev_tick;
        
    }
    (liquidity, next)
}

#[storage(read, write)]
fn tick_insert(
    ref mut ticks: StorageMap<I24, Tick>,
    fee_growth_global0: U128, fee_growth_global1: U128,  
    seconds_growth_global: U128, current_price: Q64x64,
    amount: U128,  ref mut nearest: I24,
    above: I24, below: I24, 
    prev_above: I24, prev_below: I24
) -> I24 {
    // check inputs
    assert(below < above);
    assert(below > MIN_TICK() || below == MIN_TICK());
    assert(above < MAX_TICK() || above == MAX_TICK());
    
    let mut below_tick = ticks.get(below);

    if below_tick.liquidity != ~U128::from(0,0) || below == MIN_TICK() {
        // tick has already been initialized
        below_tick.liquidity += amount;
        ticks.insert(below, below_tick);
    } else {
        // tick has not been initialized
        let mut prev_tick = ticks.get(prev_below);
        let prev_next = prev_tick.next_tick;
        
        // check below ordering
        assert(prev_tick.liquidity != ~U128::from(0,0) || prev_below == MIN_TICK());
        assert(prev_below < below && below < prev_above);
        
        if below < nearest || below == nearest {
            ticks.insert(below, Tick {
                prev_tick: prev_below,
                next_tick: prev_next,
                liquidity: amount,
                fee_growth_outside0: fee_growth_global0,
                fee_growth_outside1: fee_growth_global1,
                seconds_growth_outside: seconds_growth_global
            });
        } else {
            ticks.insert(below, Tick {
                prev_tick: prev_below,
                next_tick: prev_next,
                liquidity: amount,
                fee_growth_outside0: 0,
                fee_growth_outside1: 0,
                seconds_growth_outside: ~U128::from(0,0)
            });
        }
        prev_tick.next_tick = below;
        ticks.insert(prev_next, prev_tick);
    }

    let mut above_tick = ticks.get(above);

    if above_tick.liquidity != ~U128::from(0,0) || above == MAX_TICK() {
        above_tick.liquidity += amount;
        ticks.insert(above, above_tick);
    } else {
        let mut prev_tick = ticks.get(prev_above);
        let mut prev_next = prev_tick.next_tick;

        // check above order
        assert(prev_tick.liquidity != ~U128::from(0,0));
        assert(prev_next > above);
        assert(prev_above < above);

        if above < nearest || above == nearest {
            ticks.insert(above, Tick {
                prev_tick: prev_above,
                next_tick: prev_next,
                liquidity: amount,
                fee_growth_outside0: fee_growth_global0.d,
                fee_growth_outside1: fee_growth_global1.d,
                seconds_growth_outside: seconds_growth_global
            });
        } else {
            ticks.insert(above, Tick {
                prev_tick: prev_above,
                next_tick: prev_next,
                liquidity: amount,
                fee_growth_outside0: 0,
                fee_growth_outside1: 0,
                seconds_growth_outside: ~U128::from(0,0)
            });
        }
        prev_tick.next_tick = above;
        ticks.insert(prev_above, prev_tick);
        let prev_next_tick = ticks.get(prev_next);
        prev_next_tick.prev_tick = above;
        ticks.insert(prev_next, prev_next_tick);
    }

    let tick_at_price: I24 = fget_tick_at_price(current_price);

    let above_is_between: bool = nearest < above && (above < tick_at_price || above == tick_at_price);
    let below_is_between: bool = nearest < below && (below < tick_at_price || below == tick_at_price);
    
    if above_is_between {
        nearest = above;
    } else if below_is_between {
        nearest = below;
    }

    nearest
}

#[storage(read, write)]
fn tick_remove(
    ref mut ticks: StorageMap<I24, Tick>,
    below: I24, above: I24,
    ref mut nearest: I24,
    amount: U128
) -> I24 {
    let mut current_tick = ticks.get(below);
    let mut prev = current_tick.prev_tick;
    let mut next = current_tick.next_tick;
    let mut prev_tick = ticks.get(prev);
    let mut next_tick = ticks.get(next);

    if below != MIN_TICK() && current_tick.liquidity == amount {
        // clear below tick from storage
        prev_tick.next_tick = current_tick.next_tick;
        next_tick.prev_tick = current_tick.prev_tick;

        if nearest == below {
            nearest = current_tick.prev_tick;
        }
        
        ticks.insert(below, empty_tick());
        ticks.insert(prev, prev_tick);
        ticks.insert(next, next_tick);

    } else {
        current_tick.liquidity += amount;
        ticks.insert(below, current_tick);
    }

    current_tick = ticks.get(above);
    prev = current_tick.prev_tick;
    next = current_tick.next_tick;
    prev_tick = ticks.get(prev);
    next_tick = ticks.get(next);

    if above != MAX_TICK() && current_tick.liquidity == amount {
        // clear above tick from storage
        prev_tick.next_tick = next;
        next_tick.prev_tick = prev;

        if nearest == above {
            nearest = current_tick.prev_tick;
        }

        ticks.insert(above, empty_tick());
        ticks.insert(prev, prev_tick);
        ticks.insert(next, next_tick);

    } else {
        current_tick.liquidity -= amount;
        ticks.insert(above, current_tick);
    }

    nearest
}