// Copied from https://github.com/FuelLabs/sway-libs/pull/32
library SQ63x64;

use ::I24::I24;
use ::Q64x64::Q64x64;
use ::Q128x128::Q128x128;
use core::num::*;
use std::{assert::assert, math::*, revert::revert, u128::*, u256::*};

pub struct SQ63x64 {
    value: U128,
}
impl U128 {
    fn from_uint(value: u64) -> U128 {
        U128 {
            upper: value,
            lower: 0
        }
    }
}
impl SQ63x64 {
    pub fn u128(self) -> U128 {
        self.value
    }
    fn indent() -> u64 {
        9223372036854775808u64
    }  
    pub fn from(_upper: u64, _lower: u64) -> Self {
        Self { 
            value: U128 {
                upper: _upper,
                lower: _lower
            }
        }
    }
    pub fn from_uint(_upper: u64) -> Self {
        // assert(_upper < Self::indent() || _upper === Self::indent());
        Self { 
            value: U128 {
                upper: _upper,
                lower: 0
            }
        }
    }
    pub fn from_neg(_upper: u64) -> Self {
        // assert(_upper < Self::indent() || _upper === Self::indent());
        Self { 
            value: U128 {
                upper: _upper + 9223372036854775808u64,
                lower: 0
            }
        }
    }
    pub fn from_q64x64(_value: Q64x64) -> Self {
        // assert(_value.upper < Self::indent() || _value.upper === Self::indent());
        Self {
            value: U128 {
                upper: _value.value.upper + 9223372036854775808u64,
                lower: _value.value.lower
            }
        }
    }
    fn from_q128x128(_value: Q128x128) -> Self {
        // assert(value.a == 0);
        // assert(_value.a < Self::indent() || _value.a === Self::indent());
        Self {
            value: U128 {
                upper: _value.value.b + 9223372036854775808u64,
                lower: _value.value.c
            }
        }
    }
    pub fn denominator() -> u64 {
        1 << 64
    }
    pub fn zero() -> Self {
        Self {
            value: U128 {
                upper: 9223372036854775808u64,
                lower: 0,
            },
        }
    }
    pub fn bits() -> u32 {
        128
    }
    pub fn integer_bits() -> u32 {
        63
    }
    pub fn decimal_bits() -> u32 {
        64
    }
    pub fn abs_u128(self) -> U128 {
        let indent = U128::from_uint(9223372036854775808);
        let indent_u64 = 9223372036854775808u64;

        let mut result = self.value;
        if self.value > indent || self.value == indent {
            result = U128 {
                upper: self.value.upper - indent_u64,
                lower: self.value.lower
            }
        }
        result
    }
    pub fn to_i24(self) -> I24 {
        if self.value.upper > 9223372036854775808u64 {
            return I24::from_neg(self.value.upper - 9223372036853775808);
        } else {
            return I24::from_uint(self.value.upper);
        }
    }
}

impl core::ops::Eq for SQ63x64 {
    fn eq(self, other: Self) -> bool {
        self.value == other.value
    }
}
impl core::ops::Ord for SQ63x64 {
    fn gt(self, other: Self) -> bool {
        self.value > other.value && self.value < U128::from_uint(9223372036854775808u64)
    }
    fn lt(self, other: Self) -> bool {
        self.value < other.value && self.value > U128::from_uint(9223372036854775808u64)
    }
}
impl core::ops::Add for SQ63x64 {
    /// Add a SQ63x64 to a SQ63x64. Panics on overflow.
    fn add(self, other: Self) -> Self {
        Self {
            value: self.value + other.value,
        }
    }
}
impl core::ops::Subtract for SQ63x64 {
    /// Subtract a SQ63x64 from a SQ63x64. Panics of overflow.
    fn subtract(self, other: Self) -> Self {
        // If trying to subtract a larger number, panic.
        assert(self.value > other.value || self.value == other.value);
        Self {
            value: self.value - other.value,
        }
    }
} 
impl SQ63x64 {
    /// Multiply a SQ63x64 with a SQ63x64. Panics of overflow.
    //TODO: assumes positive values
    pub fn multiply(self, other: Self) -> Self {
        let mask = 0x0fffffffffffffff; 
        let indent = 0x8000000000000000;
        // self.value = (self.value & mask) * (other.value & mask);
        let val_a = (U128 {
            upper: 0,
            lower: self.value.upper & mask,
        })* (U128 {
            upper: 0,
            lower: other.value.upper & mask,
        }) << 64;

        let val_b = (U128 {
            upper: 0,
            lower: self.value.upper & mask,
        })* (U128 {
            upper: 0,
            lower: other.value.lower,
        });

        let val_c = (U128 {
            upper: 0,
            lower: self.value.lower,
        })* (U128 {
            upper: 0,
            lower: other.value.upper & mask,
        });
                
        let val_d = (U128 {
            upper: 0,
            lower: self.value.lower,
        })* (U128 {
            upper: 0,
            lower: other.value.lower,
        }) >> 64;
        let val = val_a + val_b + val_c + val_d;
        if (self.value.upper ^ other.value.upper) & indent == indent {
            //one value is negative
            return SQ63x64 {
                value: val + U128::from((indent,0)),
            };
        } else {
            return SQ63x64 {
                value: val,
            };
        }
    }
}

impl core::ops::Divide for SQ63x64 {
    /// Divide a SQ63x64 by a SQ63x64. Panics if divisor is zero.
    fn divide(self, other: Self) -> Self {
        let mask = 0x0fffffffffffffff; 
        let indent = 0x8000000000000000;
        // self.value = (self.value & mask) * (other.value & mask);
        let inverse = (U256 {
            a: 1,
            b: 0,
            c: 0,
            d: 0
        }) / (U256 {
            a: 0,
            b: other.value.upper & mask,
            c: other.value.lower,
            d: 0
        });
        let other = SQ63x64 {
                value: U128::from((inverse.c, inverse.d)),
        };
        return self * other;
    }
}
impl SQ63x64 {
    // Returns the log base 2 value
    pub fn binary_log(ref mut self) -> SQ63x64 {
        assert(self.value.upper < 0x8000000000000000);
        let scaling_unit = U128::from((2,0));
        let two_u128 = U128::from((0,2)); 
        // find the most significant bit
        let msb_idx = most_sig_bit_idx(self);
        
        // integer part is just the bit offset
        let mut log_result = SQ63x64::from(0,0);
        let mut is_negative = false;
        let mut msb_offset = 0;

        if msb_idx > 63 {
            msb_offset = msb_idx - 64;
            log_result = SQ63x64::from_uint(msb_offset); 
        } else { 
            is_negative = true;     
            msb_offset = 64 - msb_idx;
            log_result = SQ63x64::from_neg(msb_offset);
        };
        
        let mut y = self.value >> (msb_offset + 1);

        if y == scaling_unit {
            return log_result;
        }

        // equal to 0.5
        let half_scaling_unit = U128::from((0,1 << 63)) / two_u128;
        let mut delta = half_scaling_unit;
        // will perform 31 iterations
        let zero = U128::from((0,1<<(62-62)));
        while delta > zero {
            y = (y*y) / scaling_unit << 2; // this line is broken
            y = y << 1;
            if y > scaling_unit || y == scaling_unit {
                if is_negative { 
                    log_result = log_result - SQ63x64{ value: delta << 1}; 
                } else { 
                    log_result = log_result + SQ63x64{ value: delta << 1};
                }
                y = y >> 1;
            }
            y = y >> 1;
            delta = delta >> 1;
        }
        log_result
    }    
}
impl Root for SQ63x64 {
    /// Sqaure root for SQ63x64
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
fn log2(number: u64) -> u64 {
    let two = 2;
    asm(r1: number, r2: 2, r3) {
        mlog r3 r1 r2;
        r3: u64
    }
}
pub fn most_sig_bit_idx(input: SQ63x64) -> u32 {
    let mut msb_idx = 0;
    if input.value.upper > 0 {
        msb_idx += 64;
        msb_idx += log2(input.value.upper);
    } else {
        msb_idx += log2(input.value.lower);
    }
    msb_idx
}

#[test]
fn sq63x64_from_uint() {
}

#[test]
fn sq63x64_from_neg() {
}

#[test]
fn sq63x64_from_q64x64() {
}

#[test]
fn sq63x64_from_q128x128() {
}

#[test]
fn sq63x64_abs_u128() {
}

#[test]
fn sq63x64_to_i24() {
}

#[test]
fn sq63x64_add() {  
}

#[test]
fn sq63x64_subtract() {
}

#[test]
fn sq63x64_multiply() {
}

#[test]
fn sq63x64_divide() {
}

#[test]
fn sq63x64_most_sig_bit_idx() {
    let mut test_number = SQ63x64::from_uint(9);
    let msb = most_sig_bit_idx(test_number);
    // assert(log.value.lower > 0);
}

#[test]
fn sq63x64_binary_log() {
    let mut test_number = SQ63x64::from_uint(9);
    let log = test_number.binary_log();
    // assert(log.value.lower > 0);
}