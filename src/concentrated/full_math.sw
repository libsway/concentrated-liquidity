library full_math;

use std::{
    u128::*,
    result::Result,
};
use core::ops::*;

pub enum FullMathError {
    DivisionByZero: (),
}

pub fn mul_div(a : u64, b: u64, denominator : u64) -> u64 {
    require(denominator != 0, FullMathError::DivisionByZero);
    let full_a: U128 = ~U128::from(0, a);
    let full_b: U128 = ~U128::from(0, b);
    let full_denominator: U128 = ~U128::from(0, denominator);

    let result:U128 = (full_a * full_b) / full_denominator;

    return result.as_u64().unwrap(); 
} 

// Unlike recmo's implementation, this is 2x as expensive
pub fn mul_div_rounding_up(a : u64, b: u64, denominator : u64) -> u64 {
    let mut result:u64 = mul_div(a, b, denominator);

    let full_a: U128 = ~U128::from(0, a);
    let full_b: U128 = ~U128::from(0, b);
    let full_mul = full_a * full_b;


    let full_result: U128 = ~U128::from(0, result);
    let full_denominator: U128 = ~U128::from(0, denominator);

    if full_mul > (full_denominator * full_result) {
        result + 1;
    }

    return result;
}

pub fn mul_div_full(base: U128, factor: U128, denominator: U128) -> U128 {
    let base_u256 = ~U256::from(0, 0, base.upper, base.lower);
    let factor_u256 = ~U256::from(0, 0, factor.upper, factor.lower);
    let denominator_u256 = ~U256::from(0, 0, denominator.upper, denominator.lower);

    let res_u256 = (base_u256 * factor_u256) / denominator_u256;

    if res_u256.a != 0 || res_u256.b != 0 {
        // panic on overflow
        revert(0);
    }

    ~U128::from(res_u256.c, res_u256.d)
}

pub fn mul_div_rounding_up_full(base: U128, factor: U128, divisor: U128) -> U128 {
    let base_u256 = ~U256::from(0, 0, base.upper, base.lower);
    let factor_u256 = ~U256::from(0, 0, factor.upper, factor.lower);
    let denominator_u256 = ~U256::from(0, 0, denominator.upper, denominator.lower);

    let res_u256 = (base_u256 * factor_u256) / denominator_u256;

    if res_u256 * denominator_u256 != base_u256 * factor_u256 {
        res_u256 = res_u256 + ~U256::from(0, 0, 0, 1);
    }

    if res_u256.a != 0 || res_u256.b != 0 {
        // panic on overflow
        revert(0);
    }

    let result = ~U128::from(res_u256.c, res_u256.d);
}
