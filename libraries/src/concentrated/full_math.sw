library full_math;

dep Q128x128;
dep Q64x64;

use std::{result::Result, u128::U128, u256::U256};
use std::revert::revert;
use Q128x128::Q128x128;
use Q64x64::Q64x64;

pub enum FullMathError {
    DivisionByZero: (),
}

fn log2(number: u64) -> u64 {
    let two = 2;
    asm(r1: number, r2: 2, r3) {
        mlog r3 r1 r2;
        r3: u64
    }
}

pub fn msb_idx(input: U256) -> u32 {
    let mut msb_idx = 0;
    if input.a > 0 {
        msb_idx += 192;
        msb_idx += log2(input.a);
    } else if input.b > 0 {
        msb_idx += 128;
        msb_idx += log2(input.b);
    } else if input.c > 0 {
        msb_idx += 64;
        msb_idx += log2(input.c);
    } else {
        msb_idx += log2(input.d);
    }
    msb_idx
}

impl U256 {
    // Divide a `U256` by a `U256`. Panics if divisor is zero.
    // refer to https://stackoverflow.com/a/5284915
    fn div(self, divisor: Self) -> Self {
        let zero = U256::from((0, 0, 0, 0));
        let one = U256::from((0, 0, 0, 1));

        assert(divisor != zero);

        //TODO: this evaluates to true even when it shouldn't
        //if divisor > self { return 0; }

        if self.a == 0 && self.b == 0 && divisor.a == 0 && divisor.b == 0 {
            let res = U128::from((self.c, self.d)) / U128::from((divisor.c, divisor.d));
            return U256::from((0, 0, res.upper, res.lower));
        }

        let self_msb_idx = msb_idx(self);
        let div_msb_idx  = msb_idx(divisor);

        let mut num = self;
        let mut div = divisor;

        div <<= (self_msb_idx - div_msb_idx);

        let mut quotient = U256::from((0, 0, 0, 0));

        let mut i =0;

        if self_msb_idx > div_msb_idx {
            i = (self_msb_idx - div_msb_idx - 1);
        } else {
            return one;
        }

        while true {
            if num > div || num == div{
                quotient += one;
                num -= div;
            }
            num <<= 1;
            quotient <<= 1;

            if i == 0 {
                return quotient;
            }
            i -= 1;
        }
        quotient
    }

    fn mul(self, other: Self) -> Self {
            // Both upper words cannot be non-zero simultaneously. Otherwise, overflow is guaranteed.
            assert(self.a == 0 || other.a == 0);

            if self.a != 0 {
                // If `self.a` is non-zero, all words of `other`, except for `d`, should be zero. 
                // Otherwise, overflow is guaranteed.
                assert(other.b == 0 && other.c == 0);
                U256::from((self.a * other.d, 0, 0, 0))
            } else if other.a != 0 {
                // If `other.a` is non-zero, all words of `self`, except for `d`, should be zero.
                // Otherwise, overflow is guaranteed.
                assert(self.b == 0 && self.c == 0);
                U256::from((other.a * self.d, 0, 0, 0))
            } else {
                if self.b != 0 {
                    // If `self.b` is non-zero, `other.b` has  to be zero. Otherwise, overflow is 
                    // guaranteed because:
                    // `other.b * 2 ^ (64 * 2) * self.b * 2 ^ (62 ^ 2) > 2 ^ (64 * 4)`
                    assert(other.b == 0);
                    let result_b_d = self.b.overflowing_mul(other.d);
                    let result_c_c = self.c.overflowing_mul(other.c);
                    let result_c_d = self.c.overflowing_mul(other.d);
                    let result_d_c = self.d.overflowing_mul(other.c);
                    let result_d_d = self.d.overflowing_mul(other.d);

                    U256::from((
                        self.b * other.c + result_b_d.upper,
                        result_b_d.lower + result_c_d.upper + result_d_c.upper,
                        result_d_d.upper + result_c_d.lower + result_d_c.lower,
                        result_d_d.lower,
                    ))
                } else if other.b != 0 {
                    // If `other.b` is nonzero, `self.b` has to be zero. Otherwise, overflow is 
                    // guaranteed because: 
                    // `other.b * 2 ^ (64 * 2) * self.b * 2 ^ (62 ^ 2) > 2 ^ (64 * 4)`.
                    assert(self.b == 0);
                    let result_b_d = other.b.overflowing_mul(self.d);
                    let result_c_c = other.c.overflowing_mul(self.c);
                    let result_c_d = other.c.overflowing_mul(self.d);
                    let result_d_c = other.d.overflowing_mul(self.c);
                    let result_d_d = other.d.overflowing_mul(self.d);

                    U256::from((
                        other.b * self.c + result_b_d.upper,
                        result_b_d.lower + result_c_d.upper + result_d_c.upper,
                        result_d_d.upper + result_c_d.lower + result_d_c.lower,
                        result_d_d.lower,
                    ))
                } else {
                    let result_c_c = other.c.overflowing_mul(self.c);
                    let result_c_d = self.c.overflowing_mul(other.d);
                    let result_d_c = self.d.overflowing_mul(other.c);
                    let result_d_d = self.d.overflowing_mul(other.d);

                    U256::from((
                        result_c_c.upper,
                        result_c_c.lower + result_c_d.upper + result_d_c.upper,
                        result_d_d.upper + result_c_d.lower + result_d_c.lower,
                        result_d_d.lower,
                    ))
                }
            }
        }
}

pub fn mul_div(base: U128, factor: U128, denominator: U128) -> U128 {
    let base_u256 = U256 {
        a: 0,
        b: 0,
        c: base.upper,
        d: base.lower,
    };
    let factor_u256 = U256 {
        a: 0,
        b: 0,
        c: factor.upper,
        d: factor.lower,
    };
    let denominator_u256 = U256::from((
        0,
        0,
        denominator.upper,
        denominator.lower,
    ));
    //TODO: this division does not work properly
    let res_u256 = (base_u256.mul(factor_u256).div(denominator_u256));
    //TODO:
    // if (res_u256.a != 0) || (res_u256.b != 0) {
    //     // panic on overflow
    //     revert(0);
    // }

    U128 {
        upper: res_u256.c,
        lower: res_u256.d,
    }
}
pub fn mul_div_u64(base: u64, factor: u64, denominator: u64) -> u64 {
    let base = U128 {
        upper: 0,
        lower: base,
    };
    let factor = U128 {
        upper: 0,
        lower: factor,
    };
    let denominator = U128 {
        upper: 0,
        lower: denominator,
    };
    let res = (base * factor) / (denominator);
    if res.upper != 0 {
        // panic on overflow
        revert(0);
    }
    res.lower
}
pub fn mul_div_rounding_up_u64(base: u64, factor: u64, denominator: u64) -> u64 {
    let base = U128 {
        upper: 0,
        lower: base,
    };
    let factor = U128 {
        upper: 0,
        lower: factor,
    };
    let denominator = U128 {
        upper: 0,
        lower: denominator,
    };
    let mut res = (base * factor) / denominator;

    if (res * denominator) != (factor * base) {
        res += U128 {
            upper: 0,
            lower: 1,
        };
    }
    if res.upper != 0 {
        // panic on overflow
        revert(0);
    }

    let result: u64 = res.lower;

    result
}
pub fn mul_div_rounding_up(base: U128, factor: U128, denominator: U128) -> U128 {
    let base_u256 = U256 {
        a: 0,
        b: 0,
        c: base.upper,
        d: base.lower,
    };
    let factor_u256 = U256 {
        a: 0,
        b: 0,
        c: factor.upper,
        d: factor.lower,
    };
    let denominator_u256 = U256 {
        a: 0,
        b: 0,
        c: denominator.upper,
        d: denominator.lower,
    };
    let mut res_u256 = base_u256.mul(factor_u256).div(denominator_u256);
    if res_u256.mul(denominator_u256) != base_u256.mul(factor_u256) {
        res_u256 = res_u256 + U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 1,
        };
    }
    if (res_u256.a != 0) || (res_u256.b != 0) {
        // panic on overflow
        revert(0);
    }
    U128 {
        upper: res_u256.c,
        lower: res_u256.d,
    }
}
pub fn mul_div_u256(base: U256, factor: U128, denominator: U128) -> U128 {
    let base_u256 = base;
    let factor_u256 = U256 {
        a: 0,
        b: 0,
        c: factor.upper,
        d: factor.lower,
    };
    let denominator_u256 = U256 {
        a: 0,
        b: 0,
        c: denominator.upper,
        d: denominator.lower,
    };
    let res_u256 = base_u256.mul(factor_u256).div(denominator_u256)
    ;
    if (res_u256.a != 0) || (res_u256.b != 0) {
        // panic on overflow
        revert(0);
    }
    U128 {
        upper: res_u256.c,
        lower: res_u256.d,
    }
}
pub fn mul_div_rounding_up_u256(base: U256, factor: U128, denominator: U128) -> U128 {
    let base_u256 = base;
    let factor_u256 = U256 {
        a: 0,
        b: 0,
        c: factor.upper,
        d: factor.lower,
    };
    let denominator_u256 = U256 {
        a: 0,
        b: 0,
        c: denominator.upper,
        d: denominator.lower,
    };
    let res_u256 = base_u256.mul(factor_u256).div(denominator_u256);
    if (res_u256.a != 0) || (res_u256.b != 0) {
        // panic on overflow
        revert(0);
    }
    let mut res_128 = U128 {
        upper: res_u256.c,
        lower: res_u256.d,
    };
    if res_u256 * denominator_u256 != base_u256 * factor_u256 {
        res_128 = res_128 + U128 {
            upper: 0,
            lower: 1,
        };
    }

    res_128
}

pub fn mul_div_q64x64(base: Q128x128, factor: Q128x128, denominator: Q128x128) -> Q64x64 {
    let mut res: Q128x128 = (base * factor) / denominator;
    if (res.value.a != 0) || (res.value.b != 0) {
        // panic on overflow
        revert(0);
    }
    Q64x64 {
        value: U128 {
            upper: res.value.b,
            lower: res.value.c,
        },
    }
}

pub fn mul_div_rounding_up_q64x64(
    base: Q128x128,
    factor: Q128x128,
    denominator: Q128x128,
) -> Q64x64 {
    let mut res: Q128x128 = (base * factor) / denominator;
    if res * denominator != base * factor {
        res = res + Q128x128 {
            value: U256 {
                a: 0,
                b: 0,
                c: 0,
                d: 1,
            },
        };
    }
    if (res.value.a != 0) || (res.value.b != 0) {
        // panic on overflow
        revert(0);
    }
    Q64x64 {
        value: U128 {
            upper: res.value.b,
            lower: res.value.c,
        },
    }
}

#[test]
fn full_math_mul_div_u64() {
}

#[test]
fn full_math_mul_div() {
}

#[test]
fn full_math_mul_div_rounding_up_u64() {
}

#[test]
fn full_math_mul_div_rounding_up() {
}

#[test]
fn full_math_mul_div_u256() {
}

#[test]
fn full_math_mul_div_rounding_up_u256() {
}

#[test]
fn full_math_mul_div_q64x64() {
}

#[test]
fn full_math_mul_div_rounding_up_q64x64() {
}

