# 🌴🔱 Exeggutor AMM 🌴🔱

The Exeggutor AMM is a reference implementation of the [Sushiswap Trident](https://github.com/sushiswap/trident) implementation of Concentrated Liquidity in Sway. To run on the FuelVM many modifications had to be made, specifically around the typing of many variables. The design expectation of this AMM is that tokens on the FuelVM would use 8 decimal precision, and store balances in a `u64`.

## Type Table

This Table keep tracks of which types which changed and why

| Orginal Variable |  Type  |  New Type  |  Reasoning |
| ---------------- | -------|------------|------------|
| Content Cell     | Co     | Co         | Co         |
s


## Library Reference

Exeggutor requires many new additions of libraries to be built, and so docs and descriptions of each of these libraries are included below.

### dydx_math

A library used to determine token amounts from a pure liquidity number (amount0 * amount1), and liquidity from amounts. Also for general change within a tick math.

### full_math

A library to compute multiplication/division with complete accuracy by upcasting to a higher precision before performing calculations.

### i24

### Q64x64

### Q128x128

### swap_lib

### tick_delta_math

### tick_math





