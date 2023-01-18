contract;

dep events;
dep errors;

use errors::ConcentratedLiquidityPoolErrors;
use events::{BurnEvent, InitEvent, SwapEvent, MintEvent, FlashEvent};

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
    auth::*,
    logging::log,
    call_frames::{contract_id ,msg_asset_id},
    context::msg_amount,
};

use cl_libs::I24::*;
use cl_libs::Q64x64::*;
use cl_libs::Q128x128::*;
use cl_libs::dydx_math::*;
use cl_libs::tick_math::*;
use cl_libs::full_math::*;
use cl_libs::swap_lib::*;

impl core::ops::Ord for ContractId {
    fn lt(self, other: Self) -> bool {
        self.value < other.value
    }
    fn gt(self, other: Self) -> bool {
        self.value > other.value
    }
}

impl u64 {
    fn u128(self) -> U128 {
        U128 {
            upper: 0,
            lower: self
        }
    }
}

struct Position {
    liquidity: U128,
    fee_growth_inside0: Q64x64,
    fee_growth_inside1: Q64x64,
}

struct Tick {
    prev_tick: I24,
    next_tick: I24,
    liquidity: U128,
    fee_growth_outside0: Q64x64,
    fee_growth_outside1: Q64x64,
    seconds_growth_outside: U128
}

abi ConcentratedLiquidityPool {
    // Core functions
    #[storage(read, write)]
    fn init(token0: ContractId, token1: ContractId, swap_fee: u64, sqrt_price: Q64x64, tick_spacing: u32);

    #[storage(read, write)]
    fn set_price(price : Q64x64);

    #[storage(read, write)]
    fn mint(lower_old: I24, lower: I24, upper_old: I24, upper: I24, amount0_desired: u64, amount1_desired: u64, recipient: Identity) -> U128;

    #[storage(read, write)]
    fn collect(tickLower: I24, tickUpper: I24) -> (u64, u64);

    #[storage(read, write)]
    fn burn(recipient: Identity, lower: I24, upper: I24, liquidity_amount: U128) -> (u64, u64, u64, u64);

    #[storage(read, write)]
    fn swap(sqrt_price_limit: Q64x64, recipient: Identity) -> u64;

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
    token0: ContractId = ContractId{value:0x0000000000000000000000000000000000000000000000000000000000000000},
    token1: ContractId = ContractId{value:0x0000000000000000000000000000000000000000000000000000000000000000},

    max_fee: u32 = 100000,
    tick_spacing: u32 = 10, // implicitly a u24
    swap_fee: u32 = 2500,

    liquidity: U128 = U128{upper: 0, lower: 0},

    seconds_growth_global: U256 = U256{a: 0, b: 0, c: 0, d:0},
    last_observation: u32 = 0,

    fee_growth_global0: Q64x64 = Q64x64{value : U128{upper:0,lower:0}},
    fee_growth_global1: Q64x64 = Q64x64{value : U128{upper:0,lower:0}},

    token0_protocol_fee: u64 = 0,
    token1_protocol_fee: u64 = 0,

    reserve0: u64 = 0,
    reserve1: u64 = 0,

    // Orginally Sqrt of price aka. √(y/x), multiplied by 2^64.
    sqrt_price: Q64x64 = Q64x64{value : U128{upper:0,lower:0}}, 
    
    nearest_tick: I24 = I24 { underlying: 2147483648u32}, // Zero

    unlocked: bool = false,

    ticks: StorageMap<I24, Tick> = StorageMap {},
    positions: StorageMap<(Identity, I24, I24), Position> = StorageMap {},
}

impl ConcentratedLiquidityPool for Contract {
    #[storage(read, write)]
    fn init(first_token: ContractId, second_token: ContractId, swap_fee: u64, sqrt_price: Q64x64, tick_spacing: u32) {
        require(storage.sqrt_price == Q64x64{value: U128{upper:0,lower:0}}, ConcentratedLiquidityPoolErrors::AlreadyInitialized);
        require(swap_fee <= storage.max_fee, ConcentratedLiquidityPoolErrors::InvalidSwapFee);
        require(first_token != second_token, ConcentratedLiquidityPoolErrors::InvalidToken);
        storage.token0 = if first_token < second_token { first_token }  else { second_token };
        storage.token1 = if first_token < second_token { second_token } else { first_token };
        storage.nearest_tick = get_tick_at_price(sqrt_price);
        storage.sqrt_price = sqrt_price;
        storage.swap_fee = swap_fee;
        storage.tick_spacing = tick_spacing;
        storage.unlocked = true;

        log(InitEvent {
            pool_id: contract_id(),
            token0: storage.token0,
            token1: storage.token1,
            swap_fee,
            tick_spacing: tick_spacing,
            init_price_upper: sqrt_price.value.upper,
            init_price_lower: sqrt_price.value.lower,
            init_tick: storage.nearest_tick.underlying
        });
    }
    #[storage(read, write)]
    fn swap(sqrt_price_limit: Q64x64, recipient: Identity) -> u64 {
        // sanity checks
        require(msg_amount() > 0, ConcentratedLiquidityPoolErrors::ZeroAmount);
        let token0 = storage.token0;
        let token1 = storage.token1;
        require(msg_asset_id() == token0 || msg_asset_id() == token1, ConcentratedLiquidityPoolErrors::InvalidToken);
        let amount = msg_amount();
        let token_zero_to_one = if msg_asset_id() == token0 { true } else { false };
        let mut current_price = storage.sqrt_price;
        if token_zero_to_one { require(sqrt_price_limit > current_price, ConcentratedLiquidityPoolErrors::PriceLimitExceeded) }
        else                 { require(sqrt_price_limit < current_price,  ConcentratedLiquidityPoolErrors::PriceLimitExceeded) }

        // constants
        let one_e_6_u128 = U128{upper: 0, lower: 1000000};
        let one_e_6_q128x128 = Q128x128::from_u128(one_e_6_u128);
        let one_u128 = (U128{upper: 0, lower:1});
        let one_q128x128 = Q128x128::from_uint(1);
        let zero_u128 = (U128{upper: 0, lower:0});

        // set local vars
        let mut fee_amount         = zero_u128;
        let mut total_fee_amount   = zero_u128;
        let mut protocol_fee       = zero_u128;
        let mut fee_growth_globalA = if token_zero_to_one { storage.fee_growth_global1 } else { storage.fee_growth_global0 };
        let mut fee_growth_globalB = if token_zero_to_one { storage.fee_growth_global0 } else { storage.fee_growth_global1 };
        let mut current_price      = storage.sqrt_price;
        let mut current_liquidity  = storage.liquidity;
        let mut amount_in_left     = U128{upper: 0, lower: amount};
        let mut next_tick_to_cross = if token_zero_to_one { storage.nearest_tick } else { storage.ticks.get(storage.nearest_tick).next_tick };
        
        // return value
        let mut amount_out = 0;
        // handle next_tick == 0
        while amount_in_left != zero_u128 {
            let next_tick_price = get_price_sqrt_at_tick(next_tick_to_cross);
            let mut next_price = next_tick_price;
            let mut output = 0;
            let mut cross = false;
            if token_zero_to_one {
                // token0 (x) for token1 (y)
                // decreasing price
                if next_price < sqrt_price_limit { next_price = sqrt_price_limit }
                let max_dx : U128 = get_dx(current_liquidity, next_price, current_price, false).u128();
                if amount_in_left < max_dx || amount_in_left == max_dx {
                    let liquidity_padded = Q128x128::from_u128(current_liquidity);
                    let price_padded     = Q128x128::from_q64x64(current_price.value);
                    let amount_in_padded = Q128x128::from_u128(amount_in_left);
                    let mut new_price : Q64x64 = mul_div_rounding_up_q64x64(liquidity_padded, price_padded, liquidity_padded + price_padded * amount_in_padded);

                    if !((next_price < new_price || next_price == new_price) && new_price < current_price) {
                        let price_cast = U128{upper: 1, lower: 0};
                        new_price = mul_div_rounding_up_q64x64(
                            one_q128x128,
                            liquidity_padded, 
                            liquidity_padded / price_padded + amount_in_padded
                        );
                    }
                    output = get_dy(current_liquidity, new_price, current_price, false);
                    current_price = new_price;
                    amount_in_left = zero_u128;
                } else {
                    // we need to cross the next tick
                    output = get_dy(current_liquidity, next_price, current_price, false);
                    current_price = next_price;
                    if next_price == next_tick_price { cross = true }
                    amount_in_left -= max_dx;
                }
            }
            else {
                // token1 (y) for token0 (x)
                // increasing price
                if next_price > sqrt_price_limit { next_price = sqrt_price_limit }
                let max_dy = get_dy(current_liquidity, current_price, next_price, false).u128();
                if amount_in_left < max_dy || amount_in_left == max_dy {
                    //TODO: what is this u64::max() constant for?
                    let new_price = current_price + Q64x64{ value : mul_div(amount_in_left, U128{upper: 0, lower: u64::max()}, current_liquidity)};
                    output = get_dx(current_liquidity, current_price, new_price, false);
                    current_price = new_price;
                    amount_in_left = U128{upper: 0, lower: 0};
                } else {
                    // we need to cross the next tick
                    output = get_dx(current_liquidity, current_price, next_price, false);
                    current_price = next_price;
                    amount_in_left -= max_dy;
                    if next_price == next_tick_price { cross = true }
                }
                let mut fee_growth = storage.fee_growth_global0;

                let (total_fee_amount, amount_out, protocol_fee, fee_growth_globalA) = handle_fees(
                    output,
                    storage.swap_fee,
                    current_liquidity,
                    total_fee_amount.lower,
                    amount_out,
                    protocol_fee.lower,
                    fee_growth
                );
            }
            if cross {
                let (mut current_liquidity, mut next_tick_to_cross) = tick_cross(
                    next_tick_to_cross,
                    storage.seconds_growth_global,
                    current_liquidity,
                    fee_growth_globalA,
                    fee_growth_globalB,
                    token_zero_to_one,
                    I24::from(storage.tick_spacing)
                );
                if current_liquidity == zero_u128 {
                    // find the next tick with liquidity
                    current_price = get_price_sqrt_at_tick(next_tick_to_cross);
                    let (current_liquidity, next_tick_to_cross) = tick_cross(
                        next_tick_to_cross,
                        storage.seconds_growth_global,
                        current_liquidity,
                        fee_growth_globalA,
                        fee_growth_globalB,
                        token_zero_to_one,
                        I24::from(storage.tick_spacing)
                    );
                }
            }
            else { break; }
        }

        storage.sqrt_price = current_price;

        let new_nearest_tick = if token_zero_to_one { next_tick_to_cross } else { storage.ticks.get(next_tick_to_cross).prev_tick };

        if storage.nearest_tick != new_nearest_tick {
            storage.nearest_tick = new_nearest_tick;
            storage.liquidity = current_liquidity;
        }
        // handle case where not all liquidity is used
        let amount_in_left = amount_in_left.lower;
        let amount_in = amount - amount_in_left;

        _swap_update_reserves(token_zero_to_one, amount_in, amount_out);
        _update_fees(token_zero_to_one, fee_growth_globalA, protocol_fee.lower);

        let mut token0_amount = 0;
        let mut token1_amount = 0;

        let sender: Identity= msg_sender().unwrap();

        if token_zero_to_one {
            if amount_in_left > 0 { transfer(amount_in_left, token0, recipient) }
            transfer(amount_out, token0, recipient);
            token0_amount = amount_in;
            token1_amount = amount_out;
        } else {
            if amount_in_left > 0 { transfer(amount_in_left, token1, recipient) }
            transfer(amount_out, token1, recipient);
            token1_amount = amount_in;
            token0_amount = amount_out;
        }

        log(SwapEvent {
            pool: contract_id(),
            token0_amount,
            token1_amount,
            liquidity: storage.liquidity,
            tick: storage.nearest_tick,
            sqrt_price: storage.sqrt_price,
            recipient,
            sender
        });

        amount_out
    }


    #[storage(read)]
    fn quote_amount_in(token_zero_to_one: bool, amount_out: u64) -> u64 {
        let zero_u128        = U128{upper: 0, lower: 0};
        let one_u128         = U128{upper: 0, lower: 1};
        let one_e_6_u128     = U128{upper: 0, lower: 1000000};
        let one_q128x128     = Q128x128::from_uint(1);
        let one_e_6_q128x128 = Q128x128::from_u128(one_e_6_u128);

        let swap_fee = U128{upper: 0, lower: storage.swap_fee};
        let mut amount_out_no_fee = ((U128{upper: 0, lower: amount_out}) * one_e_6_u128) / (one_e_6_u128 - swap_fee) + one_u128;
        let mut current_price = storage.sqrt_price;
        let mut current_liquidity = storage.liquidity;
        let mut next_tick_to_cross = if token_zero_to_one { storage.nearest_tick } else { storage.ticks.get(storage.nearest_tick).next_tick };
        let mut next_tick: I24 = I24::new();
        let tick_spacing = storage.tick_spacing;

        let mut final_amount_in: U128 = U128{upper: 0, lower: 0};
        let mut final_amount_out: U128 = U128{upper: 0, lower: amount_out};

        while amount_out_no_fee != zero_u128 {
            let mut next_tick_price = get_price_sqrt_at_tick(next_tick_to_cross);
            if token_zero_to_one {
                let mut max_dy = get_dy(current_liquidity, next_tick_price, current_price, false).u128();
                if amount_out_no_fee < max_dy || amount_out_no_fee == max_dy {
                    final_amount_out = (final_amount_out * one_e_6_u128) / (one_e_6_u128 - swap_fee) + one_u128;
                    let liquidity_padded  = Q128x128::from_u128(current_liquidity);
                    let price_padded      = Q128x128::from_q64x64(current_price.value);
                    let amount_out_padded = Q128x128::from_u128(final_amount_out);
                    let new_price = current_price - mul_div_rounding_up_q64x64(amount_out_padded, Q128x128::from_uint(u64::max()), liquidity_padded);
                    final_amount_in += get_dx(current_liquidity, new_price, current_price, false).u128() + one_u128;
                    break;
                } else {
                    if next_tick_to_cross / I24::from_uint(tick_spacing) % I24::from_uint(2) == I24::new(){
                        current_liquidity -= storage.ticks.get(next_tick_to_cross).liquidity;
                    } else {
                        current_liquidity += storage.ticks.get(next_tick_to_cross).liquidity;
                    }
                    amount_out_no_fee -= max_dy - one_u128; // handle rounding issues
                    let fee_amount = mul_div_rounding_up_u128(max_dy, swap_fee, one_e_6_u128);
                    if final_amount_out < (max_dy - swap_fee) || final_amount_out == (max_dy - swap_fee) {
                        break;
                    }
                    final_amount_out -= (max_dy - fee_amount);
                    next_tick = storage.ticks.get(next_tick_to_cross).prev_tick;
                }
                
            } else {
                let max_dx = get_dx(current_liquidity, current_price, next_tick_price, false).u128();
                if amount_out_no_fee < max_dx || amount_out_no_fee == max_dx {
                    final_amount_out = (final_amount_out * one_e_6_u128) / (one_e_6_u128 - swap_fee) + one_u128;

                    let liquidity_padded  = Q128x128::from_u128(current_liquidity);
                    let price_padded      = Q128x128::from_q64x64(current_price.value);
                    let amount_out_padded = Q128x128::from_u128(final_amount_out);
                    let mut new_price : Q64x64 = mul_div_rounding_up_q64x64(liquidity_padded, price_padded, liquidity_padded - price_padded * amount_out_padded);

                    if !(current_price < new_price && (new_price < next_tick_price || new_price == next_tick_price)) {
                        new_price = mul_div_rounding_up_q64x64(one_q128x128, liquidity_padded, liquidity_padded / price_padded - amount_out_padded);
                    }
                    final_amount_in += get_dy(current_liquidity, current_price, new_price, false).u128() + one_u128;
                    break;
                } else {
                    final_amount_in += get_dy(current_liquidity, current_price, next_tick_price, false).u128();
                    if next_tick_to_cross / I24::from_uint(tick_spacing) % I24::from_uint(2) == I24::new(){
                        current_liquidity += storage.ticks.get(next_tick_to_cross).liquidity;
                    } else {
                        current_liquidity -= storage.ticks.get(next_tick_to_cross).liquidity;
                    }
                    amount_out_no_fee -= max_dx + one_u128; // resolve rounding errors
                    let fee_amount = mul_div_rounding_up_u128(max_dx, swap_fee, one_e_6_u128);
                    if final_amount_out < (max_dx - fee_amount) || final_amount_out == (max_dx - fee_amount){
                        break;
                    }
                    final_amount_out -= (max_dx - fee_amount);
                    next_tick = storage.ticks.get(next_tick_to_cross).next_tick;
                }
            }
            current_price = next_tick_price;
            if(next_tick_to_cross != next_tick) {break};
            next_tick_to_cross = next_tick;
        }
         
        final_amount_in.lower
    }

    #[storage(read, write)]
    fn set_price(price : Q64x64) {
        check_sqrt_price_bounds(price);
        let zero_price = Q64x64{ value: U128{upper: 0, lower: 0} };
        if storage.sqrt_price == zero_price {
            storage.sqrt_price = price;
        }

        ()
    }

    #[storage(read, write)]
    fn mint(lower_old: I24, lower: I24, upper_old: I24, upper: I24, amount0_desired: u64, amount1_desired: u64, recipient: Identity) -> U128 {
        _ensure_tick_spacing(upper, lower).unwrap();

        let price_lower = get_price_sqrt_at_tick(lower);
        let price_upper = get_price_sqrt_at_tick(upper);
        let current_price = storage.sqrt_price;

        let liquidity_minted = get_liquidity_for_amounts(price_lower, price_upper, current_price, U128{upper: 0, lower: amount1_desired}, U128{upper: 0, lower: amount0_desired});

        // _updateSecondsPerLiquidity(uint256(liquidity));

        let (amount0_fees, amount1_fees) = _update_position(recipient, lower, upper, liquidity_minted, true);

        let sender: Identity= msg_sender().unwrap();

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

        storage.nearest_tick = tick_insert(
            liquidity_minted,
            upper, lower,
            upper_old, lower_old
        );

        let (amount0_actual, amount1_actual) = get_amounts_for_liquidity(price_upper, price_lower, current_price, liquidity_minted, true);

        //IPositionManager(msg.sender).mintCallback(token0, token1, amount0Actual, amount1Actual, mintParams.native);
        _position_update_reserves(true, amount0_actual, amount1_actual);

        let sender: Identity= msg_sender().unwrap();

        log(MintEvent {
            pool: contract_id(),
            sender,
            recipient,
            token0_amount: amount0_desired,
            token1_amount: amount1_desired,
            liquidity_minted,
            tick_lower:lower,
            tick_upper:upper,
        });

        liquidity_minted
    }

    #[storage(read, write)]
    fn burn(recipient: Identity, lower: I24, upper: I24, liquidity_amount: U128) -> (u64, u64, u64, u64) {

        // get prices
        let price_lower = get_price_sqrt_at_tick(lower);
        let price_upper = get_price_sqrt_at_tick(upper);
        let current_price = storage.sqrt_price;

        // _updateSecondsPerLiquidity(uint256(liquidity));

        // if the liquidity is in range subtract from current liquidity
        if ((current_price > price_lower) || (current_price == price_lower)) && current_price < price_upper {
            storage.liquidity -= liquidity_amount;
        }

        let sender: Identity= msg_sender().unwrap();

        let (amount0_fees, amount1_fees) = _update_position(sender, lower, upper, liquidity_amount, false);

        let (token0_amount, token1_amount) = get_amounts_for_liquidity(price_upper, price_lower, current_price, liquidity_amount, false);

        let amount0:u64 = token0_amount + amount0_fees;
        let amount1:u64 = token1_amount + amount1_fees;

        _position_update_reserves(false, amount0, amount1);

        transfer(amount0, storage.token0, sender);
        transfer(amount1, storage.token1, sender);

        log(BurnEvent {
            pool: contract_id(),
            sender,
            token0_amount,
            token1_amount,
            liquidity_burned: liquidity_amount,
            tick_lower:lower,
            tick_upper:upper,
        });

        let mut nearest_tick = storage.nearest_tick;
        storage.nearest_tick = tick_remove(lower, upper, liquidity_amount, nearest_tick);
        
        (token0_amount, token1_amount, amount0_fees, amount1_fees)
    }

    #[storage(read, write)]
    fn collect_protocol_fee() -> (u64, u64) {
        let mut amount0 = 0;
        let mut amount1 = 0;
        if storage.token0_protocol_fee > 1 {
            amount0 = storage.token0_protocol_fee;
            storage.token0_protocol_fee = 0;
            storage.reserve0 -= amount0;

        }
        if storage.token1_protocol_fee > 1 {
            amount1 = storage.token0_protocol_fee;
            storage.token1_protocol_fee = 0;
            storage.reserve1 -= amount1;
        }

        (amount0, amount1)
    }

    #[storage(read, write)]
    fn collect(tick_lower: I24, tick_upper: I24) -> (u64, u64) {
        let sender: Identity= msg_sender().unwrap();
        let (amount0_fees, amount1_fees) = _update_position(sender, tick_lower, tick_upper, (U128{upper: 0, lower:0}), false);

        storage.reserve0 -= amount0_fees;
        storage.reserve1 -= amount1_fees;

        transfer(amount0_fees, storage.token0, sender);
        transfer(amount1_fees, storage.token1, sender);

        (amount0_fees, amount1_fees)
    }

    #[storage(read)]
    fn get_price_and_nearest_tick() -> (Q64x64, I24){
        (storage.sqrt_price, storage.nearest_tick)
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
fn _ensure_tick_spacing(upper: I24, lower: I24) -> Result<(), ConcentratedLiquidityPoolErrors> {
    if lower % I24::from_uint(storage.tick_spacing) != I24::from_uint(0) {
        return Result::Err(ConcentratedLiquidityPoolErrors::InvalidTick);
    }
    if (lower / I24::from_uint(storage.tick_spacing)) % I24::from_uint(2) != I24::from_uint(0) {
        return Result::Err(ConcentratedLiquidityPoolErrors::LowerEven);
    }
    if upper % I24::from_uint(storage.tick_spacing) != I24::from_uint(0) {
        return Result::Err(ConcentratedLiquidityPoolErrors::InvalidTick);
    }
    if (upper / I24::from_uint(storage.tick_spacing)) % I24::from_uint(2) == I24::from_uint(0) {
        return Result::Err(ConcentratedLiquidityPoolErrors::UpperOdd);
    }

    Result::Ok(())
}

#[storage(read, write)]
fn _update_position(owner: Identity, lower: I24, upper: I24, amount: U128, add_liquidity: bool) -> (u64, u64) {
    let mut position = storage.positions.get((owner, lower, upper));
    require(add_liquidity || (amount < position.liquidity || amount == position.liquidity), FullMathError::Overflow);
    let (range_fee_growth0, range_fee_growth1) = range_fee_growth(lower, upper);
    
    let amount0_fees = 
        Q128x128::from_q64x64((range_fee_growth0 - position.fee_growth_inside0).value) * Q128x128::from_u128(position.liquidity);
    let amount0_fees = amount0_fees.value.b;

    let amount1_fees = 
        Q128x128::from_q64x64((range_fee_growth1 - position.fee_growth_inside1).value) * Q128x128::from_u128(position.liquidity);
    let amount1_fees = amount1_fees.value.b;

    if add_liquidity {
        position.liquidity += amount;
        //TODO: handle overflow
    } else {
        position.liquidity -= amount;
    }

    // checkpoint fee_growth_inside
    position.fee_growth_inside0 = range_fee_growth0;
    position.fee_growth_inside1 = range_fee_growth1;

    // update storage map
    storage.positions.insert((owner, lower, upper), position);
    
    (amount0_fees, amount1_fees)
}

 #[storage(read, write)]
fn _update_fees(token_zero_to_one: bool, fee_growth_global: Q64x64, protocol_fee: u64) {
     if token_zero_to_one {
         storage.fee_growth_global1 = fee_growth_global;
         storage.token1_protocol_fee += protocol_fee;
     } else {
         storage.fee_growth_global0 = fee_growth_global;
         storage.token0_protocol_fee += protocol_fee;
     }

    ()
}

#[storage(read, write)]
fn _swap_update_reserves(token_zero_to_one: bool, amount_in: u64, amount_out: u64) {

    if token_zero_to_one  {
        storage.reserve0 += amount_in;
        storage.reserve1 -= amount_out;
    } else {
        storage.reserve1 += amount_in;
        storage.reserve0 -= amount_out;
    }
}

#[storage(read, write)]
fn _position_update_reserves(add_liquidity: bool, token0_amount: u64, token1_amount: u64) {

    if add_liquidity {
        storage.reserve0 += token0_amount;
        storage.reserve1 += token1_amount;
    } else {
        storage.reserve0 -= token0_amount;
        storage.reserve1 -= token1_amount;
    }
}

#[storage(read)]
fn range_fee_growth(lower_tick : I24, upper_tick: I24) -> (Q64x64, Q64x64) {
    let current_tick = storage.nearest_tick;

    let lower: Tick = storage.ticks.get(lower_tick);
    let upper: Tick = storage.ticks.get(upper_tick);

    let _fee_growth_global0 = storage.fee_growth_global0;
    let _fee_growth_global1 = storage.fee_growth_global1;

    let mut fee_growth_below0:Q64x64 = Q64x64::from_uint(0);
    let mut fee_growth_below1:Q64x64 = Q64x64::from_uint(0);
    let mut fee_growth_above0:Q64x64 = Q64x64::from_uint(0);
    let mut fee_growth_above1:Q64x64 = Q64x64::from_uint(0);

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

fn empty_tick() -> Tick {
    Tick {
        prev_tick: I24::from_uint(0),
        next_tick: I24::from_uint(0),
        liquidity: U128{upper:0, lower:0},
        fee_growth_outside0: Q64x64::from_uint(0),
        fee_growth_outside1: Q64x64::from_uint(0),
        seconds_growth_outside: U128{upper:0, lower:0},
    }
}

// Downcast from u64 to u32, losing precision
fn u64_to_u32(a: u64) -> u32 {
    let result: u32 = a;
    result
}

//need to create U128 tick cast function in tick_math to clean up implementation
pub fn max_liquidity(tick_spacing: u32) -> U128 {
    //max U128 range
    let max_u128 = U128::max();

    //cast max_tick to U128
    let max_tick_i24 = I24::max();
    let max_tick_u32 = max_tick_i24.abs();
    let max_tick_u64: u64 = max_tick_u32;
    let max_tick_u128 = U128::from((0, max_tick_u64));

    //cast tick_spacing to U128
    let tick_spacing_u64: u64 = tick_spacing;
    let tick_spacing_u128 = U128::from((0, tick_spacing_u64));

    //liquidity math
    let double_tick_spacing = tick_spacing_u128 * (U128{upper: 0, lower: 2});
    let range_math = max_u128 / max_tick_u128;
    let liquidity_math = range_math / double_tick_spacing;

    liquidity_math
}
#[storage(read, write)]
pub fn tick_cross(
    ref mut next: I24, 
    seconds_growth_global: U256,
    ref mut liquidity: U128,
    fee_growth_globalA: Q64x64,
    fee_growth_globalB: Q64x64, 
    token_zero_to_one: bool,
    tick_spacing: I24
) -> (U128, I24) {
    //get seconds_growth from next in StorageMap
    let mut stored_tick = storage.ticks.get(next);
    let outside_growth = storage.ticks.get(next).seconds_growth_outside;

    //cast outside_growth into U256
    let seconds_growth_outside = U256{a:0,b:0,c:outside_growth.upper,d:outside_growth.lower};

    //do the math, downcast to U128, store in storage.ticks
    let outside_math: U256 = seconds_growth_global - seconds_growth_outside;
    let outside_downcast = U128{upper: outside_math.c, lower: outside_math.d};
    stored_tick.seconds_growth_outside = outside_downcast;
    storage.ticks.insert(next, stored_tick);

    let modulo_re_to24 = I24::from_uint(2);
    let i24_zero = I24::from_uint(0);

    if token_zero_to_one {
        if ((next / tick_spacing) % modulo_re_to24) == i24_zero {
            liquidity -= storage.ticks.get(next).liquidity;
        } else{
            liquidity += storage.ticks.get(next).liquidity;
        }
        //cast to Q64x64
        let mut new_stored_tick: Tick = storage.ticks.get(next);

        //do the math
        let fee_g_0 = fee_growth_globalB - new_stored_tick.fee_growth_outside0;
        let fee_g_1 = fee_growth_globalA - new_stored_tick.fee_growth_outside1;

        //push to new_stored_tick
        new_stored_tick.fee_growth_outside0 = fee_g_0;
        new_stored_tick.fee_growth_outside1 = fee_g_1;

        next = storage.ticks.get(next).prev_tick;    
    }
    
    else {
        if ((next / tick_spacing) % modulo_re_to24) == i24_zero {
            liquidity += storage.ticks.get(next).liquidity;
        } else{
            liquidity -= storage.ticks.get(next).liquidity;
        }

        let mut new_stored_tick: Tick = storage.ticks.get(next);

        //do the math
        let fee_g_0 = fee_growth_globalA - new_stored_tick.fee_growth_outside0;
        let fee_g_1 = fee_growth_globalB - new_stored_tick.fee_growth_outside1;

        //push to new_stored_tick
        new_stored_tick.fee_growth_outside0 = fee_g_0;
        new_stored_tick.fee_growth_outside1 = fee_g_1;

        //push onto storagemap
        storage.ticks.insert(next, new_stored_tick);

        //change input tick to previous tick
        next = storage.ticks.get(next).prev_tick;
    }
    (liquidity, next)
}

#[storage(read, write)]
fn tick_insert(
    amount: U128,
    above: I24, below: I24, 
    prev_above: I24, prev_below: I24
) -> I24 {
    // check inputs
    require(below < above, ConcentratedLiquidityPoolErrors::TickOrdering);
    require(below > MIN_TICK() || below == MIN_TICK(), ConcentratedLiquidityPoolErrors::TickSpacing);
    require(above < MAX_TICK() || above == MAX_TICK(), ConcentratedLiquidityPoolErrors::TickSpacing);
    
    let mut below_tick = storage.ticks.get(below);
    let mut nearest = storage.nearest_tick;

    if below_tick.liquidity != (U128{upper: 0, lower: 0}) || below == MIN_TICK() {
        // tick has already been initialized
        below_tick.liquidity += amount;
        storage.ticks.insert(below, below_tick);
    } else {
        // tick has not been initialized
        let mut prev_tick = storage.ticks.get(prev_below);
        let prev_next = prev_tick.next_tick;
        let below_next = if above < prev_tick.next_tick { above } else { prev_tick.next_tick };

        // check below ordering
        require(prev_tick.liquidity != (U128{upper: 0, lower: 0}) || prev_below == MIN_TICK(), ConcentratedLiquidityPoolErrors::TickOrdering);
        require(prev_below < below && below < prev_above, ConcentratedLiquidityPoolErrors::TickOrdering);
        
        if below < nearest || below == nearest {
            storage.ticks.insert(below, Tick {
                prev_tick: prev_below,
                next_tick: below_next,
                liquidity: amount,
                fee_growth_outside0: storage.fee_growth_global0,
                fee_growth_outside1: storage.fee_growth_global1,
                seconds_growth_outside: U128{upper:storage.seconds_growth_global.c, lower:storage.seconds_growth_global.d},
            });
        } else {
            storage.ticks.insert(below, Tick {
                prev_tick: prev_below,
                next_tick: prev_next,
                liquidity: amount,
                fee_growth_outside0: Q64x64::from_uint(0),
                fee_growth_outside1: Q64x64::from_uint(0),
                seconds_growth_outside: (U128{upper: 0, lower: 0})
            });
        }
        prev_tick.next_tick = below;
        storage.ticks.insert(prev_next, prev_tick);
    }

    let mut above_tick = storage.ticks.get(above);

    if above_tick.liquidity != (U128{upper: 0, lower: 0}) || above == MAX_TICK() {
        above_tick.liquidity += amount;
        storage.ticks.insert(above, above_tick);
    } else {
        let mut prev_tick = storage.ticks.get(prev_above);
        let mut prev_next = prev_tick.next_tick;

        // check above order
        require(prev_tick.liquidity != (U128{upper: 0, lower: 0}), ConcentratedLiquidityPoolErrors::TickOrdering);
        require(prev_next > above, ConcentratedLiquidityPoolErrors::TickOrdering);
        require(prev_above < above, ConcentratedLiquidityPoolErrors::TickOrdering);

        let above_prev = if prev_tick.prev_tick < below { below } else { prev_above };

        if above < nearest || above == nearest {
            storage.ticks.insert(above, Tick {
                prev_tick: above_prev,
                next_tick: prev_next,
                liquidity: amount,
                fee_growth_outside0: storage.fee_growth_global0,
                fee_growth_outside1: storage.fee_growth_global1,
                seconds_growth_outside: U128{upper:storage.seconds_growth_global.c, lower:storage.seconds_growth_global.d},
            });
        } else {
            storage.ticks.insert(above, Tick {
                prev_tick: prev_above,
                next_tick: prev_next,
                liquidity: amount,
                fee_growth_outside0: Q64x64::from_uint(0),
                fee_growth_outside1: Q64x64::from_uint(0),
                seconds_growth_outside: (U128{upper: 0, lower: 0})
            });
        }
        prev_tick.next_tick = above;
        storage.ticks.insert(prev_above, prev_tick);
        let mut prev_next_tick = storage.ticks.get(prev_next);
        prev_next_tick.prev_tick = above;
        storage.ticks.insert(prev_next, prev_next_tick);
    }

    let tick_at_price: I24 = get_tick_at_price(storage.sqrt_price);

    let above_is_between: bool = nearest < above && (above < tick_at_price || above == tick_at_price);
    let below_is_between: bool = nearest < below && (below < tick_at_price || below == tick_at_price);
    
    if above_is_between {
        nearest = above;
    } else if below_is_between {
        nearest = below;
    }
    
    nearest
}

#[storage(read, write)]
fn tick_remove(
    below: I24, above: I24,
    amount: U128,
    ref mut nearest: I24,
) -> I24 {
    let mut current_tick = storage.ticks.get(below);
    let mut prev = current_tick.prev_tick;
    let mut next = current_tick.next_tick;
    let mut prev_tick = storage.ticks.get(prev);
    let mut next_tick = storage.ticks.get(next);

    if below != MIN_TICK() && current_tick.liquidity == amount {
        // clear below tick from storage
        prev_tick.next_tick = current_tick.next_tick;
        next_tick.prev_tick = current_tick.prev_tick;

        if nearest == below {
            nearest = current_tick.prev_tick;
        }
        
        storage.ticks.insert(below, empty_tick());
        storage.ticks.insert(prev, prev_tick);
        storage.ticks.insert(next, next_tick);

    } else {
        current_tick.liquidity += amount;
        storage.ticks.insert(below, current_tick);
    }

    current_tick = storage.ticks.get(above);
    prev = current_tick.prev_tick;
    next = current_tick.next_tick;
    prev_tick = storage.ticks.get(prev);
    next_tick = storage.ticks.get(next);

    if above != MAX_TICK() && current_tick.liquidity == amount {
        // clear above tick from storage
        prev_tick.next_tick = next;
        next_tick.prev_tick = prev;

        if nearest == above {
            nearest = current_tick.prev_tick;
        }

        storage.ticks.insert(above, empty_tick());
        storage.ticks.insert(prev, prev_tick);
        storage.ticks.insert(next, next_tick);

    } else {
        current_tick.liquidity -= amount;
        storage.ticks.insert(above, current_tick);
    }

    nearest
}