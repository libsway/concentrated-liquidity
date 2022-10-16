library tick_math;

dep I24;
dep Q64x64;

use I24::I24;
use std::{
    u128::*,
    result::Result,
};
use I24::{neg_from};

const MIN_TICK = ~I24::neg_from(MAX_TICK);

const MAX_TICK = I24 {
    underlying: 887272
};

// const MIN_SQRT = ~Q64x64 {
//     value: get_price_at_tick(MIN_TICK)
// }

// const MAX_SQRT = ~Q64x64 {
//     value: get_price_at_tick(MAX_TICK)
// }

pub fn get_price_at_tick(tick: I24) {
    let absTick: u32 = tick.abs();
}

