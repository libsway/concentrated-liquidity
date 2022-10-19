contract;
<<<<<<< HEAD
dep libs;
use concentrated_liquidity_libs::I24::*;
=======

//dep libs;

//use concentrated_liquidity_libs::I24::*;

>>>>>>> 391971f513d2e78970398054e8cf7712349bd352
abi MyContract {
    fn test_function() -> bool;
}
impl MyContract for Contract {
    fn test_function() -> bool {
        true
    }
}
