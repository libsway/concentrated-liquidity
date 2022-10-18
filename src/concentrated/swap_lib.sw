library swap_lib;

dep full_math;

use full_math::{mul_div, mul_div_rounding_up};

fn handle_fees(output: u64, swap_fee: u32, bar_fee: u64, current_liquidity: u64, total_fee_amount: u64, amount_out: u64, protocol_fee: u64, fee_growth_global:u64) -> (u64, u64, u64, u64) {
    let PRECISION:u64 = 100;
    let mut fee_amount: u64 = mul_div_rounding_up(output, swap_fee, 1e6);
    let mut total_fee_amount = total_fee_amount;
    let mut amount_out = amount_out;
    let mut protocol_fee = protocol_fee;

    total_fee_amount = total_fee_amount + fee_amount;

    amount_out = amount_out + (output - fee_amount);

    let fee_delta:u64 = mul_div_rounding_up(fee_amount, bar_fee, 1e4);
    
    protocol_fee = + protocol_fee + fee_delta;

    fee_amount = fee_amount - fee_delta;

    let fee_growth_global = fee_growth_global + mul_div(fee_amount, PRECISION, current_liquidity);

    return (total_fee_amount, amount_out, protocol_fee, fee_growth_global);
}

