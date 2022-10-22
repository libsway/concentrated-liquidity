contract;

dep cl_libs;

use core::num::*;
use std::{
    revert::require,
    identity::*,
    contract_id::*,
    address::Address,
    u128::U128,
    storage::StorageMap,
    token::transfer,
    result::*,
    chain::auth::*,
};

use cl_libs::I24::*;
use cl_libs::Q64x64::*;
use cl_libs::dydx_math::*;
use cl_libs::tick_math::*;
use cl_libs::tick::*;

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
    fn burn(lower: I24, upper: I24, amount: u64) -> (u64, u64, u64, u64);

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

    // ticks: StorageMap<I24, Tick> = (),
    // positions: StorageMap<(Identity, I24, I24), Position> = (),
}

impl ConcentratedLiquidityPool for Contract {
    #[storage(read, write)]
    fn swap(recipient: Address, token_zero_to_one: bool, amount: u64, sprtPriceLimit: Q64x64) -> u64 {
        // feeAmount: 0,
        // totalFeeAmount: 0,
        // protocolFee: 0,
        // feeGrowthGlobalA: zeroForOne ? feeGrowthGlobal1 : feeGrowthGlobal0,
        // feeGrowthGlobalB: zeroForOne ? feeGrowthGlobal0 : feeGrowthGlobal1,
        // currentPrice: uint256(price),
        // currentLiquidity: uint256(liquidity),
        // input: inAmount,
        // nextTickToCross: zeroForOne ? nearestTick : ticks[nearestTick].nextTick
        // set local vars
        let mut fee_amount         = 0;
        let mut total_fee_amount   = 0;
        let mut protocol_fee       = 0;
        let mut fee_growth_global0 = 0;
        let mut fee_growth_global1 = 0;
        let mut current_price      = price;
        let mut current_liquidity  = liquidity;
        let amount_in_left         = amount;
        let next_tick_to_cross     = if token_zero_to_one { nearest_tick } else { ticks.get(nearest_tick).next_tick };
        // return value
        let mut amount_out = 0;

        while amount_in != 0 {
            let next_tick_price = get_price_sqrt_at_tick(next_tick_to_cross);
            let output = 0;
            let cross = false;

            if token_zero_to_one {
                // token0 (x) for token1 (y)
                // decreasing price
                let max_dx = get_dx(current_liquidity, next_tick_price, current_price, false);
                if amount_in_left <= max_dx {
                    //TODO: only represents max u64 in liquidity (max possible is max u128)
                    liquidity_padded = ~Q64x64::from(~U128::from(current_liquidity.value.lower, 0));
                    //TODO: needs to be converted to a Q64x64
                    let mut new_price = mul_div_rounding_up_u256(liquidity_padded, current_price, liquidity_padded + current_price * amount_in_left);

                    if !((next_tick_price < new_price || next_tick_price == new_price) && new_price < current_price) {
                        new_price = mul_div_rounding_up_u256(~U256::from(0,1,0,0), liquidity_padded, liquidity_padded / current_price + amount_in_left);
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
            } else {
                // token1 (y) for token0 (x)
                // increasing price
                let max_dy = get_dy(current_liquidity, current_price, next_tick_price, false);

                if amount_in_left < max_dy || amount_in_left == max_dy {
                    //TODO: what is this constant? :thonk:
                    new_price = current_price + mul_div(amount_in_left, 0x1000000000000000000000000, current_liquidity);

                    output = get_dx(current_liquidity, current_price, new_price, false);
                    current_price = new_price;
                    amount_in_left = 0;
                } else {
                    // we need to cross the next tick
                    output = get_dx(current_liquidity, current_price, next_tick_price, false);
                    current_price = next_tick_price;
                    cross = true;
                    amount_in_left -= max_dy;
                }
                //TODO: bar_fee of 0?
                (total_fee_amount, amount_out, protocol_fee, fee_growth_globalA) = handle_fees(
                    output,
                    swap_fee,
                    0,
                    current_liquidity,
                    total_fee_amount,
                    amount_out,
                    protocol_fee,
                    fee_growth_globalA
                );(
                if cross {
                    (current_liquidity, next_tick_to_cross) = tick_cross(
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
                if current_liquidity == 0 {
                    // find the next tick with liquidity
                    current_price = get_price_sqrt_at_tick(next_tick_to_cross);
                    (current_liquidity, next_tick_to_cross) = tick_cross(
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

        price = current_price;

        let new_nearest_tick = if token_zero_to_one { next_tick_to_cross } else { tick.get(next_tick_to_cross).prev_tick };

        if nearest_tick != new_nearest_tick {
            nearest_tick = new_nearest_tick;
            liquidity = current_liquidity;
        }

        _update_reserves(token_zero_to_one, amount_in, amount_out);
        _update_fees(token_zero_to_one, fee_growth_globalA, protocol_fee);

        if token_zero_to_one {
            //transfer token1 amount_out recipient
            //emit Swap(recipient, token1, token0, inAmount, amountOut)
        } else {
            //transfer token0 amount_out recipient
           // emit Swap(recipient, token1, token0, inAmount, amountOut)
        }
        amount_out
    }

    #[storage(read)]
    fn quote_amount_in(token_zero_to_one: bool, amount_out: u64) -> u64 {
        10
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
    fn burn(lower: I24, upper: I24, amount: U128) -> (u64, u64, u64, u64) {
        let price_lower = get_price_sqrt_at_tick(lower);
        let price_upper = get_price_sqrt_at_tick(upper);
        let current_price = storage.price;

        // _updateSecondsPerLiquidity(uint256(liquidity));

        if ((price_lower < current_price) || (price_lower == current_price)) && current_price > price_upper {
            storage.liquidity -=amount;
        }

        let (token0_amount, token1_amount) = get_amounts_for_liquidity(price_upper, price_lower, current_price, amount, false);

        // if (amount > uint128(type(int128).max)) revert Overflow();

        let sender: Identity= msg_sender().unwrap();

        let (amount0_fees, amount1_fees) = _update_position(sender, lower, upper, liquidity_minted);

        let amount0:u64 = token0_amount + amount0_fees;
        let amount1:u64 = token1_amount + amount1_fees;

        storage.reserve0 -= amount0;
        storage.reserve1 -= amount1;

        transfer(amount0, storage.token0, sender);
        transfer(amount1, storage.token1, sender);

        // nearestTick = Ticks.remove(ticks, lower, upper, amount, nearestTick);

        (0,0,0,0)
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

    let lower: Tick = storage.ticks.get(lower_tick).unwrap();
    let upper: Tick = storage.ticks.get(upper_tick).unwrap();

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
