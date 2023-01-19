contract;

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
    auth::*,
    logging::log,
    call_frames::{contract_id ,msg_asset_id},
    context::msg_amount,
};

use cl_libs::I24::*;
use cl_libs::Q64x64::*;
use cl_libs::tick_math::*;

//TODO: implement these in pool.sw
pub enum ConcentratedLiquidityPoolErrors {
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

struct InitEvent {
    pool_id: ContractId,
    token0: ContractId,
    token1: ContractId,
    swap_fee: u64,
    tick_spacing: u32,
    init_price_upper: u64,
    init_price_lower: u64,
    init_tick: u32
}

struct SwapEvent {
    pool: ContractId,
    sender: Identity,
    recipient: Identity,
    token0_amount: u64,
    token1_amount: u64,
    liquidity: U128,
    tick: I24,
    sqrt_price: Q64x64
}

struct MintEvent {
    pool: ContractId,
    sender: Identity,
    recipient: Identity,
    token0_amount: u64,
    token1_amount: u64,
    liquidity_minted: U128,
    tick_lower: I24,
    tick_upper: I24
}

struct BurnEvent {
    pool: ContractId,
    sender: Identity,
    token0_amount: u64,
    token1_amount: u64,
    liquidity_burned: U128,
    tick_lower: I24,
    tick_upper: I24
}

struct FlashEvent {
    fee_growth_global0: Q64x64,
    fee_growth_global1: Q64x64
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
        require(storage.sqrt_price == Q64x64{value: U128{upper:0,lower:0}});
        require(swap_fee <= storage.max_fee);
        require(first_token != second_token);
        storage.token0 = if first_token < second_token { first_token }  else { second_token };
        storage.token1 = if first_token < second_token { second_token } else { first_token };
        storage.nearest_tick = get_tick_at_price(sqrt_price);
        storage.sqrt_price = sqrt_price;
        storage.swap_fee = swap_fee;
        storage.tick_spacing = tick_spacing;
        storage.unlocked = true;

        // log(InitEvent {
        //     pool_id: contract_id(),
        //     token0: storage.token0,
        //     token1: storage.token1,
        //     swap_fee,
        //     tick_spacing: tick_spacing,
        //     init_price_upper: sqrt_price.value.upper,
        //     init_price_lower: sqrt_price.value.lower,
        //     init_tick: storage.nearest_tick.underlying
        // });
    }
    #[storage(read, write)]
    fn swap(sqrt_price_limit: Q64x64, recipient: Identity) -> u64 {

        // sanity checks
        require(msg_amount() > 0);
        let token0 = storage.token0;
        let token1 = storage.token1;
        require(msg_asset_id() == token0 || msg_asset_id() == token1);
        let amount = msg_amount();
        let token_zero_to_one = if msg_asset_id() == token0 { true } else { false };

        if token_zero_to_one {
            transfer(msg_amount(), token0, recipient);
        } else {
            transfer(msg_amount(), token1, recipient);
        }

        let sender = msg_sender().unwrap();

        // log(SwapEvent {
        //     pool: contract_id(),
        //     token0_amount: msg_amount(),
        //     token1_amount: msg_amount(),
        //     liquidity: storage.liquidity,
        //     tick: storage.nearest_tick,
        //     sqrt_price: storage.sqrt_price,
        //     recipient,
        //     sender
        // });

        msg_amount()
    }


    #[storage(read)]
    fn quote_amount_in(token_zero_to_one: bool, amount_out: u64) -> u64 {
        amount_out
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
        let liquidity_minted = (amount0_desired + amount1_desired).u128();

        let sender: Identity= msg_sender().unwrap();

        // log(MintEvent {
        //     pool: contract_id(),
        //     sender,
        //     recipient,
        //     token0_amount: amount0_desired,
        //     token1_amount: amount1_desired,
        //     liquidity_minted,
        //     tick_lower:lower,
        //     tick_upper:upper,
        // });

        liquidity_minted
    }

    #[storage(read, write)]
    fn burn(recipient: Identity, lower: I24, upper: I24, liquidity_amount: U128) -> (u64, u64, u64, u64) {
        let amount = (liquidity_amount / U128::from((0,2))).lower;
        let sender = msg_sender().unwrap();
        transfer(amount, storage.token0, sender);
        transfer(amount, storage.token1, sender);
        
        (amount, amount, 0, 0)
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

        transfer(0, storage.token0, sender);
        transfer(0, storage.token1, sender);

        (0, 0)
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