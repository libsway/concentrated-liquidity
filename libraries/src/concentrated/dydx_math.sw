library dydx_math;

dep full_math;

use full_math::{
    mul_div,
    mul_div_q64x64,
    mul_div_rounding_up_u128,
    mul_div_rounding_up_q64x64,
    mul_div_rounding_up_u256,
    mul_div_u256,
};
use ::Q64x64::Q64x64;
use std::u256::U256;
use std::u128::U128;

#[test]
pub fn dydx_math_get_dy() -> u64 {
    get_dy(
        U128::from((1_000_000_000,0)),
        Q64x64{value: U128::from((5000,0))},
        Q64x64{value: U128::from((1000,0))},
        false
    )
}
// Obligatory note on liquidity
// Note that dydx math is implicitly expecting a Q.
pub fn get_dy(
    liquidity: U128,
    price_upper: Q64x64,
    price_lower: Q64x64,
    round_up: bool,
) -> u64 {
    let PRECISION: U128 = U128 {
        upper: 1,
        lower: 0,
    };
    let mut dy = U128 {
        upper: 0,
        lower: 0
    };
    // return (price_upper - price_lower).u128() * liquidity / PRECISION;
    if round_up {   
        //dy = mul_div_rounding_up_u64(liquidity, (price_upper - price_lower).u128(), PRECISION);
        dy = U128::from((0,1));
    } else {
        dy = mul_div(liquidity, (price_upper - price_lower).u128(), PRECISION);
    }
    dy.lower
}

#[test]
fn dydx_math_get_dx() -> u64 {
    get_dx(
        U128::from((0,1_000_000_000)),
        Q64x64{value: U128::from((5000,0))},
        Q64x64{value: U128::from((1000,0))},
        false
    )
}

pub fn get_dx(
    liquidity: U128,
    price_upper: Q64x64,
    price_lower: Q64x64,
    round_up: bool,
) -> u64 {
    let PRECISION_BITS: u64 = 64;
    let mut dx: U128 = U128 {
        upper: 0,
        lower: 0,
    };
    if round_up {
        dx = mul_div_rounding_up_u256(U256::from((0, 0, liquidity.upper, liquidity.lower)) << PRECISION_BITS, (price_upper - price_lower).u128(), price_upper.u128());
        if dx % price_lower.u128() == (U128 {
                upper: 0,
                lower: 0,
            })
        {
            dx = dx / price_lower.u128();
        } else {
            dx = (dx / price_lower.u128()) + U128 {
                upper: 0,
                lower: 1,
            };
        }
    } else {
        dx = mul_div_u256(U256 {
            a: 0,
            b: 0,
            c: liquidity.upper,
            d: liquidity.lower,
        } << PRECISION_BITS, (price_upper - price_lower).u128(), price_upper.u128()) / price_lower.u128();
    }
    dx.lower
}

#[test]
fn dydx_math_get_liquidity_for_amounts() -> U128 {
    get_liquidity_for_amounts(
        Q64x64{value: U128::from((5000,0))},
        Q64x64{value: U128::from((1000,0))},
        Q64x64{value: U128::from((5000,0))},
        U128::from((0,1_000_000_000_000)),
        U128::from((0,0))
    )
}

pub fn get_liquidity_for_amounts(
    price_lower: Q64x64,
    price_upper: Q64x64,
    current_price: Q64x64,
    dy: U128,
    dx: U128,
) -> U128 {
    let PRECISION: U128 = U128 {
        upper: 0,
        lower: u64::max(),
    };
    let mut liquidity: U128 = U128 {
        upper: 0,
        lower: 0,
    };
    if price_upper < current_price
        || price_upper == current_price
    {
        liquidity = mul_div(dy, PRECISION, (price_upper - price_lower).u128());
    } else if current_price == price_lower
        || current_price < price_lower
    {
        liquidity = mul_div(dx, mul_div(price_lower.u128(), price_upper.u128(), PRECISION), (price_upper - price_lower).u128());
    } else {
        let liquidity0 = mul_div(dx, mul_div(price_upper.u128(), current_price.u128(), PRECISION), (price_upper - current_price).u128());
        let liquidity1 = mul_div(dy, PRECISION, (current_price - price_lower).u128());
        if liquidity0 < liquidity1 {
            liquidity = liquidity0;
        } else {
            liquidity = liquidity1;
        }
    }
    liquidity
}

#[test]
pub fn dydx_math_get_amounts_for_liquidity() -> (u64, u64) {
    get_amounts_for_liquidity(
        Q64x64{value: U128::from((5000,0))},
        Q64x64{value: U128::from((1000,0))},
        Q64x64{value: U128::from((5000,0))},
        U128::from((0,1_000_000_000_000)),
        false
    )
}

pub fn get_amounts_for_liquidity(
    price_upper: Q64x64,
    price_lower: Q64x64,
    current_price: Q64x64,
    liquidity_amount: U128,
    round_up: bool,
) -> (u64, u64) {
    let mut token1_amount: u64 = 0;
    let mut token0_amount: u64 = 0;
    if price_upper < current_price
        || price_upper == current_price
    {
        // Only supply `token1` (`token1` is Y).
        token1_amount = get_dy(liquidity_amount, price_upper, price_lower, round_up);
    } else if (current_price < price_lower)
        || (current_price < price_lower)
    {
        token0_amount = get_dx(liquidity_amount, price_upper, price_lower, round_up);
    } else {
        token0_amount = get_dx(liquidity_amount, price_upper, price_lower, round_up);
        token1_amount = get_dy(liquidity_amount, price_upper, price_lower, round_up);
    }
    (token0_amount, token1_amount)
}
