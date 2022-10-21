library full_math;

use std::{result::Result, u128::*, u256::*};
use std::revert::revert;
use core::ops::*;

pub enum FullMathError {
    DivisionByZero: (),
}

pub fn mul_div_u64(base: u64, factor: u64, denominator: u64) -> u64 {
    let base = ~U128::from(0, base);
    let factor = ~U128::from(0, factor);
    let denominator = ~U128::from(0, denominator);
    let res = (base * factor) / denominator;
    if res.upper != 0 {
        // panic on overflow
        revert(0);
    }

    res.lower
}

pub fn mul_div(base: U128, factor: U128, denominator: U128) -> U128 {
    let base_u256 = ~U256::from(0, 0, base.upper, base.lower);
    let factor_u256 = ~U256::from(0, 0, factor.upper, factor.lower);
    let denominator_u256 = ~U256::from(0, 0, denominator.upper, denominator.lower);
    let res_u256 = (base_u256 * factor_u256) / denominator_u256;
    if (res_u256.a != 0) || (res_u256.b != 0) {
        // panic on overflow
        revert(0);
    }
    ~U128::from(res_u256.c, res_u256.d)
}
pub fn mul_div_rounding_up_u64(base: u64, factor: u64, denominator: u64) -> u64 {
    let base = ~U128::from(0, base);
    let factor = ~U128::from(0, factor);
    let denominator = ~U128::from(0, denominator);
    let mut res = (base * factor) / denominator;
    

    if (res * denominator) != (factor  * base) {
        res += ~U128::from(0,1);
    }
    if res.upper != 0 {
        // panic on overflow
        revert(0);
    }
    
    let result: u64 = res.lower;

    result
}
pub fn mul_div_rounding_up(base: U128, factor: U128, denominator: U128) -> U128 {
    let base_u256 = ~U256::from(0, 0, base.upper, base.lower);
    let factor_u256 = ~U256::from(0, 0, factor.upper, factor.lower);
    let denominator_u256 = ~U256::from(0, 0, denominator.upper, denominator.lower);
    let mut res_u256 = (base_u256 * factor_u256) / denominator_u256;
    if res_u256 * denominator_u256 != base_u256 * factor_u256 {
        res_u256 = res_u256 + ~U256::from(0, 0, 0, 1);
    }
    if (res_u256.a != 0) || (res_u256.b != 0) {
        // panic on overflow
        revert(0);
    }
    ~U128::from(res_u256.c, res_u256.d)
}
pub fn mul_div_u256(base: U256, factor: U128, denominator: U128) -> U128 {
    let base_u256 = base;
    let factor_u256 = ~U256::from(0, 0, factor.upper, factor.lower);
    let denominator_u256 = ~U256::from(0, 0, denominator.upper, denominator.lower);
    let res_u256 = (base_u256 * factor_u256) / denominator_u256;
    if (res_u256.a != 0) || (res_u256.b != 0) {
        // panic on overflow
        revert(0);
    }
    ~U128::from(res_u256.c, res_u256.d)
}
pub fn mul_div_rounding_up_u256(base: U256, factor: U128, denominator: U128) -> U128 {
    let base_u256 = base;
    let factor_u256 = ~U256::from(0, 0, factor.upper, factor.lower);
    let denominator_u256 = ~U256::from(0, 0, denominator.upper, denominator.lower);
    let mut res_u256 = (base_u256 * factor_u256) / denominator_u256;
    if res_u256 * denominator_u256 != base_u256 * factor_u256 {
        res_u256 = res_u256 + ~U256::from(0, 0, 0, 1);
    }
    if (res_u256.a != 0) || (res_u256.b != 0) {
        // panic on overflow
        revert(0);
    }
    ~U128::from(res_u256.c, res_u256.d)
}
