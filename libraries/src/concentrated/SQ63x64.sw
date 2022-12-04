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
                upper: _value.value.a + 9223372036854775808u64,
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
    fn multiply(self, other: Self) -> Self {
        let mask = 0x0fffffffffffffff; 
        let indent = 0x8000000000000000;
        let int = U256 {
            a: 0,
            b: self.value.upper & mask,// negates sign
            c: self.value.lower,
            d: 0,
        } * U256 {
            a: 0,
            b: other.value.upper & mask,
            c: 0,
            d: 0,
        };
        let dec = U256 {
            a: 0,
            b: self.value.upper & mask,
            c: self.value.lower,
            d: 0,
        } * U256 {
            a: 0,
            b: 0,
            c: other.value.lower,
            d: 0,
        } >> 64;
        if self.value.upper ^ other.value.lower & indent == indent {
            //one value is negative
            return SQ63x64 {
                value: U128::from((int.b + indent, int.c)) + U128::from((dec.b, dec.c)),
            };
        } else {
            return SQ63x64 {
                value: U128::from((int.b, int.c)) + U128::from((dec.b, dec.c)),
            };
        }
    }
}

impl core::ops::Divide for SQ63x64 {
    /// Divide a SQ63x64 by a SQ63x64. Panics if divisor is zero.
    fn divide(self, divisor: Self) -> Self {
        let mask = 0x0fffffffffffffff; 
        let indent = 0x8000000000000000;
        let int = U256 {
            a: 0,
            b: self.value.upper & mask,
            c: self.value.lower,
            d: 0,
        } / U256 {
            a: 0,
            b: divisor.value.upper & mask,
            c: 0,
            d: 0,
        };
        let dec = U256 {
            a: 0,
            b: self.value.upper & mask,
            c: self.value.lower,
            d: 0,
        } / U256 {
            a: 0,
            b: 0,
            c: divisor.value.lower,
            d: 0,
        } << 64;
        if self.value.upper ^ divisor.value.lower & indent == indent {
            //one value is negative
            return SQ63x64 {
                value: U128::from((int.b + indent, int.c)) + U128::from((dec.b, dec.c)),
            };
        } else {
            return SQ63x64 {
                value: U128::from((int.b, int.c)) + U128::from((dec.b, dec.c)),
            };
        } 
    }
}
impl SQ63x64 {
    // Returns the log base 2 value
    pub fn binary_log(ref mut self) -> SQ63x64 {
        // find the most significant bit
        let scaling_unit = U128::from((1,0)) >> 1;
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
        let half_scaling_unit = U128::from((0,1 << 63)) >> 1;
        let double_scaling_unit = U128::from((2,0)) >> 1;
        let mut delta = half_scaling_unit;
        let zero = U128::from((0,2^62));
        while delta > zero {
            y = (y * y) / scaling_unit;
            if y > double_scaling_unit || y == double_scaling_unit {
                if is_negative { 
                    log_result -= SQ63x64{ value: delta << 1 } 
                } else { log_result += SQ63x64{ value: delta << 1 } };
                y >>= 1;
            }
            delta >>= 1;
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
pub fn most_sig_bit_idx(input: SQ63x64) -> u32 {
    let mut v = Vec::new();
    let value = input.abs_u128();
    v.push(value.upper);
    v.push(value.lower);
    let mut vector_idx = 0;
    while vector_idx < v.len() {
        let mut bit_idx = 64;
        if vector_idx == 0 { bit_idx -= 1};
        while (bit_idx > 0) {
            bit_idx -= 1;
            let bit_compare = 1 << bit_idx;
            // return v.get(vector_idx).unwrap()
            if (v.get(vector_idx).unwrap() > bit_compare
                || v.get(vector_idx).unwrap() == bit_compare)
            {   
                return 64 * (v.len() - vector_idx - 1) + bit_idx;
            }
        }
        vector_idx += 1;
    }
    //TODO: should throw err
    return 0;
}
