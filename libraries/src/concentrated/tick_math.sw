library tick_math;

use ::I24::I24;
use std::{result::Result, u128::U128, u256::U256};
use ::Q64x64::{full_multiply, Q64x64};
use ::Q128x128::Q128x128;

pub fn MAX_TICK() -> I24 {
    return I24::max();
}
pub fn MIN_TICK() -> I24 {
    return I24::min();
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

pub fn get_price_sqrt_at_tick(tick: I24) -> Q64x64 {
    let zero: U256 = U256 {
        a: 0,
        b: 0,
        c: 0,
        d: 0,
    };
    let absTick = tick.abs();
    let absTick: u64 = absTick;
    let absTick: U256 = U256 {
        a: 0,
        b: 0,
        c: 0,
        d: absTick,
    };

    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x1,
        }) != zero
    {
        U256 {
            a: 0xfffcb933,
            b: 0xbd6fad37,
            c: 0x59a46990,
            d: 0x580e213a,
        }
    } else {
        U256 {
            a: 0x10000000,
            b: 0x00000000,
            c: 0x00000000,
            d: 0x00000000,
        }
    };
    //0xfff97272373d413259a46990580e213a
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x2,
        }) != zero
    {
        (ratio * U256 {
            a: 0xfffcb933,
            b: 0xbd6fad37,
            c: 0x59a46990,
            d: 0x0580e213a,
        }) >> 128
    } else {
        ratio
    };
    //0xfff2e50f5f656932ef12357cf3c7fdcc
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x4,
        }) != zero
    {
        (ratio * U256 {
            a: 0xfff2e50f,
            b: 0x5f656932,
            c: 0xef12357c,
            d: 0xf3c7fdcc,
        }) >> 128
    } else {
        ratio
    };
    //0xffe5caca7e10e4e61c3624eaa0941cd0
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x8,
        }) != zero
    {
        (ratio * U256 {
            a: 0xffe5caca,
            b: 0x7e10e4e6,
            c: 0x1c3624ea,
            d: 0xa0941cd0,
        }) >> 128
    } else {
        ratio
    };
    //0xffcb9843d60f6159c9db58835c926644
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x10,
        }) != zero
    {
        (ratio * U256 {
            a: 0xffcb9843,
            b: 0xd60f6159,
            c: 0xc9db5883,
            d: 0x5c926644,
        }) >> 128
    } else {
        ratio
    };
    //0xff973b41fa98c081472e6896dfb254c0
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x20,
        }) != zero
    {
        (ratio * U256 {
            a: 0xff973b41,
            b: 0xfa98c081,
            c: 0x472e6896,
            d: 0xdfb254c0,
        }) >> 128
    } else {
        ratio
    };
    //0xff2ea16466c96a3843ec78b326b52861
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x40,
        }) != zero
    {
        (ratio * U256 {
            a: 0xff2ea1646,
            b: 0x66c96a38,
            c: 0x43ec78b3,
            d: 0x26b52861,
        }) >> 128
    } else {
        ratio
    };
    //0xfe5dee046a99a2a811c461f1969c3053
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x80,
        }) != zero
    {
        (ratio * U256 {
            a: 0xfe5dee04,
            b: 0x6a99a2a8,
            c: 0x11c461f1,
            d: 0x969c3053,
        }) >> 128
    } else {
        ratio
    };
    //0xfcbe86c7900a88aedcffc83b479aa3a4
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x100,
        }) != zero
    {
        (ratio * U256 {
            a: 0xfcbe86c7,
            b: 0x900a88ae,
            c: 0xdcffc83b,
            d: 0x479aa3a4,
        }) >> 128
    } else {
        ratio
    };   
    //0xf987a7253ac413176f2b074cf7815e54
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x200,
        }) != zero
    {
        (ratio * U256 {
            a: 0xf987a725,
            b: 0x3ac41317,
            c: 0x6f2b074c,
            d: 0xf7815e54,
        }) >> 128
    } else {
        ratio
    };
    //0xf3392b0822b70005940c7a398e4b70f3
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x400,
        }) != zero
    {
        (ratio * U256 {
            a: 0xf3392b08,
            b: 0x22b70005,
            c: 0x940c7a39,
            d: 0x8e4b70f3,
        }) >> 128
    } else {
        ratio
    }; 
    //0xe7159475a2c29b7443b29c7fa6e889d9
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x800,
        }) != zero
    {
        (ratio * (U256 {
            a: 0xe7159475,
            b: 0xa2c29b74,
            c: 0x43b29c7f,
            d: 0xa6e889d9,
        })) >> 128
    } else {
        ratio
    };
    //0xd097f3bdfd2022b8845ad8f792aa5825
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x1000,
        }) != zero
    {
        (ratio * (U256 {
            a: 0xd097f3bd,
            b: 0xfd2022b8,
            c: 0x845ad8f7,
            d: 0x92aa5825,
        })) >> 128
    } else {
        ratio
    };   
    //0xa9f746462d870fdf8a65dc1f90e061e5
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x2000,
        }) != zero
    {
        (ratio * (U256 {
            a: 0xa9f74646,
            b: 0x2d870fdf,
            c: 0x8a65dc1f,
            d: 0x90e061e5,
        })) >> 128
    } else {
        ratio
    }; 
    //0x70d869a156d2a1b890bb3df62baf32f7
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x4000,
        }) != zero
    {
        (ratio * (U256 {
            a: 0x70d869a1,
            b: 0x56d2a1b8,
            c: 0x90bb3df6,
            d: 0x2baf32f7,
        })) >> 128
    } else {
        ratio
    };
    //0x31be135f97d08fd981231505542fcfa6
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x8000,
        }) != zero
    {
        (ratio * (U256 {
            a: 0x31be135f,
            b: 0x97d08fd9,
            c: 0x81231505,
            d: 0x542fcfa6,
        })) >> 128
    } else {
        ratio
    };
    //0x9aa508b5b7a84e1c677de54f3e99bc9
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x10000,
        }) != zero
    {
        (ratio * (U256 {
            a: 0x9aa508b5,
            b: 0x5b7a84e1,
            c: 0xc677de54,
            d: 0xf3e99bc9,
        })) >> 128
    } else {
        ratio
    };
    //0x5d6af8dedb81196699c329225ee604
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x20000,
        }) != zero
    {
        (ratio * (U256 {
            a: 0x5d6af8de,
            b: 0xdb8119669,
            c: 0x6699c329,
            d: 0x225ee604,
        })) >> 128
    } else {
        ratio
    };  
    //0x2216e584f5fa1ea926041bedfe98
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x40000,
        }) != zero
    {
        (ratio * (U256 {
            a: 0x2216e584,
            b: 0xf5fa1ea9,
            c: 0x1ea92604,
            d: 0x1bedfe98,
        })) >> 128
    } else {
        ratio
    }; 
    //0x48a170391f7dc42444e8fa2
    let ratio = if (absTick
        & U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0x80000,
        }) != zero
    {
        (ratio * U256 {
            a: 0x00000000,
            b: 0x48a17039,
            c: 0x91f7dc42,
            d: 0x444e8fa2,
        }) >> 128
    } else {
        ratio
    };
    if (tick > I24::from_uint(0)) {
        let ratio = U256::max() / ratio;
    }
    // shr 128 to downcast to a U128
    let round_up: U256 = if (ratio % (U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 1,
        }) << 128) == (U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0,
        })
    {
        U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0,
        }
    } else {
        U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 1,
        }
    };
    let price: U256 = ratio + round_up;
    return Q64x64 {
        value: U128 {
            upper: price.b,
            lower: price.c,
        },
    };
}

pub fn MIN_SQRT_PRICE() -> Q64x64 {
    Q64x64 {
        value: U128 {
            upper: 0,
            lower: 0,
        },
    }
}

pub fn MAX_SQRT_PRICE() -> Q64x64 {
    Q64x64 {
        value: U128 {
            upper: 0,
            lower: 0,
        },
    }
}

pub fn get_tick_at_price(sqrt_price: Q64x64) -> I24 {
    check_sqrt_price_bounds(sqrt_price);

    // square price
    let mut price: Q128x128 = full_multiply(sqrt_price, sqrt_price);

    // base value for tick change -> 1.0001
    let mut tick_base = Q128x128 {
        value: U256 {
            a: 0,
            b: 0,
            c: (10001 << (64 - 4)),
            d: 0,
        },
    };

    //TODO: should we round up?
    // change of base; log base 1.0001 (price) = log base 2 (price) / log base 2 (1.0001)
    let log_base_tick_of_price: I24 = price.binary_log() / tick_base.binary_log();

    // return base 1.0001 price
    log_base_tick_of_price
}
