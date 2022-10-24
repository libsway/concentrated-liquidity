contract;

abi ExeguttorTests {
    fn test_thing() -> bool;
}

impl ExeguttorTests for Contract {
    fn test_thing() -> bool {
        true
    }
}
