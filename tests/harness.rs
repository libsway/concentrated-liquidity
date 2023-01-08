use fuels::prelude::*;
use fuels::tx::ConsensusParameters;
use fuel_chain_config::ChainConfig;
use fuel_chain_config::CoinConfig;
use fuel_chain_config::StateConfig;
use exeguttor_mod::Q64x64;

abigen!(
    Exeguttor,
    "./amm/out/debug/amm-abi.json"
);


#[tokio::test]
async fn test_initialize_pool() {
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
    let my_tx_params = TxParameters::new(None, Some(1_000_000_000), None);

    let consensus_parameters_config =
        ConsensusParameters::DEFAULT
            .with_max_gas_per_tx(1_000_000_000_000)
            .with_gas_per_byte(0);

    let chain_config = ChainConfig {    
        initial_state: Some(StateConfig {
            coins: Some(coin_configs),
            contracts: None,
            messages: None,
            ..StateConfig::default()}),
        chain_name: "local".into(),
        block_gas_limit: 1_000_000_000_000,
        transaction_parameters: consensus_parameters_config,
        ..Default::default()
        };

    let node_config = Config::local_node();
    let (fuel_client, _socket_addr) = setup_test_client(
                                        coins,
                                        vec![],
                                        Some(node_config),
                                        Some(chain_config),
                                        None
                                      ).await;
    wallet.set_provider(Provider::new(fuel_client));

    let (contract_instance, _id) = get_test_contract_instance(wallet).await;

    // Price assumes an implicit reserve of 100,000,000 A tokens and 10,000,000 B tokens
    // According the formula sqrt(reserve0 * reserve1) * 2**64
    let price = Q64x64{value : U128{upper : 31622776, lower : 0}};

    contract_instance.methods()
        .init(ContractId::from([0; 32]), ContractId::from([1; 32]), 500, price, 10).call().await.unwrap().value;

    // Call will fail on previous unwrap if instatiation doesn't work
}

async fn get_test_contract_instance(
    wallet: WalletUnlocked,
) -> (Exeguttor, Bech32ContractId) {
    
    let id = Contract::deploy(
        "./amm/out/debug/amm.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./amm/out/debug/amm-storage_slots.json"
                .to_string(),
        )),
    )
    .await
    .unwrap();

    let instance = Exeguttor::new(id.clone(), wallet);

    (instance, id)
}
