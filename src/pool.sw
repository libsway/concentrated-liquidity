contract;

dep cl_libs;

use core::num::*;
use std::{
    revert::require,
    identity::*,
    contract_id::*,
    address::Address,
    u128::*,
    u256::*,
    storage::StorageMap,
    token::transfer,
    result::*,
    chain::auth::*,
};

use cl_libs::I24::*;
use cl_libs::Q64x64::*;
use cl_libs::Q128x128::*;
use cl_libs::dydx_math::*;
use cl_libs::tick_math::*;
use cl_libs::tick::*;
use cl_libs::full_math::*;
use cl_libs::swap_lib::*;

pub enum ConcentratedLiquidityErrors {
    Locked: (),
    ZeroAddress: (),
    InvalidToken: (),
    InvalidSwapFee: (),
    LiquidityOverflow: (),
    Token0Missing: (),
    Token1Missing: (),
    InvalidTick: (),
    LowerEven: (),
    UpperOdd: (),
    MaxTickLiquidity: (),
    Overflow: (),
}

struct Position {
    liquidity: U128,
    fee_growth_inside0: u64,
    fee_growth_inside1: u64,
}

abi ConcentratedLiquidityPool {
    // Core functions
    #[storage(read, write)]
    fn set_price(price : Q64x64);

    #[storage(read, write)]
    fn mint(lower_old: I24, lower: I24, upper_old: I24, upper: I24, amount0_desired: u64, amount1_desired: u64) -> U128;

    #[storage(read, write)]
    fn collect(tickLower: I24, tickUpper: I24) -> (u64, u64);

    #[storage(read, write)]
    fn burn(lower: I24, upper: I24, amount: U128) -> (u64, u64, u64, u64);

    #[storage(read, write)]
    fn swap(recipient: Address, token_zero_to_one: bool, amount: u64, sprtPriceLimit: Q64x64) -> u64;

    #[storage(read)]
    fn quote_amount_in(token_zero_to_one: bool, amount_out: u64) -> u64;

    #[storage(read, write)]
    fn collect_protocol_fee() -> (u64, u64);

    #[storage(read)]
    fn get_price_and_nearest_tick() -> (Q64x64, I24);

    #[storage(read)]
    fn get_protocol_fees() -> (u64, u64);

    #[storage(read)]
    fn get_reserves() -> (u64, u64);
}

// Should be all storage variables
storage { 

    token0: ContractId = ~ContractId::from(0x0000000000000000000000000000000000000000000000000000000000000000),
    token1: ContractId = ~ContractId::from(0x0000000000000000000000000000000000000000000000000000000000000000),

    max_fee: u32 = 100000,
    tick_spacing: u32 = 10, // implicitly a u24
    swap_fee: u32 = 2500,
    
    //bar_fee_to: Identity = (),

    liquidity: U128 = U128{upper: 0, lower: 0},

    seconds_growth_global: U128 = U128{upper: 0, lower: 0},
    last_observation: u32 = 0,

    fee_growth_global0: u64 = 0,
    fee_growth_global1: u64 = 0,

    bar_fee: u64 = 0,

    token0_protocol_fee: u64 = 0,
    token1_protocol_fee: u64 = 0,

    reserve0: u64 = 0,
    reserve1: u64 = 0,

    // Orginally Sqrt of price aka. √(y/x), multiplied by 2^64.
    price: Q64x64 = Q64x64 { value : U128 {upper: 0, lower: 0} }, 
    
    nearest_tick: I24 = I24 { underlying: 2147483648u32}, // Zero

    unlocked: bool = false,

    ticks: StorageMap<I24, Tick> = StorageMap {},
    positions: StorageMap<(Identity, I24, I24), Position> = StorageMap {},
}

impl ConcentratedLiquidityPool for Contract {
    #[storage(read, write)]
    fn swap(recipient: Address, token_zero_to_one: bool, amount: u64, sprtPriceLimit: Q64x64) -> u64 {
        // set local vars
        let mut fee_amount         = 0;
        let mut total_fee_amount   = 0;
        let mut protocol_fee       = 0;
        let mut fee_growth_global0 = 0;
        let mut fee_growth_global1 = 0;
        let mut current_price      = storage.price;
        let mut current_liquidity  = storage.liquidity;
        let mut amount_in_left     = ~U128::from(0, amount);
        let next_tick_to_cross     = if token_zero_to_one { storage.nearest_tick } else { storage.ticks.get(storage.nearest_tick).next_tick };
        // return value
        let mut amount_out = 0;

        while amount_in_left != 0 {
            let mut next_tick_price = get_price_sqrt_at_tick(next_tick_to_cross);
            let mut output: U128 = U128{upper:0,lower:0};
            let mut cross = false;
            if token_zero_to_one {
                // token0 (x) for token1 (y)
                // decreasing price
                let max_dx : U128 = get_dx(current_liquidity, next_tick_price, current_price, false);
                if amount_in_left <= max_dx {
                    //TODO: only represents max u64 in liquidity (max possible is max u128)
                    let liquidity_padded = Q128x128 { value: ~U256::from(current_liquidity.upper, current_liquidity.lower, 0, 0) };
                    //TODO: needs to be converted to a Q64x64
                    let mut new_price = mul_div_rounding_up_q64x64(current_liquidity, current_price.value, liquidity_padded + current_price * ~Q64x64::from(U128{upper:0, lower: amount_in_left}));

                    if !((next_tick_price < new_price || next_tick_price == new_price) && new_price < current_price) {
                        let price_cast = ~U128::from(1, 0);
                        new_price = mul_div_rounding_up_q64x64(
                            price_cast, // TODO someone check this
                            liquidity_padded, 
                            liquidity_padded / current_price + ~Q64x64::from(~U128::from(amount_in_left, 0))
                        );
                    }
                    output = get_dy(current_liquidity, new_price, current_price, false);
                    current_price = new_price;
                    amount_in_left = 0;
                } else {
                    // we need to cross the next tick
                    output = get_dy(current_liquidity, next_tick_price, current_price, false);
                    current_price = next_tick_price;
                    cross = true;
                    amount_in_left -= max_dx;
                }
            }
            else {
                // token1 (y) for token0 (x)
                // increasing price
                let max_dy = get_dy(current_liquidity, current_price, next_tick_price, false);
                if amount_in_left < max_dy || amount_in_left == max_dy {
                    //TODO: what is this constant? :thonk:
                    let new_price = current_price + mul_div(amount_in_left, ~u64::max(), current_liquidity);

                    output = get_dx(current_liquidity, current_price, new_price, false);
                    current_price = new_price;
                    amount_in_left = ~U128::from(0, 0);
                } else {
                    // we need to cross the next tick
                    output = get_dx(current_liquidity, current_price, next_tick_price, false);
                    current_price = next_tick_price;
                    cross = true;
                    amount_in_left -= max_dy;
                }
                //TODO: bar_fee of 0?
                let (total_fee_amount, amount_out, protocol_fee, fee_growth_globalA) = handle_fees(
                    output,
                    storage.swap_fee,
                    0,
                    current_liquidity,
                    total_fee_amount,
                    amount_out,
                    protocol_fee,
                    fee_growth_globalA
                );
            }
            if cross {
                let (current_liquidity, next_tick_to_cross) = tick_cross(
                    ticks,
                    next_tick_to_cross,
                    seconds_growth_global,
                    current_liquidity,
                    fee_growth_globalA,
                    fee_growth_globalB,
                    token_zero_to_one,
                    tick_spacing
                );
                if current_liquidity == 0 {
                    // find the next tick with liquidity
                    current_price = get_price_sqrt_at_tick(next_tick_to_cross);
                    let (current_liquidity, next_tick_to_cross) = tick_cross(
                        ticks,
                        next_tick_to_cross,
                        seconds_growth_global,
                        current_liquidity,
                        fee_growth_globalA,
                        fee_growth_globalB,
                        token_zero_to_one,
                        tick_spacing
                    );
                }
            }
        }

        storage.price = current_price;

        let new_nearest_tick = if token_zero_to_one { next_tick_to_cross } else { storage.ticks.get(next_tick_to_cross).prev_tick };

        if storage.nearest_tick != new_nearest_tick {
            storage.nearest_tick = new_nearest_tick;
            storage.liquidity = current_liquidity;
        }

        let amount_in = amount;

        _update_reserves(token_zero_to_one, amount_in, amount_out);
        _update_fees(token_zero_to_one, fee_growth_globalA, protocol_fee);

        if token_zero_to_one {
            //transfer token1 amount_out recipient
            //emit Swap(recipient, token1, token0, inAmount, amountOut)
        } else {
            //transfer token0 amount_out recipient
           // emit Swap(recipient, token1, token0, inAmount, amountOut)
        }
    }


    #[storage(read)]
    fn quote_amount_in(token_zero_to_one: bool, amount_out: u64) -> u64 {
        let mut amount_out_no_fee = (amount_out * 1000000) / (1000000 - storage.swap_fee) + 1;
        let mut current_price = storage.price;
        let mut current_liquidity = storage.liquidity;
        let mut next_tick_to_cross = if token_zero_to_one { storage.nearest_tick } else { storage.ticks.get(nearest_tick).next_tick };
        let mut next_tick: I24 = ~I24::new();
        let tick_spacing = storage.tick_spacing;
        let swap_fee = storage.swap_fee;

        let mut final_amount_in: U128 = ~U128::from(0,0);
        let mut final_amount_out: U128 = ~U128::from(0,amount_out);
        let mut amount_out_no_fee = ~U128::from(0, amount_out_no_fee);
        while amount_out_no_fee != ~U128::from(0,0) {
            let mut next_tick_price = get_price_sqrt_at_tick(next_tick_to_cross);
            if token_zero_to_one {
                let mut max_dy = get_dy(current_liquidity, next_tick_price, current_price, false);
                if amount_out_no_fee < max_dy || amount_out_no_fee == max_dy {
                    final_amount_out = (final_amount_out * 1000000) / (1000000 - swap_fee) + 1;
                    let new_price = current_price - mul_div(final_amount_out, U128{upper:0, lower:~u64::max()}, current_liquidity);
                    final_amount_in += get_dx(current_liquidity, new_price, current_price, false) + 1;
                    break;
                } else {
                    if next_tick_to_cross / ~I24::from_uint(tick_spacing) % ~I24::from_uint(2) == ~I24::new(){
                        current_liquidity -= storage.ticks.get(next_tick_to_cross).liquidity;
                    } else {
                        current_liquidity += storage.ticks.get(next_tick_to_cross).liquidity;
                    }
                    amount_out_no_fee -= max_dy - 1; // handle rounding issues
                    let fee_amount = mul_div_rounding_up( max_dy, swap_fee, 1000000);
                    if final_amount_out < (max_dy - swap_fee) || final_amount_out == (max_dy - swap_fee) {
                        break;
                    }
                    final_amount_out -= (max_dy - fee_amount);
                    next_tick = storage.ticks.get(next_tick_to_cross).prev_tick;
                }
                
            } else {
                let max_dx = get_dx(current_liquidity, current_price, next_tick_price, false);

                if amount_out_no_fee < max_dx || amount_out_no_fee == max_dx {
                    final_amount_out = (final_amount_out * 1000000) / (1000000 - swap_fee) + 1;

                    let liquidity_padded = ~Q64x64::from(~U128::from(current_liquidity.lower, 0));
                    let mut new_price = mul_div_rounding_up_u256(liquidity_padded, current_price, liquidity_padded - current_price * final_amount_out);

                    if !(current_price < new_price && (new_price < next_tick_price || new_price == next_tick_price)) {
                        new_price = mul_div_rounding_up_u256(~U256::from(0,1,0,0), liquidity_padded, liquidity_padded / current_price - final_amount_out);
                    }
                    final_amount_in += get_dy(current_liquidity, current_price, new_price, false) + 1;
                    break;
                } else {
                    final_amount_in += get_dy(current_liquidity, current_price, next_tick_price, false);
                    if next_tick_to_cross / ~I24::from_uint(tick_spacing) % ~I24::from_uint(2) == ~I24::new(){
                        current_liquidity += storage.ticks.get(next_tick_to_cross).liquidity;
                    } else {
                        current_liquidity -= storage.ticks.get(next_tick_to_cross).liquidity;
                    }
                    amount_out_no_fee -= max_dx + 1; // resolve rounding errors
                    let fee_amount = mul_div_rounding_up(max_dx, swap_fee, 1000000);
                    if final_amount_out < (max_dx - fee_amount) || final_amount_out == (max_dx - fee_amount){
                        break;
                    }
                    final_amount_out -= (max_dx - fee_amount);
                    next_tick = storage.ticks.get(next_tick_to_cross).next_tick;
                }
            }
            current_price = next_tick_price;
            assert(next_tick_to_cross != next_tick); // check for insufficient output liquidity
            next_tick_to_cross = next_tick;
        }
         
        final_amount_in.lower
    }

    #[storage(read, write)]
    fn set_price(price : Q64x64) {
        check_sqrt_price_bounds(price);
        let zero_price = Q64x64{ value: ~U128::from(0,0) };
        if storage.price == zero_price {
            storage.price = price;
        }

        ()
    }

    #[storage(read, write)]
    fn mint(lower_old: I24, lower: I24, upper_old: I24, upper: I24, amount0_desired: u64, amount1_desired: u64) -> U128 {
        _ensure_tick_spacing(upper, lower).unwrap();

        let price_lower = get_price_sqrt_at_tick(lower);
        let price_upper = get_price_sqrt_at_tick(upper);
        let current_price = storage.price;

        let liquidity_minted = get_liquidity_for_amounts(price_lower, price_upper, current_price, ~U128::from(0, amount1_desired), ~U128::from(0, amount0_desired));

        // _updateSecondsPerLiquidity(uint256(liquidity));

        let sender: Identity= msg_sender().unwrap();

        let (amount0_fees, amount1_fees) = _update_position(sender, lower, upper, liquidity_minted);

        if amount0_fees > 0 {
            transfer(amount0_fees, storage.token0, sender);
            storage.reserve0 -= amount0_fees;
        }
        if amount1_fees > 0 {
            transfer(amount1_fees, storage.token1, sender);
            storage.reserve1 -= amount1_fees;
        }
        if (price_lower < current_price || price_lower == current_price) && (current_price < price_upper) {
            storage.liquidity += liquidity_minted;
        }

        /* nearestTick = Ticks.insert(
            ticks,
            feeGrowthGlobal0,
            feeGrowthGlobal1,
            secondsGrowthGlobal,
            mintParams.lowerOld,
            mintParams.lower,
            mintParams.upperOld,
            mintParams.upper,
            uint128(liquidityMinted),
            nearestTick,
            uint160(currentPrice)
        ); */

        let (amount0_actual, amount1_actual) = get_amounts_for_liquidity(price_upper, price_lower, current_price, liquidity_minted, true);

        //IPositionManager(msg.sender).mintCallback(token0, token1, amount0Actual, amount1Actual, mintParams.native);

        if amount0_actual != 0 {
            storage.reserve0 += amount0_actual;
            // if (reserve0 > _balance(token0)) revert Token0Missing();
        }

        if amount1_actual != 0 {
            storage.reserve1 += amount1_actual;
            // if (reserve0 > _balance(token0)) revert Token0Missing();
        }

        liquidity_minted
    }

    #[storage(read, write)]
    fn burn(lower: I24, upper: I24, liquidity_amount: U128) -> (u64, u64, u64, u64) {
        let price_lower = get_price_sqrt_at_tick(lower);
        let price_upper = get_price_sqrt_at_tick(upper);
        let current_price = storage.price;

        // _updateSecondsPerLiquidity(uint256(liquidity));

        if ((price_lower < current_price) || (price_lower == current_price)) && current_price > price_upper {
            storage.liquidity -= liquidity_amount;
        }

        let sender: Identity= msg_sender().unwrap();

        let (amount0_fees, amount1_fees) = _update_position(sender, lower, upper, liquidity_amount);

         let (token0_amount, token1_amount) = get_amounts_for_liquidity(price_upper, price_lower, current_price, liquidity_amount, false);

        let amount0:u64 = token0_amount + amount0_fees;
        let amount1:u64 = token1_amount + amount1_fees;

        storage.reserve0 -= amount0;
        storage.reserve1 -= amount1;

        transfer(amount0, storage.token0, sender);
        transfer(amount1, storage.token1, sender);

        // nearestTick = Ticks.remove(ticks, lower, upper, amount, nearestTick);
        //TODO: get fee growth in range and calculate fees based on liquidity
        (token0_amount, token1_amount, 0, 0)
    }

    #[storage(read, write)]
    fn collect_protocol_fee() -> (u64, u64) {
        let mut amount0 = 0;
        let mut amount1 = 0;
        if storage.token0_protocol_fee > 1 {
            amount0 = storage.token0_protocol_fee;
            storage.token0_protocol_fee = 0;
            storage.reserve0 -= amount0;
            //transfer(amount0, storage.token0, storage.bar_fee_to)
        }
        if storage.token1_protocol_fee > 1 {
            amount1 = storage.token0_protocol_fee;
            storage.token1_protocol_fee = 0;
            storage.reserve1 -= amount1;
            //transfer(amount1, storage.token1, storage.bar_fee_to)
        }

        (amount0, amount1)
    }

    #[storage(read, write)]
    fn collect(tick_lower: I24, tick_upper: I24) -> (u64, u64) {
        let sender: Identity= msg_sender().unwrap();
        let (amount0_fees, amount1_fees) = _update_position(sender, tick_lower, tick_upper, ~U128::from(0,0));

        storage.reserve0 -= amount0_fees;
        storage.reserve1 -= amount1_fees;

        transfer(amount0_fees, storage.token0, sender);
        transfer(amount1_fees, storage.token1, sender);

        (amount0_fees, amount1_fees)
    }

    #[storage(read)]
    fn get_price_and_nearest_tick() -> (Q64x64, I24){
        (storage.price, storage.nearest_tick)
    }

    #[storage(read)]
    fn get_protocol_fees() -> (u64, u64){
        (storage.token0_protocol_fee, storage.token1_protocol_fee)
    }

    #[storage(read)]
    fn get_reserves() -> (u64, u64){
        (storage.reserve0, storage.reserve1)
    }
}
#[storage(read)]
fn _ensure_tick_spacing(upper: I24, lower: I24) -> Result<(), ConcentratedLiquidityErrors> {
    if lower % ~I24::from_uint(storage.tick_spacing) != ~I24::from_uint(0) {
        return Result::Err(ConcentratedLiquidityErrors::InvalidTick);
    }
    if (lower / ~I24::from_uint(storage.tick_spacing)) % ~I24::from_uint(2) != ~I24::from_uint(0) {
        return Result::Err(ConcentratedLiquidityErrors::LowerEven);
    }
    if upper % ~I24::from_uint(storage.tick_spacing) != ~I24::from_uint(0) {
        return Result::Err(ConcentratedLiquidityErrors::InvalidTick);
    }
    if (upper / ~I24::from_uint(storage.tick_spacing)) % ~I24::from_uint(2) == ~I24::from_uint(0) {
        return Result::Err(ConcentratedLiquidityErrors::UpperOdd);
    }

    Result::Ok(())
}

#[storage(read, write)]
fn _update_position( owner: Identity, lower: I24, upper: I24, amount: U128) -> (u64, u64) {
    //let position = storage.positions.get((owner, lower, upper));

    let (range_fee_growth0, range_fee_growth1) = range_fee_growth(lower, upper);

    (0, 0)
}
#[storage(read,write)]
fn swap(recipient: Address, token_zero_to_one: bool, amount: u64, sprtPriceLimit: Q64x64) {
    ()
}
#[storage(read)]
fn quote_amount_in(token_zero_to_one: bool, amount_out: u64) {
    ()
}

#[storage(read, write)]
fn _update_reserves(token_zero_to_one: bool, amount_in: u64, amount_out: u64) {

    ()
}

#[storage(read, write)]
fn _update_fees(token_zero_to_one: bool, fee_growth_global: u64, protocol_fee: u64) {
    if token_zero_to_one {
        storage.fee_growth_global1 = fee_growth_global;
        storage.token1_protocol_fee += protocol_fee;
    } else {
        storage.fee_growth_global0 = fee_growth_global;
        storage.token0_protocol_fee += protocol_fee;
    }

    ()
}



#[storage(read)]
fn range_fee_growth(lower_tick : I24, upper_tick: I24) -> (u64, u64) {
    let current_tick = storage.nearest_tick;

    let lower: Tick = storage.ticks.get(lower_tick);
    let upper: Tick = storage.ticks.get(upper_tick);

    let _fee_growth_global0 = storage.fee_growth_global0;
    let _fee_growth_global1 = storage.fee_growth_global1;

    let mut fee_growth_below0:u64 = 0;
    let mut fee_growth_below1:u64 = 0;
    let mut fee_growth_above0:u64 = 0;
    let mut fee_growth_above1:u64 = 0;

    if lower_tick < current_tick || lower_tick == current_tick {
        fee_growth_below0 = lower.fee_growth_outside0;
        fee_growth_below1 = lower.fee_growth_outside1;
    } else {
        fee_growth_below0 = _fee_growth_global0 - lower.fee_growth_outside0;
        fee_growth_below1 = _fee_growth_global1 - lower.fee_growth_outside1;
    }

    if (current_tick < upper_tick) {
        fee_growth_above0 = upper.fee_growth_outside0;
        fee_growth_above1 = upper.fee_growth_outside1;
    } else {
        fee_growth_above0 = _fee_growth_global0 - upper.fee_growth_outside0;
        fee_growth_above1 = _fee_growth_global1 - upper.fee_growth_outside1;
    }

    let fee_growth_inside0 = _fee_growth_global0 - fee_growth_below0 - fee_growth_above0;
    let fee_growth_inside1 = _fee_growth_global1 - fee_growth_below1 - fee_growth_above1;

    (fee_growth_inside0, fee_growth_inside1)
}
