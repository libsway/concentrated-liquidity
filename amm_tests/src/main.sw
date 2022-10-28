contract;

use cl_libs::I24::I24;

abi ExeguttorTests {
    fn test_thing() -> bool;
}

impl ExeguttorTests for Contract {
    fn test_thing() -> bool {
        true
    }
}
