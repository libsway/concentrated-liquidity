contract;

use std::u256::*;
use std::u128::*;
use cl_libs::SQ63x64::*;
use cl_libs::Q64x64::*;
use cl_libs::I24::*;
use cl_libs::tick_math::*;
use cl_libs::dydx_math::*;

abi ExeguttorTests {
    fn test_dydx_math() -> u64;
    fn test_most_sig_bit_idx() -> u64;
    fn test_binary_log() -> SQ63x64;
    fn test_abs_u128() -> U128;
    fn test_get_tick_at_price() -> I24;
}

pub enum ExeguttorTestsErrors {
    MostSigBitTestCase1: (),
    MostSigBitTestCase2: (),
    MostSigBitTestCase3: (),
    MostSigBitTestCase4: ()
}

impl ExeguttorTests for Contract {
    fn test_dydx_math() -> u64 {
        return dydx_math_get_dy();
    }

    fn test_most_sig_bit_idx() -> u64 {
        let mut test_number = SQ63x64{value: U128{upper: 2**63, lower:0}};
        let mut result = most_sig_bit_idx(test_number);
        require(result == 0, ExeguttorTestsErrors::MostSigBitTestCase1);

        let mut test_number = SQ63x64{value: U128{upper: 2**63 + 2**62, lower:0}};
        let mut result = most_sig_bit_idx(test_number);
        require(result == 126, ExeguttorTestsErrors::MostSigBitTestCase2);

        let mut test_number = SQ63x64{value: U128{upper: 2**62, lower:0}};
        let mut result = most_sig_bit_idx(test_number);
        require(result == 126, ExeguttorTestsErrors::MostSigBitTestCase3);

        test_number = SQ63x64{value: U128{upper: 9, lower: 1<<63}};
        result = most_sig_bit_idx(test_number);
        require(result == 67, ExeguttorTestsErrors::MostSigBitTestCase4);

        result
    }

    fn test_abs_u128() -> U128 {
        let mut test_number = SQ63x64{value: U128{upper: 2**63 + 2**62, lower:0}};
        let mut result = test_number.abs_u128();
        return U128 {upper:0, lower: 0};
    }  

    fn test_binary_log() -> SQ63x64 {
        let mut sqrt_price = Q64x64{value: U128::from((1,0))};
        let mut price = SQ63x64{value: (sqrt_price * sqrt_price).value };
        price.binary_log()
    }

    fn test_get_tick_at_price() -> I24 {
        let mut test_number1 = Q64x64{value: U128::from((4,0))};
        // let price = Q64x64{value : U128{upper : 3, lower : 0}};

        let mut result = get_tick_at_price(test_number1);
        result
    }
}
