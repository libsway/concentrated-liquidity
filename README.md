# 🌴🔱 Exeggutor AMM 🌴🔱

The Exeggutor AMM is a reference implementation of the [Sushiswap Trident](https://github.com/sushiswap/trident) implementation of Concentrated Liquidity in Sway. To run on the FuelVM many modifications had to be made, specifically around the typing of many variables. The design expectation of this AMM is that tokens on the FuelVM would use 8 decimal precision, and store balances in a `u64`.

## Type Table

This Table keep tracks of which types which changed and why

| Orginal Variable |  Type  |  New Type  |  Reasoning |
| ---------------- | -------|------------|------------|
| Reserve{0,1}         | uint128 |  u64       | Max Integer Size to Store token balances, planned to support 8 decimal tokens which use u64 for token balances         |
| liquidity         | uint128 |  U128       | Since Liquidity = x * y, if both x and y are reserves, then if both are max u64, liquidity could be up to U128         |
| price         | uint160 |  Q64x64       | Since price is originally a Q64.96, it's scaled down to a Q64.64, represents sqrt of price, since Q64.64 has more the enough integer precision, makes it easier to scale back up, and decimal is still very very accurate on numbers where balances are represented as `u64`        |

## Library Reference

Exeggutor requires many new additions of libraries to be built, and so docs and descriptions of each of these libraries are included below.

### dydx_math

A library used to determine token amounts from a pure liquidity number (amount0 * amount1), and liquidity from amounts. Also for general change within a tick math.

### full_math

A library to compute multiplication/division with complete accuracy by upcasting to a higher precision before performing calculations.

### i24

Concentrated Liquidity requires an `i24` to represent ticks, because with every value in `i24` a tick can represnet a change in basis point.

### Q64x64

The Q64x64 library is a library for basic handling of Fixed-Point numbers, with 64 bits for the integer, and 64 bits for decimal. Used to store price and do other partial values.

### Q128x128

The Q128x128 library is a library for basic handling of Fixed-Point numbers, with 128 bits for the integer, and 128 bits for decimal. Mostly used for when math is needed with more precision than a Q64.64.

### swap_lib

A `swap_lib` to just perform fee calculations for concentrated liquidity, and take into account but protocol fees and liquidity provider fees.

### tick_math

Another math library to determine tick value from price, and price from tick.


