// Copied from https://github.com/FuelLabs/sway-libs/pull/32
library Q128x128;

use core::num::*;
use std::{
    assert::assert, 
    math::*, 
    revert::revert, 
    U256::*, 
    u256::*
};

pub struct Q128x128 {
    value: U256,
}

pub struct msb_tuple {
    sig_bits: u64,
    most_sig_bit: u8
}
impl Q128x128 {
    pub fn denominator() -> u64 {
        1 << 128
    }
    pub fn zero() -> Self {
        Self {
            value: ~U256::from(0, 0),
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
// impl core::ops::Multiply for Q128x128 {
//     /// Multiply a Q128x128 with a Q128x128. Panics of overflow.
//     fn multiply(self, other: Self) -> Q128x64 {
//         let self_u256 = ~U256::from(0, 0, self.value.upper, self.value.lower);
//         let other_u256 = ~U256::from(0, 0, self.value.upper, self.value.lower);
//         let self_multiply_other = self_u256 * other_u256;
//         let res_u256 = self_multiply_other >> 64;
//         if res_u256.b != 0 {
//             // panic on overflow
//             revert(0);
//         }
//         Self {
//             value: ~U256::from(res_u256.c, res_u256.d),
//         }
//     }
// }
// impl core::ops::Divide for Q128x128 {
//     /// Divide a Q128x128 by a Q128x128. Panics if divisor is zero.
//     fn divide(self, divisor: Self) -> Self {
//         let zero = ~Q128x128::zero();
//         assert(divisor != zero);
//         let denominator = ~U256::from(0, ~Self::denominator());
//         // Conversion to U256 done to ensure no overflow happen
//         // and maximal precision is avaliable
//         // as it makes possible to multiply by the denominator in 
//         // all cases
//         let self_U256 = ~U256::from(0, self.value);
//         let divisor_U256 = ~U256::from(0, divisor.value);

//         // Multiply by denominator to ensure accuracy 
//         let res_U256 = self_U256 * denominator / divisor_U256;
//         if res_U256.upper != 0 {
//             // panic on overflow
//             revert(0);
//         }
//         Self {
//             value: res_U256.lower,
//         }
//     }
// }
impl Q128x128 {
    /// Creates Q128x128 that correponds to a multplied Q64x64
    pub fn from(int: U128, dec: U128) -> Self {
        let cast256 = ~U256::from(int.upper, int.lower, dec.upper, dec.lower);
        Self {
            value: cast256
        }
    }

    /// Creates Q128x128 that correponds to a unsigned integer
    pub fn from_uint(uint: u64) -> Self {
        let cast128 = ~U256::from(0, ~Self::denominator() * uint);
        Self {
            value: cast128,
        }
    }

    // Returns the log base 2 value
    pub fn binary_log(self) -> Self {
        let msb_idx = most_sig_bit_idx(self.value);
        let sig_bits = most_sig_bits(msb_idx);
        asm(output: log_sig_bits, r1: sig_bits, r2: 2) {
            mlog output, r1, r2;
        }
        let log_base2_u256 = insert_log_bits(self.value, msb_idx, log_sig_bits);
        asm(output: log_base2_max_u64, r1: 10**16, r2: 2) {
            mlog output, r1, r2;
        }
        // 16*8 = 128
        let log_base2_1_q128x128 = ~U256::from(0, 0, 0, log_base2_max_u64 * 8);
        // log2(price) = log2(price*10^128) - log2(10^128)
        // zero normalizes log base 2
        // handle negative values with I24
        let log_base2_q128x128 = log_base2_u256 - log_base2_1_q128x128

        log_base2_q128x128
    }

    fn most_sig_bit_idx(value: U256) -> u8 {
        let mut v = ~Vec::new();
        v.push(value.a); v.push(value.b); v.push(value.c); v.push(value.d);

        let vector_idx = 0;
        while vector_idx < v.len() {
            let mut bit_idx = 63;
            while(bit_idx > 0){
                bit_compare = 1 << bit_idx;
                if(v.get(vector_idx) > bit_compare || v.get(vector_idx) == bit_compare){
                    return 64 * (v.len() - vector_idx) + (bit_idx)
                }
                bit_idx -= 1;
            }
            vector_idx += 1;
        }
    }

    fn most_sig_bits(msb_idx: u8) -> u64 {
        // intiialize vector
        let mut v = ~Vec::new();
        // 192 -> 255       128 -> 191      64 -> 127         0 -> 63
        v.push(value.a); v.push(value.b); v.push(value.c); v.push(value.d);
        // initialize result bits
        let mut result: u64 = ~u64::zero();
        let mut result_idx = 63;
        // match msb_idx (most significant bit index) with vector_idx
        let start_vector_idx =  (v.len() - 1) - (msb_idx) / 64;
        let mut vector_idx = start_vector_idx;
        while (vector_idx < v.len()) {
            let mut bit_idx = if vector_idx == start_vector_idx { msb_idx % 64 } else { 63 };
            while( bit_idx > 0 ) {
                bit_compare = 1 << (bit_idx);
                xor_flag: bool = (v.get(vector_idx) ^ bit_compare) < v.get(vector_idx);
                let result_add = if(xor_flag) { 1 << result_idx } else { 0 };
                result += result_add; result_idx -= 1; bit_idx -= 1;
                if(result_idx < 0 ) {
                    return result;
                }
            }
            vector_idx += 1;
        }
    }

    fn insert_sig_bits(ref mut val, msb_idx: u8, log_sig_bits: u64) -> U256 {
        // intiialize vector
        let mut v = ~Vec::new();
        v.push(~u64::zero()); v.push(~u64::zero()); v.push(~u64::zero()); v.push(~u64::zero());
        let mut result_idx = 63;

        // match msb_idx (most significant bit index) with vector_idx
        let start_vector_idx =  (v.len() - 1) - (msb_idx) / 64;
        let mut vector_idx = start_vector_idx;

        // iterate over vector
        while (vector_idx < v.len()) {
            // initialize bit_idx
            let mut bit_idx = if vector_idx == start_vector_idx { msb_idx % 64 } else { 63 };
            // iterate over each bit in each vector element
            while( bit_idx > 0 ) {
                // take the new bit from log_sig_bits and scale it to current bit_idx
                new_bit = log_sig_bits & (1 << result_idx) >> result_idx << bit_idx;
                // replace old bits with new
                new_value = v.get(vector_idx) + new_bit;
                v.set(vector_idx, new_value);
                // return when all 64 bits have been inserted
                if(result_idx == 0 ) {
                    return ~U256::from(v.get(0), v.get(1), v.get(2), v.get(3));
                }
                result_idx -= 1;
            }
            vector_idx += 1;
        }
    }
}
impl Root for Q128x128 {
    /// Square root for Q128x128
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
impl Exponentiate for Q128x128 {
    /// Power function. x ^ exponent
    fn pow(self, exponent: Self) -> Self {
        let demoninator_power = ~Q128x128::denominator();
        let exponent_int = exponent.value >> 32;
        let nominator_pow = ~U256::from(0, self.value).pow(~U256::from(0, exponent_int));
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
            value: ~U256::from(0, nominator.lower),
        }
    }
}
impl Exponent for Q128x128 {
    /// Exponent function. e ^ x
    fn exp(exponent: Self) -> Self {
        let one = ~Q128x128::from_uint(1);

        //coefficients in the Taylor series up to the seventh power
        let p2 = ~Q128x128::from(2147483648); // p2 == 1 / 2!
        let p3 = ~Q128x128::from(715827882); // p3 == 1 / 3!
        let p4 = ~Q128x128::from(178956970); // p4 == 1 / 4!
        let p5 = ~Q128x128::from(35791394); // p5 == 1 / 5!
        let p6 = ~Q128x128::from(5965232); // p6 == 1 / 6!
        let p7 = ~Q128x128::from(852176); // p7 == 1 / 7!
        // common technique to counter loosing sugnifucant numbers in usual approximation
        // Taylor series approximation of exponantiation function minus 1. The subtraction is done to deal with accuracy issues
        let res_minus_1 = exponent + exponent * exponent * (p2 + exponent * (p3 + exponent * (p4 + exponent * (p5 + exponent * (p6 + exponent * p7)))));
        let res = res_minus_1 + one;
        res
    }
}
