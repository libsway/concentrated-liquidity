library tick_math;

dep I24;
// dep Q64x64;

use I24::*;
// use I24::{
//     neg_from
// };

use std::{
    u128::*,
    u256::*,
    result::Result,
};
// use Q64x64::Q64x64;

// const MAX_TICK = I24 {
//     underlying: 887272
// };

// const MIN_TICK = ~I24::neg_from(MAX_TICK.underlying);

// const MIN_SQRT = Q64x64 {
//     value: ~Q64x64::from(get_price_at_tick(MIN_TICK))
// };

// const MAX_SQRT = Q64x64 {
//     value: ~Q64x64::from(get_price_at_tick(MAX_TICK))
// };
 

pub fn get_price_at_tick(tick: I24) -> U128 {
    let zero: U256 = ~U256::from(0,0,0,0);
    let absTick = tick.abs();
    let absTick: u64 = absTick;
    let absTick: U256 = ~U256::from(0, 0, 0, absTick);
    
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x1)) != zero {
            ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a) 
        } else { 
            ~U256::from(0x10000000, 0x00000000, 0x00000000, 0x00000000) 
        };
//0xfff97272373d413259a46990580e213a
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x2)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x0580e213a)) >> 128 
        } else { 
            ratio 
        };
//0xfff2e50f5f656932ef12357cf3c7fdcc
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x4)) != zero { 
            (ratio * ~U256::from(0xfff2e50f, 0x5f656932, 0xef12357c, 0xf3c7fdcc)) >> 128 
        } else { 
            ratio 
        };
//0xffe5caca7e10e4e61c3624eaa0941cd0
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x8)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };
//0xffcb9843d60f6159c9db58835c926644
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x10)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };
//0xff973b41fa98c081472e6896dfb254c0
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x20)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };
//0xff2ea16466c96a3843ec78b326b52861
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x40)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };
//0xfe5dee046a99a2a811c461f1969c3053
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x80)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };
//0xfcbe86c7900a88aedcffc83b479aa3a4
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x100)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };   
//0xf987a7253ac413176f2b074cf7815e54
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x200)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };
//0xf3392b0822b70005940c7a398e4b70f3
     let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x400)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        }; 
//0xe7159475a2c29b7443b29c7fa6e889d9
     let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x800)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };
//0xd097f3bdfd2022b8845ad8f792aa5825
     let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x1000)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };   
//0xa9f746462d870fdf8a65dc1f90e061e5
     let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x2000)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        }; 
//0x70d869a156d2a1b890bb3df62baf32f7
     let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x4000)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };
//0x31be135f97d08fd981231505542fcfa6
     let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x8000)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };
//0x9aa508b5b7a84e1c677de54f3e99bc9
     let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x10000)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };
//0x5d6af8dedb81196699c329225ee604
     let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x20000)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };  
//0x2216e584f5fa1ea926041bedfe98
     let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x40000)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        }; 
//0x48a170391f7dc42444e8fa2
     let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x80000)) != zero { 
            (ratio * ~U256::from(0xfffcb933, 0xbd6fad37, 0x59a46990, 0x580e213a)) >> 128 
        } else { 
            ratio 
        };
    if (tick > ~I24::from_uint(0)) {
        let ratio = ~U256::max() / ratio;
    }     
    return ~U128::from(0,0);
}

fn get_tick_at_price(price: U128) -> I24 {
    // need to validate ratio
    return ~I24::from(0);
}