// Copied from https://github.com/FuelLabs/sway-libs/pull/32
library Q128x128;

use core::primitives::*;
use std::{assert::assert, math::*, revert::revert, u128::*, u256::*};
use ::I24::I24;

pub struct Q128x128 {
    value: U256,
}

pub struct msb_tuple {
    sig_bits: u64,
    most_sig_bit: u8,
}

impl Q128x128 {
    pub fn denominator() -> u64 {
        1 << 128
    }
    pub fn zero() -> Self {
        Self {
            value: U256 {
                a: 0,
                b: 0,
                c: 0,
                d: 0,
            },
        }
    }
    pub fn bits() -> u32 {
        256
    }
}
impl core::ops::Eq for Q128x128 {
    fn eq(self, other: Self) -> bool {
        self.value == other.value
    }
}
impl core::ops::Ord for Q128x128 {
    fn gt(self, other: Self) -> bool {
        self.value > other.value
    }
    fn lt(self, other: Self) -> bool {
        self.value < other.value
    }
}
impl core::ops::Add for Q128x128 {
    /// Add a Q128x128 to a Q128x128. Panics on overflow.
    fn add(self, other: Self) -> Self {
        Self {
            value: self.value + other.value,
        }
    }
}
impl core::ops::Subtract for Q128x128 {
    /// Subtract a Q128x128 from a Q128x128. Panics of overflow.
    fn subtract(self, other: Self) -> Self {
        // If trying to subtract a larger number, panic.
        assert(self.value > other.value || self.value == other.value);
        Self {
            value: self.value - other.value,
        }
    }
}
impl core::ops::Multiply for Q128x128 {
    /// Nultiply a Q128x128 by a Q128x128. Panics of overflow.
    fn multiply(self, other: Self) -> Q128x128 {
        let int = self.value * U256 {
            a: other.value.a,
            b: other.value.b,
            c: 0,
            d: 0,
        };
        let dec = self.value * U256 {
            a: 0,
            b: 0,
            c: other.value.c,
            d: other.value.d,
        } >> 128;
        Self {
            value: int + dec,
        }
    }
}
impl core::ops::Divide for Q128x128 {
    /// Divide a Q128x128 by a Q128x128. Panics if divisor is zero.
    fn divide(self, divisor: Self) -> Self {
        let int = self.value / U256 {
            a: divisor.value.a,
            b: divisor.value.b,
            c: 0,
            d: 0,
        };
        let dec = self.value / U256 {
            a: 0,
            b: 0,
            c: divisor.value.c,
            d: divisor.value.d,
        } << 128;
        Self {
            value: int + dec,
        }
    }
}

impl Q128x128 {
    /// Creates Q128x128 that correponds to a unsigned integer
    pub fn from_uint(uint: u64) -> Q128x128 {
        let value = U256 {
            a: 0,
            b: uint,
            c: 0,
            d: 0,
        };
        Q128x128 { value }
    }

    /// Creates Q128x128 that correponds to a unsigned integer
    pub fn from_u128(uint128: U128) -> Q128x128 {
        let value = U256 {
            a: uint128.upper,
            b: uint128.lower,
            c: 0,
            d: 0,
        };
        Q128x128 { value }
    }

    /// Creates Q128x128 that correponds to a unsigned integer
    pub fn from_u256(uint256: U256) -> Self {
        let value = uint256;
        Self { value }
    }

    pub fn from_q64x64(q64: U128) -> Q128x128 {
        let value = U256 {
            a: 0,
            b: q64.upper,
            c: q64.lower,
            d: 0,
        };
        Q128x128 { value }
    }

          
}

pub fn most_sig_bit_idx(value: U256) -> u64 {
    let mut v = Vec::new();
    v.push(value.a);
    v.push(value.b);
    v.push(value.c);
    v.push(value.d);

    let mut vector_idx = 0;
    while vector_idx < v.len() {
        let mut bit_idx = 64;
        while (bit_idx > 0) {
            bit_idx -= 1;
            let bit_compare = 1 << bit_idx;
            // return v.get(vector_idx).unwrap()
            if (v.get(vector_idx).unwrap() > bit_compare
                || v.get(vector_idx).unwrap() == bit_compare)
            {   
                return 64 * (v.len() - vector_idx - 1) + (bit_idx);
            }
        }
        vector_idx += 1;
    }
    //TODO: should throw err
    return 0;
}

pub fn most_sig_bits(value: U256, msb_idx: u8) -> u64 {
    let value_idx = msb_idx / 64;
    let msb_mod   = (msb_idx + 1) % 64;

    let first_val: u64 = 0; let second_val: u64 = 0;

    let first_val = match value_idx {
        0 => value.d,
        1 => value.c,
        2 => value.b,
        3 => value.a,
        _ => return 0,
    };

    if msb_mod == 0 || value_idx == 0 {
        return first_val;
    }

    let second_val = match value_idx {
        1 => value.d,
        2 => value.c,
        3 => value.b,
        _ => return 0,
    };

    let lsh_first_val = first_val << (64 - msb_mod);    

    let rsh_second_val = second_val >> (msb_mod);

    (lsh_first_val + rsh_second_val)
}

#[test]
fn q128x128_from_uint() {
}

#[test]
fn q128x128_from_u128() {
}

#[test]
fn q128x128_from_u256() {
}

#[test]
fn q128x128_from_q64x64() {
}

#[test]
fn q128x128_add() {  
}

#[test]
fn q128x128_subtract() {
}

#[test]
fn q128x128_multiply() {
}

#[test]
fn q128x128_divide() {
}
