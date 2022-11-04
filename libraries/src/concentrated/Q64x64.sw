// Copied from https://github.com/FuelLabs/sway-libs/pull/32
library Q64x64;

use core::num::*;
use std::{
    assert::assert, 
    math::*, 
    revert::revert, 
    u128::*, 
    u256::*
};

use ::Q128x128::Q128x128;

pub struct Q64x64 {
    value: U128,
}
impl Q64x64 {
    pub fn u128(self) -> U128 {
        self.value
    }
}
impl Q64x64 {
    pub fn from(value: U128) -> Self {
        Self { value }
    }
}
impl Q64x64 {
    pub fn denominator() -> u64 {
        1 << 64
    }
    pub fn zero() -> Self {
        Self {
            value: U128{upper: 0, lower: 0},
        }
    }
    pub fn bits() -> u32 {
        128
    }
    pub fn integer_bits() -> u32 {
        64
    }
    pub fn decimal_bits() -> u32 {
        64
    }
}
impl U128 {
    fn ge(self, other: Self) -> bool {
        self > other || self == other
    }
    fn le(self, other: Self) -> bool {
        self < other || self == other
    }
}
impl core::ops::Eq for Q64x64 {
    fn eq(self, other: Self) -> bool {
        self.value == other.value
    }
}
impl core::ops::Ord for Q64x64 {
    fn gt(self, other: Self) -> bool {
        self.value > other.value
    }
    fn lt(self, other: Self) -> bool {
        self.value < other.value
    }
}
impl core::ops::Add for Q64x64 {
    /// Add a Q64x64 to a Q64x64. Panics on overflow.
    fn add(self, other: Self) -> Self {
        Self {
            value: self.value + other.value,
        }
    }
}
impl core::ops::Subtract for Q64x64 {
    /// Subtract a Q64x64 from a Q64x64. Panics of overflow.
    fn subtract(self, other: Self) -> Self {
        // If trying to subtract a larger number, panic.
        assert(self.value >= other.value);
        Self {
            value: self.value - other.value,
        }
    }
}
impl Q64x64 {
    /// Multiply a Q64x64 with a Q64x64. Panics of overflow.
    fn multiply(self, other: Self) -> Q128x128 {
        let int = U256{a: 0, b: self.value.upper, c: self.value.lower, d: 0} * U256{a: 0, b: other.value.upper, c: 0, d: 0};
        let dec = U256{a: 0, b: self.value.upper, c: self.value.lower, d: 0} * U256{a: 0, b: 0, c: other.value.lower, d: 0} >> 64;
        return Q128x128{value: (int + dec)};
    }
}
impl core::ops::Divide for Q64x64 {
    /// Divide a Q64x64 by a Q64x64. Panics if divisor is zero.
    fn divide(self, divisor: Self) -> Self {
        let int = U256{a: 0, b: self.value.upper, c: self.value.lower, d: 0} / U256{a: 0, b: divisor.value.upper, c: 0, d: 0};
        let dec = U256{a: 0, b: self.value.upper, c: self.value.lower, d: 0} / U256{a: 0, b: 0, c: divisor.value.lower, d: 0} << 64;
        let value_u256 = int + dec;
        let value_u128 = U128{upper: value_u256.b, lower: value_u256.c};
        Self {
            value: value_u128
        }
    }
}
impl core::ops::Mod for U128 {
    /// Modulo of a U128 by a U128. Panics if divisor is zero.
    fn modulo(self, divisor: Self) -> Self {
        let zero = U128{upper: 0, lower: 0};
        let one =  U128{upper: 0, lower: 1};
        assert(divisor != zero);
        let mut quotient = U128::new();
        let mut remainder = U128::new();
        let mut i = 128 - 1;
        while true {
            quotient <<= 1;
            remainder <<= 1;
            remainder = remainder | ((self & (one << i)) >> i);
            // TODO use >= once OrdEq can be implemented.
            if remainder > divisor || remainder == divisor {
                remainder -= divisor;
                quotient = quotient | one;
            }
            if i == 0 {
                break;
            }
            i -= 1;
        }
        remainder
    }
}

impl Q64x64 {
    /// Creates Q64x64 that correponds to a unsigned integer
    pub fn from_uint(uint: u64) -> Self {
        let value = U128{upper: uint, lower: 0};
        Self {
            value
        }
    }
}
impl Root for Q64x64 {
    /// Sqaure root for Q64x64
    fn sqrt(self) -> Self {
        let nominator_root = self.value.sqrt();
        // Need to multiple over 2 ^ 16, as the sqare root of the denominator 
        // is also taken and we need to ensure that the denominator is constant
        let nominator = nominator_root << 16;
        Self {
            value: nominator,
        }
    }
}
