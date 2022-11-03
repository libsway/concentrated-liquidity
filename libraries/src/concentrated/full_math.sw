library full_math;

dep Q128x128;
dep Q64x64;

use std::{result::Result, u128::*, u256::*};
use std::revert::revert;
use core::ops::*;
use Q128x128::*;
use Q64x64::*;

pub enum FullMathError {
    DivisionByZero: (),
}

pub fn mul_div_u64(base: u64, factor: u64, denominator: u64) -> u64 {
    let base = U128{upper: 0, lower: base};
    let factor = U128{upper: 0, lower: factor};
    let denominator = U128{upper: 0, lower: denominator};
    let res = (base * factor) / denominator;
    if res.upper != 0 {
        // panic on overflow
        revert(0);
    }
    res.lower
}

pub fn mul_div(base: U128, factor: U128, denominator: U128) -> U128 {
    let base_u256 = U256{a:0, b:0, c:base.upper, d:base.lower};
    let factor_u256 = U256{a:0, b:0, c:factor.upper, d:factor.lower};
    let denominator_u256 = U256{a:0, b:0, c:denominator.upper, d:denominator.lower};
    let res_u256 = (base_u256 * factor_u256) / denominator_u256;
    if (res_u256.a != 0) || (res_u256.b != 0) {
        // panic on overflow
        revert(0);
    }
    U128{upper: res_u256.c, lower: res_u256.d}
}
pub fn mul_div_rounding_up_u64(base: u64, factor: u64, denominator: u64) -> u64 {
    let base = U128{upper: 0, lower: base};
    let factor = U128{upper: 0, lower: factor};
    let denominator = U128{upper: 0, lower: denominator};
    let mut res = (base * factor) / denominator;
    

    if (res * denominator) != (factor  * base) {
        res += U128{upper: 0, lower: 1};
    }
    if res.upper != 0 {
        // panic on overflow
        revert(0);
    }
    
    let result: u64 = res.lower;

    result
}
pub fn mul_div_rounding_up(base: U128, factor: U128, denominator: U128) -> U128 {
    let base_u256 = U256{a: 0, b: 0, c: base.upper, d: base.lower};
    let factor_u256 = U256{a: 0,b: 0,c: factor.upper,d: factor.lower};
    let denominator_u256 = U256{a: 0,b: 0,c: denominator.upper, d: denominator.lower};
    let mut res_u256 = (base_u256 * factor_u256) / denominator_u256;
    if res_u256 * denominator_u256 != base_u256 * factor_u256 {
        res_u256 = res_u256 + U256{a: 0, b: 0,c: 0,d: 1};
    }
    if (res_u256.a != 0) || (res_u256.b != 0) {
        // panic on overflow
        revert(0);
    }
    U128{ upper: res_u256.c, lower: res_u256.d }
}
pub fn mul_div_u256(base: U256, factor: U128, denominator: U128) -> U128 {
    let base_u256 = base;
    let factor_u256 = U256{a: 0,b: 0,c: factor.upper,d: factor.lower};
    let denominator_u256 = U256{a: 0,b: 0,c: denominator.upper,d: denominator.lower};
    let res_u256 = (base_u256 * factor_u256) / denominator_u256;
    if (res_u256.a != 0) || (res_u256.b != 0) {
        // panic on overflow
        revert(0);
    }
    U128{upper: res_u256.c,lower: res_u256.d}
}
pub fn mul_div_rounding_up_u256(base: U256, factor: U128, denominator: U128) -> U128 {
    let base_u256 = base;
    let factor_u256 = U256{a: 0, b: 0, c: factor.upper, d: factor.lower};
    let denominator_u256 = U256{a: 0, b: 0,c: denominator.upper,d: denominator.lower};
    let res_u256 = (base_u256 * factor_u256) / denominator_u256;
    if (res_u256.a != 0) || (res_u256.b != 0) {
        // panic on overflow
        revert(0);
    }
    let mut res_128 = U128{ upper: res_u256.c, lower: res_u256.d };
    if res_u256 * denominator_u256 != base_u256 * factor_u256 {
        res_128 = res_128 + U128{upper: 0,lower: 1};
    }
    
    res_128
}

pub fn mul_div_q64x64(base: Q128x128, factor: Q128x128, denominator: Q128x128) -> Q64x64 {
    let mut res: Q128x128 = (base * factor) / denominator;
    if (res.value.a != 0) || (res.value.b != 0) {
        // panic on overflow
        revert(0);
    }
    Q64x64{value: U128{upper: res.value.b, lower: res.value.c}}
}

pub fn mul_div_rounding_up_q64x64(base: Q128x128, factor: Q128x128, denominator: Q128x128) -> Q64x64 {
    let mut res: Q128x128 = (base * factor) / denominator;
    if res * denominator != base * factor {
        res = res + Q128x128 { value: U256{ a: 0, b: 0, c: 0, d: 1 }};
    }
    if (res.value.a != 0) || (res.value.b != 0) {
        // panic on overflow
        revert(0);
    }
    Q64x64{value: U128{ upper: res.value.b, lower: res.value.c}}
