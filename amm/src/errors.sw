library errors;

pub enum ConcentratedLiquidityPoolErrors {
    Locked: (),
    ZeroAddress: (),
    ZeroAmount: (),
    InvalidToken: (),
    InvalidSwapFee: (),
    PriceLimitExceeded: (),
    LiquidityOverflow: (),
    Token0Missing: (),
    Token1Missing: (),
    InvalidTick: (),
    LowerEven: (),
    UpperOdd: (),
    MaxTickLiquidity: (),
    Overflow: (),
    AlreadyInitialized: (),
    TickOrdering: (),
    TickSpacing: (),
}