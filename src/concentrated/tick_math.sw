library tick_math;

dep I24;
dep Q64x64;

use I24::I24;
use I24::neg_from;
use std::{
    u128::*,
    result::Result,
};
use Q64x64::Q64x64;

const MAX_TICK = I24 {
    underlying: 887272
};

const MIN_TICK = I24 {
    underlying: neg_from(MAX_TICK)
};

const MIN_SQRT = Q64x64 {
    value: ~Q64x64::from(get_price_at_tick(MIN_TICK))
};

const MAX_SQRT = Q64x64 {
    value: ~Q64x64::from(get_price_at_tick(MAX_TICK))
};

pub fn get_price_at_tick(tick: I24) -> u32 {
    let absTick = ~I24::into(tick.abs());
    return absTick;
}

