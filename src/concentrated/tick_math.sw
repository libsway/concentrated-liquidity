library tick_math;

dep I24;
dep Q64x64;
dep Q128x128;

use I24::*;
use std::{
    u128::*,
    u256::*,
    result::Result,
    math::*, 
};
use Q64x64::*;
use Q128x128::*;

impl U256 {
    fn modulo(self, other: U256) -> U256 {
        return (self - other * (self / other));
    }
}
pub fn MAX_TICK() -> I24 {
    return ~I24::max();

}
pub fn MIN_TICK() -> I24 {
    return ~I24::min();
}

impl U256 {
    fn modulo(self, other: U256) -> U256 {
        return (self - other * (self / other));
    }
}

pub fn check_sqrt_price_bounds(sqrt_price: Q64x64) {
    assert(sqrt_price < MIN_SQRT_PRICE());
    assert(sqrt_price > MAX_SQRT_PRICE() || sqrt_price == MAX_SQRT_PRICE());
}

pub fn get_price_at_tick(tick: I24) -> Q64x64 {
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
            (ratio * ~U256::from(0xffe5caca, 0x7e10e4e6, 0x1c3624ea, 0xa0941cd0)) >> 128 
        } else { 
            ratio 
        };
    //0xffcb9843d60f6159c9db58835c926644
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x10)) != zero { 
            (ratio * ~U256::from(0xffcb9843, 0xd60f6159, 0xc9db5883, 0x5c926644)) >> 128 
        } else { 
            ratio 
        };
    //0xff973b41fa98c081472e6896dfb254c0
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x20)) != zero { 
            (ratio * ~U256::from(0xff973b41, 0xfa98c081, 0x472e6896, 0xdfb254c0)) >> 128 
        } else { 
            ratio 
        };
    //0xff2ea16466c96a3843ec78b326b52861
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x40)) != zero { 
            (ratio * ~U256::from(0xff2ea1646, 0x66c96a38, 0x43ec78b3, 0x26b52861)) >> 128 
        } else { 
            ratio 
        };
    //0xfe5dee046a99a2a811c461f1969c3053
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x80)) != zero { 
            (ratio * ~U256::from(0xfe5dee04, 0x6a99a2a8, 0x11c461f1, 0x969c3053)) >> 128 
        } else { 
            ratio 
        };
    //0xfcbe86c7900a88aedcffc83b479aa3a4
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x100)) != zero { 
            (ratio * ~U256::from(0xfcbe86c7, 0x900a88ae, 0xdcffc83b, 0x479aa3a4)) >> 128 
        } else { 
            ratio 
        };   
    //0xf987a7253ac413176f2b074cf7815e54
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x200)) != zero { 
            (ratio * ~U256::from(0xf987a725, 0x3ac41317, 0x6f2b074c, 0xf7815e54)) >> 128 
        } else { 
            ratio 
        };
    //0xf3392b0822b70005940c7a398e4b70f3
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x400)) != zero { 
            (ratio * ~U256::from(0xf3392b08, 0x22b70005, 0x940c7a39, 0x8e4b70f3)) >> 128 
        } else { 
            ratio 
        }; 
    //0xe7159475a2c29b7443b29c7fa6e889d9
     let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x800)) != zero { 
            (ratio * ~U256::from(0xe7159475, 0xa2c29b74, 0x43b29c7f, 0xa6e889d9)) >> 128 
        } else { 
            ratio 
        };
    //0xd097f3bdfd2022b8845ad8f792aa5825
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x1000)) != zero { 
            (ratio * ~U256::from(0xd097f3bd, 0xfd2022b8, 0x845ad8f7, 0x92aa5825)) >> 128 
        } else { 
            ratio 
        };   
    //0xa9f746462d870fdf8a65dc1f90e061e5
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x2000)) != zero { 
            (ratio * ~U256::from(0xa9f74646, 0x2d870fdf, 0x8a65dc1f, 0x90e061e5)) >> 128 
        } else { 
            ratio 
        }; 
    //0x70d869a156d2a1b890bb3df62baf32f7
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x4000)) != zero { 
            (ratio * ~U256::from(0x70d869a1, 0x56d2a1b8, 0x90bb3df6, 0x2baf32f7)) >> 128 
        } else { 
            ratio 
        };
    //0x31be135f97d08fd981231505542fcfa6
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x8000)) != zero { 
            (ratio * ~U256::from(0x31be135f, 0x97d08fd9, 0x81231505, 0x542fcfa6)) >> 128 
        } else { 
            ratio 
        };
    //0x9aa508b5b7a84e1c677de54f3e99bc9
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x10000)) != zero { 
            (ratio * ~U256::from(0x9aa508b5, 0x5b7a84e1, 0xc677de54, 0xf3e99bc9)) >> 128 
        } else { 
            ratio 
        };
    //0x5d6af8dedb81196699c329225ee604
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x20000)) != zero { 
            (ratio * ~U256::from(0x5d6af8de, 0xdb8119669, 0x6699c329, 0x225ee604)) >> 128 
        } else { 
            ratio 
        };  
    //0x2216e584f5fa1ea926041bedfe98
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x40000)) != zero { 
            (ratio * ~U256::from(0x2216e584, 0xf5fa1ea9, 0x1ea92604, 0x1bedfe98)) >> 128 
        } else { 
            ratio 
        }; 
    //0x48a170391f7dc42444e8fa2
    let ratio = 
        if (absTick & ~U256::from(0, 0, 0, 0x80000)) != zero { 
            (ratio * ~U256::from(0x00000000, 0x48a17039, 0x91f7dc42, 0x444e8fa2)) >> 128 
        } else { 
            ratio 
        };
    if (tick > ~I24::from_uint(0)) {
        let ratio = ~U256::max() / ratio;
    }
    // shr 128 to downcast to a U128
    let round_up: U256 = if (ratio % (~U256::from(0,0,0,1) << 128) == ~U256::from(0,0,0,0)) {
        ~U256::from(0,0,0,0)
    } else {
        ~U256::from(0,0,0,1)
    };
    let price: U256 = ratio + round_up;
    return ~Q64x64::from(~U128::from(price.b, price.c));
}

//TODO: call once at deployment time
pub fn MIN_SQRT_PRICE() -> Q64x64 {
    Q64x64 { value : ~U128::from(0,0)}
}

pub fn MAX_SQRT_PRICE() -> Q64x64 {
    Q64x64 { value : ~U128::from(0,0)}
}

fn get_tick_at_price(sqrt_price: Q64x64) -> I24 {
    check_sqrt_price_bounds(sqrt_price);

    // square price
    let mut price: Q128x128 = sqrt_price * sqrt_price;

    // base value for tick change -> 1.0001
    let mut tick_base = ~Q128x128::from(~U128::from(0, 0), ~U128::from(10001 << (64 - 4), 0));

    //TODO: should we round up?
    // change of base; log base 1.0001 (price) = log base 2 (price) / log base 2 (1.0001)
    let log_base_tick_of_price: I24 = price.binary_log() / tick_base.binary_log();

    // return base 1.0001 price
    log_base_tick_of_price
}

