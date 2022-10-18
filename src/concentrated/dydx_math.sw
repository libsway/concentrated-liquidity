library dydx_math;
dep full_math;
use full_math::{mul_div, mul_div_rounding_up};

use std::u128::U128;

// Obligatory note on liquidity
// Note that dydx math is implicitly expecting a Q.
fn get_dy(
    liquidity: U128,
    price_upper: u64,
    price_lower: u64,
    round_up: bool,
) -> u64 {
    let PRECISION = ~u64::max();
    let mut dy: u64 = 0;
    if round_up {
        dy = mul_div_rounding_up_full(liquidity, ~U128::from(0, price_upper - price_lower), ~U128::from(PRECISION));
    } else {
        dy = mul_div_full(liquidity, ~U128::from(0, price_upper - price_lower), ~U128::from(PRECISION));
    }
    dy
}
fn get_dx(
    liquidity: U128,
    price_upper: u64,
    price_lower: u64,
    round_up: bool,
) -> u64 {
    let PRECISION_BITS: u64 = 64;
    let mut dx: u64 = 0;
    if round_up {
        dx = mul_div_rounding_up_u256(~U256::from(0, 0,liquidity.upper, liquidity.lower) << PRECISION_BITS, price_upper - price_lower, price_upper);
        if dx % price_lower == 0 {
            dx = dx / price_lower;
        } else {
            dx = (dx / price_lower) + 1;
        }
    } else {
        dx = mul_div_u256(~U256::from(0, 0,liquidity.upper, liquidity.lower) << PRECISION_BITS, price_upper - price_lower, price_upper) / price_lower;
    }
    dx
}
fn get_liquidity_for_amounts(
    price_lower: u64,
    price_upper: u64,
    current_price: u64,
    dy: u64,
    dx: u64,
) -> U128 {
    let PRECISION: u64 =  ~u64::max();
    let mut liquidity: U128 = 0;
    if price_upper <= current_price {
        liquidity = mul_div(dy, PRECISION, price_upper - price_lower);
    } else if current_price <= price_lower {
        liquidity = mul_div(dx, mul_div(price_lower, price_upper, PRECISION), price_upper - price_lower);
    } else {
        let liquidity0: u64 = mul_div(dx, mul_div(price_upper, current_price, PRECISION), price_upper - current_price);
        let liquidity1: u64 = mul_div(dy, PRECISION, current_price - price_lower);
        if liquidity0 < liquidity1 {
            liquidity = liquidity0;
        } else {
            liquidity = liquidity1;
        }
    }

    liquidity
}
fn get_amounts_for_liquidity(
    price_upper: u64,
    price_lower: u64,
    current_price: u64,
    liquidity_amount: u64,
    round_up: bool,
) -> (u64, u64) {
    let mut token1_amount: u64 = 0;
    let mut token0_amount: u64 = 0;
    if price_upper <= current_price {
        // Only supply `token1` (`token1` is Y).
        token1_amount = get_dy(liquidity_amount, price_upper, price_lower, round_up);
    } else if current_price <= price_lower {
        token0_amount = get_dx(liquidity_amount, price_upper, price_lower, round_up);
    } else {
        token0_amount = get_dx(liquidity_amount, price_upper, price_lower, round_up);
        token1_amount = get_dy(liquidity_amount, price_upper, price_lower, round_up);
    }
    (token0_amount, token1_amount)
}
