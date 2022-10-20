library ticks;

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
use pool::{Tick};

//modulo for I24
impl core::ops::Mod for I24{
    fn modulo(self, other: I24) -> I24 {
        return (self - other * (self / other));
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
//TODO: do we need read permission?
#[storage(read, write)]
fn tick_cross(
    ticks_map: StorageMap<I24, Tick>,
    mut next_tick: I24, 
    fee_growth_time: U256, mut liquidity: U256, 
    seconds_growth_global: U256, fee_growth_globalA: U256,
    fee_growth_globalB: U256, 
    tick_spacing: I24, spacing: I24,
    token_zero_to_one: bool
) -> (U128, I24) {
    //get seconds_growth from next_tick in StorageMap
    let stored_tick: Tick = ticks_map.get(next_tick);
    let outside_growth: U128 = ticks_map.get(next_tick).seconds_growth_outside;

    //cast outside_growth into U256
    let outside_cast256 = ~U256::from(0, outside_growth);

    //do the math, downcast to U128, store in ticks_map
    let outside_math: U256 = outside_cast256 - seconds_growth_global;
    let outside_downcast = ~U128::from(outside_math.c, outside_math.d);
    stored_tick.seconds_growth_outside = outside_downcast;
    ticks_map.insert(next_tick, stored_tick);
    
    
    if token_zero_to_one {
        let modulo_re_to24 = ~I24::from(0, 2);
        if ((next_tick / tick_spacing) % modulo_re_to24) == 0 {
            liquidity = liquidity + 

        }
        
        else{
            
        }

        //change fee growth values, push onto storagemap
        let new_stored_tick: Tick = ticks_map.get(next_tick);
        new_stored_tick.fee_growth_outside0 = fee_growth_globalB - new_stored_tick.fee_growth_outside0;
        new_stored_tick.fee_growth_outside1 = fee_growth_globalA - new_stored_tick.fee_growth_outside1;
        ticks_map.insert(next_tick, new_stored_tick);

        //change input tick to previous tick
        next_tick = ticks_map.get(next_tick).previous_tick;    
    }
    else{
        if ((next_tick / tick_spacing) % modulo_re_to24) == 0 {
            
        }
        
        else{
            
        }
        //change fee growth values, push onto storagemap
        let new_stored_tick: Tick = ticks_map.get(next_tick);
        new_stored_tick.fee_growth_outside0 = fee_growth_globalB - new_stored_tick.fee_growth_outside1;
        new_stored_tick.fee_growth_outside1 = fee_growth_globalA - new_stored_tick.fee_growth_outside0;
        ticks_map.insert(next_tick, new_stored_tick);

        //change input tick to previous tick
        next_tick = ticks_map.get(next_tick).previous_tick; 
        
    }
    (liquidity, next_tick)
    
    
}

#[storage(read, write)]
fn tick_insert(
    ticks: StorageMap<I24, Tick>,
    fee_growth_global0: U256, fee_growth_global1: U256,  
    seconds_growth_global: U256, current_price: U256,
    amount: U128,  nearest_tick: I24
    above_tick: I24, below_tick: I24, 
    prev_above_tick: I24, prev_below_tick: I24
) -> I24 {
    // check inputs
    assert(below_tick < above_tick);
    assert(below_tick > ~tick_math::MIN_TICK() || below_tick == ~tick_math::MIN_TICK());
    assert(above_tick < ~tick_math::MAX_TICK() || above_tick == ~tick_math::MAX_TICK());
    
    below_tick_liquidity: U128 = ticks.get(below_tick).liquidity;

    if below_tick_liquidity != 0 || below_tick == ~tick_math::MIN_TICK() {
        // tick has already been initialized
        ticks[lower].liquidity = below_tick_liquidity + amount;
    } else {
        // tick has not been initialized
        prev_tick = ticks[prev_below_tick];
        prev_next_tick = prev_tick.next_tick;\
        
        // check below ordering
        assert(prev_tick.liquidity != 0 || prev_below_tick == ~tick_math::MIN_TICK());
        assert(prev_below_tick < below_tick && below_tick < prev_above_tick);
        
        if below_tick < nearest_tick || below_tick == nearest_tick {
            ticks[below_tick] = Tick {
                prev_below_tick,
                prev_next_tick,
                amount,
                fee_growth_global0,
                fee_growth_global1,
                seconds_growth_global
            };
        } else {
            ticks[below_tick] = Tick {
                prev_below_tick,
                prev_next_tick,
                amount,
                0,
                0,
                0
            }
        }
        prev_tick.next_tick = below_tick;
        ticks[prev_next_tick].prev_tick = below_tick;
    }

    above_tick_liquidity: U128 = ticks[above_tick].liquidity;

    if above_tick_liquidity != 0 || above_tick == ~tick_math::MAX_TICK() {
        ticks[above_tick].liquidity = above_tick_liquidity
    } else {
        prev_tick = ticks[prev_above_tick];
        prev_next_tick = prev_tick.next_tick;

        // check above order
        assert(prev_tick.liquidity != 0);
        assert(prev_next_tick > above_tick);
        assert(prev_above_tick < above_tick);

        if above_tick < nearest_tick || above_tick == nearest_tick {
            ticks[above_tick] = Tick {
                prev_above_tick,
                prev_next_tick,
                amount,
                fee_growth_global0,
                fee_growth_global1,
                seconds_growth_global
            }
        } else {
            ticks[above_tick] = Tick {
                prev_above_tickm
                prev_next_tick,
                amount,
                0,
                0,
                0
            }
        }
        prev_tick.next_tick = above_tick;
        ticks[prev_next_tick].prev_tick = above_tick;
    }

    tick_at_price: I24 = ~tick_math::get_tick_at_price(current_price);

    above_tick_between: bool = nearest_tick < above_tick && (above_tick < tick_at_price || above_tick == tick_at_price);
    below_tick_between: bool = nearest_tick < below_tick && (below_tick < tick_at_price || below_tick == tick_at_price);
    
    if above_tick_between {
        nearest_tick = above_tick;
    } else if below_tick_between {
        nearest_tick = below_tick;
    }
    
    nearest_tick
}

#[storage(read, write)]
fn tick_remove(
    ticks_map: StorageMap<I24, Tick>, 
    below_tick: I24, above_tick: I24,
    nearest_tick: I24,
    amount: U128
) -> I24 {

}