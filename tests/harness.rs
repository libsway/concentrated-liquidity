use fuels::prelude::*;
use fuels::tx::ConsensusParameters;
use fuel_chain_config::ChainConfig;
use fuel_chain_config::CoinConfig;
use fuel_chain_config::StateConfig;

abigen!(
    ExeguttorTests,
    "./amm_tests/out/debug/tests-abi.json"
);

#[tokio::test]
async fn sq63x64() {
    let mut wallet = WalletUnlocked::new_random(None);
    let num_assets = 1;
    let coins_per_asset = 100;
    let amount_per_coin = 1_000_000_000;

    let (coins, _asset_ids) = setup_multiple_assets_coins(
        wallet.address(),
        num_assets,
        coins_per_asset,
        amount_per_coin,
    );

    let coin_configs = coins.clone()
        .into_iter()
        .map(|(utxo_id, coin)| CoinConfig { tx_id: Some(*utxo_id.tx_id()),
            output_index: Some(utxo_id.output_index() as u64),
            block_created: Some(coin.block_created),
            maturity: Some(coin.maturity),
            owner: coin.owner,
            amount: coin.amount,
            asset_id: coin.asset_id,
        })
        .collect::<Vec<_>>();

    // In order: gas_price, gas_limit, and maturity
    let my_tx_params = TxParameters::new(None, Some(10_000_000), None);

    let consensus_parameters_config =
        ConsensusParameters::DEFAULT
            .with_max_gas_per_tx(100_000_000_000)
            .with_gas_per_byte(0);

    let chain_config = ChainConfig {    
        initial_state: Some(StateConfig {
            coins: Some(coin_configs),
            contracts: None,
            messages: None,
            ..StateConfig::default()}),
            chain_name: "local".into(),
            block_gas_limit: 100_000_000_000,
            transaction_parameters: consensus_parameters_config,
            ..Default::default()
        };
    
    let (fuel_client, _socket_addr) = setup_test_client(coins,vec![],None,Some(chain_config),None).await;
    wallet.set_provider(Provider::new(fuel_client));
    let (contract_instance, _id) = get_test_contract_instance(wallet).await;

    let result = contract_instance.methods()
        .test_most_sig_bit_idx()
            .tx_params(my_tx_params)
            .call()
            .await
            .unwrap()
            .value;

    println!("{}", result);

    let result = contract_instance.methods()
        .test_binary_log()
            .tx_params(my_tx_params)
            .call()
            .await
            .unwrap()
            .value;

    println!("{}", result.value.upper);
    println!("{}", result.value.lower);
    let base: u128 = 2;
    println!("{}", base.pow(64));

    let result = contract_instance.methods()
        .test_abs_u128()
            .tx_params(my_tx_params)
            .call()
            .await
            .unwrap()
            .value;

    println!("{}", result.upper);

    assert!(result != result);
}

async fn get_test_contract_instance(
    wallet: WalletUnlocked,
) -> (ExeguttorTests, Bech32ContractId) {
    
    let id = Contract::deploy(
        "./amm_tests/out/debug/tests.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./amm_tests/out/debug/tests-storage_slots.json"
                .to_string(),
        )),
    )
    .await
    .unwrap();

    let instance = ExeguttorTests::new(id.clone(), wallet);

    (instance, id)
}
