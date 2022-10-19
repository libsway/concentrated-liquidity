library full_math;
use std::{result::Result, u128::*, u256::*};
use core::ops::*;
pub enum FullMathError {
    DivisionByZero: (),
}
pub fn mul_div(base: U128, factor: U128, denominator: U128) -> U128 {
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
pub fn mul_div_rounding_up(base: U128, factor: U128, denominator: U128) -> U128 {
    let base_u256 = ~U256::from(0, 0, base.upper, base.lower);
    let factor_u256 = ~U256::from(0, 0, factor.upper, factor.lower);
    let denominator_u256 = ~U256::from(0, 0, denominator.upper, denominator.lower);
    let mut res_u256 = (base_u256 * factor_u256) / denominator_u256;
    if res_u256 * denominator_u256 != base_u256 * factor_u256 {
        res_u256 = res_u256 + ~U256::from(0, 0, 0, 1);
    }
    if res_u256.a != 0 || res_u256.b != 0 {
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
    if res_u256.a != 0 || res_u256.b != 0 {
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
    if res_u256.a != 0 || res_u256.b != 0 {
        // panic on overflow
        revert(0);
    }
    ~U128::from(res_u256.c, res_u256.d)
}
