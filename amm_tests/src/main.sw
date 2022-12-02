contract;

use std::u256::*;
use cl_libs::Q128x128::*;
use cl_libs::I24::*;

abi ExeguttorTests {
    fn test_most_sig_bit_idx() -> u64;
    fn test_most_sig_bits() -> u64;
}

impl ExeguttorTests for Contract {      
    fn test_most_sig_bit_idx() -> u64 {
        let mut test_number = U256{a:0, b: u64::max(), c:0, d:0};
        let mut result = most_sig_bit_idx(test_number);
        assert(result == 191);

        test_number = U256{a:0, b: 1, c: 1 << 63, d:0};
        result = most_sig_bit_idx(test_number);
        assert(result == 128);
        result
    }

    fn test_most_sig_bits() -> u64 {
        let mut test_number = U256{a:0, b: u64::max(), c:0, d:0};
        let mut msb_idx = most_sig_bit_idx(test_number);
        let mut result = most_sig_bits(test_number, msb_idx);
        assert(result == u64::max());

        test_number = U256{a:0, b: 1, c: 1 << 63, d:0};
        msb_idx = most_sig_bit_idx(test_number);
        result = most_sig_bits(test_number, msb_idx);
        assert(result == (2**63 + 2**62));
        result
    }
}
