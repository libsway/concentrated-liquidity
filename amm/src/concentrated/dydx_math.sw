library dydx_math;

dep full_math;
dep Q64x64;

use full_math::*;
use Q64x64::*;
use std::u256::U256;
use std::u128::*;


// Obligatory note on liquidity
// Note that dydx math is implicitly expecting a Q.
pub fn get_dy(
    liquidity: U128,
    price_upper: Q64x64,
    price_lower: Q64x64,
    round_up: bool,
) -> U128 {
    let PRECISION: U128 = ~U128::from(0, ~u64::max());
    let mut dy: U128 = ~U128::from(0, 0);
    if round_up {
        dy = mul_div_rounding_up(liquidity, (price_upper - price_lower).u128(), PRECISION);
    } else {
        dy = mul_div(liquidity, (price_upper - price_lower).u128(), PRECISION);
    }

    dy
}
pub fn get_dx(
    liquidity: U128,
    price_upper: Q64x64,
    price_lower: Q64x64,
    round_up: bool,
) -> U128 {
    let PRECISION_BITS: u64 = 64;
    let mut dx: U128 = ~U128::from(0, 0);
    if round_up {
        dx = mul_div_rounding_up_u256(~U256::from(0, 0, liquidity.upper, liquidity.lower) << PRECISION_BITS, (price_upper - price_lower).u128(), price_upper.u128());
        if dx % price_lower.u128() == ~U128::from(0, 0) {
            dx = dx / price_lower.u128();
        } else {
            dx = (dx / price_lower.u128()) + ~U128::from(0, 1);
        }
    } else {
        dx = mul_div_u256(~U256::from(0, 0, liquidity.upper, liquidity.lower) << PRECISION_BITS, (price_upper - price_lower).u128(), price_upper.u128()) / price_lower.u128();
    }
    dx
}
pub fn get_liquidity_for_amounts(
    price_lower: Q64x64,
    price_upper: Q64x64,
    current_price: Q64x64,
    dy: U128,
    dx: U128,
) -> U128 {
    let PRECISION: U128 = ~U128::from(0, ~u64::max());
    let mut liquidity: U128 = ~U128::from(0, 0);
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
        token1_amount = get_dy(liquidity_amount, price_upper, price_lower, round_up).as_u64().unwrap();
    } else if (current_price < price_lower)
        || (current_price < price_lower)
    {
        token0_amount = get_dx(liquidity_amount, price_upper, price_lower, round_up).as_u64().unwrap();
    } else {
        token0_amount = get_dx(liquidity_amount, price_upper, price_lower, round_up).as_u64().unwrap();
        token1_amount = get_dy(liquidity_amount, price_upper, price_lower, round_up).as_u64().unwrap();
    }
    (token0_amount, token1_amount)
}
