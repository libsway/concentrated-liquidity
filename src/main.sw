contract;

//dep libs;

//use concentrated_liquidity_libs::I24::*;

abi MyContract {
    fn test_function() -> bool;
}

impl MyContract for Contract {
    fn test_function() -> bool {
        true
    }
}
