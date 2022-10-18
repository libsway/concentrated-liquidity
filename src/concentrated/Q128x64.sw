// Copied from https://github.com/FuelLabs/sway-libs/pull/32
library Q128x64;

use core::num::*;
use std::{
    assert::assert, 
    math::*, 
    revert::revert, 
    u128::*, 
    u256::*
};

pub struct Q128x64 {
    integer: U128,
    decimal: u64
}
impl Q128x64 {
    pub fn denominator() -> u64 {
        1 << 64
    }
    pub fn zero() -> Self {
        Self {
            integer: ~U128::from(0, 0),
            decimal: ~u64::from(0)
        }
    }
    pub fn bits() -> u32 {
        192
    }
}
impl core::ops::Eq for Q128x64 {
    fn eq(self, other: Self) -> bool {
        self.integer == other.integer 
        && self.decimal == other.decimal
    }
}
impl core::ops::Ord for Q128x64 {
    fn gt(self, other: Self) -> bool {
        self.integer > other.integer 
        || (self.integer == other.integer && self.decimal > other.decimal)
    }
    fn lt(self, other: Self) -> bool {
        self.integer < other.integer 
        || (self.integer == other.integer && self.decimal < other.decimal)
    }
}
impl core::ops::Add for Q128x64 {
    /// Add a Q128x64 to a Q128x64. Panics on overflow.
    fn add(self, other: Self) -> Self {
        Self {
            integer: self.integer + other.integer,
            // handle overflow by adding 1
            decimal: self.decimal + other.decimal
        }
    }
}
impl core::ops::Subtract for Q128x64 {
    /// Subtract a Q128x64 from a Q128x64. Panics of overflow.
    fn subtract(self, other: Self) -> Self {
        // If trying to subtract a larger number, panic.
        assert(self.integer > other.integer || self.integer == other.integer);
        Self {
            integer: self.integer - other.integer,
        }
    }
}
impl core::ops::Multiply for Q128x64 {
    /// Multiply a Q128x64 with a Q128x64. Panics of overflow.
    fn multiply(self, other: Self) -> Self {
        let self_u256 = ~U256::from(0, 0, self.integer.upper, self.integer.lower);
        let other_u256 = ~U256::from(0, 0, self.integer.upper, self.integer.lower);
        let self_multiply_other = self_u256 * other_u256;
        let res_u256 = self_multiply_other >> 64;
        if res_u256.b != 0 {
            // panic on overflow
            revert(0);
        }
        Self {
            integer: ~U128::from(res_u256.c, res_u256.d),
        }
    }
}
impl core::ops::Divide for Q128x64 {
    /// Divide a Q128x64 by a Q128x64. Panics if divisor is zero.
    fn divide(self, divisor: Self) -> Self {
        let zero = ~Q128x64::zero();
        assert(divisor != zero);
        let denominator = ~U256::from(0, ~Self::denominator());
        // Conversion to U128 done to ensure no overflow happen
        // and maximal precision is avaliable
        // as it makes possible to multiply by the denominator in 
        // all cases
        let self_u128 = ~U256::from(0, self.integer);
        let divisor_u128 = ~U256::from(0, divisor.integer);

        // Multiply by denominator to ensure accuracy 
        let res_u128 = self_u128 * denominator / divisor_u128;
        if res_u128.upper != 0 {
            // panic on overflow
            revert(0);
        }
        Self {
            integer: res_u128.lower,
        }
    }
}
impl Q128x64 {
    /// Creates Q128x64 that correponds to a unsigned integer
    pub fn from_uint(uint: u64) -> Self {
        let cast128 = ~U128::from(0, ~Self::denominator() * uint);
        Self {
            integer: cast128,
        }
    }
}
impl Root for Q128x64 {
    /// Sqaure root for Q128x64
    fn sqrt(self) -> Self {
        let nominator_root = self.integer.sqrt();
        // Need to multiple over 2 ^ 16, as the sqare root of the denominator 
        // is also taken and we need to ensure that the denominator is constant
        let nominator = nominator_root << 16;
        Self {
            integer: nominator,
        }
    }
}
impl Exponentiate for Q128x64 {
    /// Power function. x ^ exponent
    fn pow(self, exponent: Self) -> Self {
        let demoninator_power = ~Q128x64::denominator();
        let exponent_int = exponent.integer >> 32;
        let nominator_pow = ~U128::from(0, self.integer).pow(~U128::from(0, exponent_int));
        // As we need to ensure the fixed point structure 
        // which means that the denominator is always 2 ^ 32
        // we need to delete the nominator by 2 ^ (32 * exponent - 1)
        // - 1 is the formula is due to denominator need to stay 2 ^ 32
        let nominator = nominator_pow >> demoninator_power * (exponent_int - 1);
        if nominator.upper != 0 {
            // panic on overflow
            revert(0);
        }
        Self {
            integer: ~U128::from(0, nominator.lower),
        }
    }
}
impl Exponent for Q128x64 {
    /// Exponent function. e ^ x
    fn exp(exponent: Self) -> Self {
        let one = ~Q128x64::from_uint(1);

        //coefficients in the Taylor series up to the seventh power
        let p2 = ~Q128x64::from(2147483648); // p2 == 1 / 2!
        let p3 = ~Q128x64::from(715827882); // p3 == 1 / 3!
        let p4 = ~Q128x64::from(178956970); // p4 == 1 / 4!
        let p5 = ~Q128x64::from(35791394); // p5 == 1 / 5!
        let p6 = ~Q128x64::from(5965232); // p6 == 1 / 6!
        let p7 = ~Q128x64::from(852176); // p7 == 1 / 7!
        // common technique to counter loosing sugnifucant numbers in usual approximation
        // Taylor series approximation of exponantiation function minus 1. The subtraction is done to deal with accuracy issues
        let res_minus_1 = exponent + exponent * exponent * (p2 + exponent * (p3 + exponent * (p4 + exponent * (p5 + exponent * (p6 + exponent * p7)))));
        let res = res_minus_1 + one;
        res
    }
}
