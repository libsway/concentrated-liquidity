contract;

dep cl_libs;

use cl_libs::*;

abi MyContract {
    fn test_function() -> bool;
}
impl MyContract for Contract {
    fn test_function() -> bool {
        true
    }
}
