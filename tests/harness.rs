use fuels::prelude::*;

abigen!(
    ConcentratedLiquidityAMM,
    "./amm/out/debug/amm-abi.json"
);

#[tokio::test]
async fn test_pool_initialization() {
    let asset_ids = [AssetId::default(), AssetId::from([5; 32])];
    let asset_configs = asset_ids
        .map(|id| AssetConfig {
            id,
            num_coins: 1,
            coin_amount: 100_000_000,
        })
        .into();

    let wallet_config = WalletsConfig::new_multiple_assets(2, asset_configs);
    let mut wallets = launch_custom_provider_and_get_wallets(wallet_config, None).await;
    let main_wallet = wallets.pop().unwrap();

    let id = Contract::deploy(
        "./amm/out/debug/amm.bin",
        &main_wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./amm/out/debug/amm-storage_slots.json"
                .to_string(),
        )),
    )
    .await
    .unwrap();

    for asset in asset_ids {
        main_wallet.force_transfer_to_contract(&id, 10_000_000, asset, TxParameters { gas_price: 0, gas_limit: 100, maturity: 0 }).await.unwrap();
    }

    let amm = ConcentratedLiquidityAMM::new(id.to_string(), main_wallet.clone());

    let _ = amm.methods().init(ContractId::from([5; 32]), ContractId::from([0; 32]), 500, Q64x64 { value: U128{upper: 0, lower: u64::MAX} }, 15).call().await.unwrap().value;

    let result = amm.methods().mint(I24 { underlying: 0 }, I24 { underlying: 16777185 }, I24 { underlying: 16777185 }, I24 { underlying: 16777320 }, 10_000_000, 10_000_000, Identity::Address(fuels::tx::Address::from([5; 32]))).call().await.unwrap().value;

    println!("{:?}", result);
}
