contract;
dep concentrated/tick_math;
dep concentrated/I24;

use I24::*;
use tick_math::*;

abi MyContract {
    fn test_function() -> bool;
}

impl MyContract for Contract {
    fn test_function() -> bool {
        let value = get_price_at_tick(~I24::from_uint(0));
        true
    }
}
