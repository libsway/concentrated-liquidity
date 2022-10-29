contract;

use cl_libs::I24::I24;

abi ExeguttorTests {
    fn test_bits() -> bool;
    fn test_indent() -> bool;
    fn test_max() -> bool;
}

impl ExeguttorTests for Contract {
    fn test_bits() -> bool {
        ~I24::bits() == 24u32
    }

    fn test_indent() -> bool {
        ~I24::indent() == 8388608u32
    }

    fn test_max() -> bool {
        ~I24::from_uint(8388607u32) == ~I24::max()
    }
}
