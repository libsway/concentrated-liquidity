// Copied from https://github.com/FuelLabs/sway-libs/pull/32
library Q128x128;

dep I24;

use core::num::*;
use std::{
    assert::assert, 
    math::*, 
    revert::revert, 
    u256::*,
    u128::*,
};

use I24::*;

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
            value: ~U256::from(0,0, 0, 0),
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

impl Q128x128 {
    fn insert_sig_bits(ref mut self, msb_idx: u8, log_sig_bits: u64) -> U256 {
        // intiialize vector
        let mut v = ~Vec::new();
        v.push(self.value.a); v.push(self.value.b); v.push(self.value.c); v.push(self.value.d);
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
                let new_bit = log_sig_bits & (1 << result_idx) >> result_idx << bit_idx;
                // replace old bits with new
                let new_value = v.get(vector_idx).unwrap()  + new_bit;
                v.set(vector_idx, new_value);
                // return when all 64 bits have been inserted
                if(result_idx == 0 ) {
                    return ~U256::from(v.get(0).unwrap(), v.get(1).unwrap(), v.get(2).unwrap(), v.get(3).unwrap());
                }
                result_idx -= 1;
            }
            vector_idx += 1;
        }
        ~U256::from(0,0,0,0)
    }
}

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
        let value = ~U256::from(0, uint, 0, 0);
        Self {
            value
        }
    }

    // Returns the log base 2 value
    pub fn binary_log(ref mut self) -> I24 {
        // find the most significant bit
        let msb_idx = most_sig_bit_idx(self.value);

        // find the 64 most significant bits
        let sig_bits = most_sig_bits(self.value, msb_idx);

        // take the log base 2 of sig_bits
        let log_sig_bits = log2(sig_bits);

        // reinsert log bits into Q128X128
        let log_base2_u256 = self.insert_sig_bits(msb_idx, log_sig_bits);
        let log_base2_q128x128 = Q128x128 { value: log_base2_u256 };

        // log2(10^128) + 8*log2(10^16)
        let ten_to_the_16th:u64 = 10000000000000000;
        let log_base2_max_u64 = log2(ten_to_the_16th);

        // log2(10^128) = 8 * log2(10^16)
        let log_base2_1_q128x128 = Q128x128 { value: ~U256::from(0, 0, 0, log_base2_max_u64 * 8) };

        let mut log_base2_value = Q128x128 { value: ~U256::from(0, 0, 0, 0) };
        //TODO: should we round up to nearest tick?
        if log_base2_q128x128 > log_base2_1_q128x128 {
            log_base2_value = log_base2_q128x128 - log_base2_1_q128x128;
            return ~I24::from_uint(log_base2_value.value.b);
        } else {
            log_base2_value = log_base2_1_q128x128 - log_base2_q128x128;
            return ~I24::neg_from(log_base2_value.value.b);
        }
        //TODO: throw exception
        ~I24::from_uint(0)
    }
}

fn log2(number:u64) -> u64 {
    let two = 2;
    asm(r1: number, r2: 2, r3) {
        mlog r3 r1 r2;
        r3: u64
    }
}

fn most_sig_bit_idx(value: U256) -> u8 {
    let mut v = ~Vec::new();
    v.push(value.a); v.push(value.b); v.push(value.c); v.push(value.d);

    let mut vector_idx = 0;
    while vector_idx < v.len() {
        let mut bit_idx = 63;
        while(bit_idx > 0){
            let bit_compare = 1 << bit_idx;
            if(v.get(vector_idx).unwrap() > bit_compare || v.get(vector_idx).unwrap() == bit_compare){
                return 64 * (v.len() - vector_idx) + (bit_idx)
            }
            bit_idx -= 1;
        }
        vector_idx += 1;
    }
    //TODO: should throw err
    return 0;
}

fn most_sig_bits(value: U256, msb_idx: u8) -> u64 {
    // intiialize vector
    let mut v = ~Vec::new();
    // 192 -> 255       128 -> 191      64 -> 127         0 -> 63
    v.push(value.a); v.push(value.b); v.push(value.c); v.push(value.d);
    // initialize result bits
    let mut result: u64 = 0;
    let mut result_idx = 63;
    // match msb_idx (most significant bit findex) with vector_idx
    let start_vector_idx =  (v.len() - 1) - (msb_idx) / 64;
    let mut vector_idx = start_vector_idx;
    while (vector_idx < v.len()) {
        let mut bit_idx = if vector_idx == start_vector_idx { msb_idx % 64 } else { 63 };
        while( bit_idx > 0 ) {
            let bit_compare = 1 << (bit_idx);
            let xor_flag: bool = (v.get(vector_idx).unwrap() ^ bit_compare) < v.get(vector_idx).unwrap();
            let result_add = if(xor_flag) { 1 << result_idx } else { 0 };
            result += result_add; result_idx -= 1; bit_idx -= 1;
            if(result_idx < 0 ) {
                return result;
            }
        }
        vector_idx += 1;
    }
    //TODO: should be an Error
    return 0;
}

