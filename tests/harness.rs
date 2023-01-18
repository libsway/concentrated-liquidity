use fuels::prelude::*;
use fuels::signers::fuel_crypto::SecretKey;
use exeguttor_mod::Q64x64;
use std::str::FromStr;
use fuels::tx::ConsensusParameters;
use fuel_chain_config::ChainConfig;
use fuel_chain_config::CoinConfig;
use fuel_chain_config::StateConfig;


abigen!(
    Exeguttor,
    "./amm/out/debug/amm-abi.json"
);

abigen!(
    ExeguttorTests,
    "./amm_tests/out/debug/tests-abi.json"
);

// abigen!(
//     TestToken,
//     "./token/out/debug/token-abi.json"
// );

// #[tokio::test]
// async fn test_initialize_pool() {
//     let provider = Provider::connect("127.0.0.1:4000").await.unwrap();

//     let secret =
//         SecretKey::from_str("7f8a325504e7315eda997db7861c9447f5c3eff26333b20180475d94443a10c6")
//             .unwrap();

//     // Create the wallet
//     let wallet = WalletUnlocked::new_from_private_key(secret, Some(provider));
//     let test_wallet_address = wallet.address().clone().into();

//     let (contract_instance, _id) = get_contract_instance(wallet.clone()).await;

//     // Price assumes an implicit reserve of 100,000,000 A tokens and 10,000,000 B tokens
//     // According the formula sqrt(reserve0 * reserve1) * 2**64
//     let price = Q64x64{value : U128{upper : 3, lower : 0}};

//     let (token_a, token_a_id) = get_test_token_instance(wallet.clone()).await;
//     let (token_b, token_b_id) = get_test_token_instance(wallet).await;

//     token_a.methods().mint_and_send_to_address(1, test_wallet_address).append_variable_outputs(1).call().await.unwrap();

//     token_b.methods().mint_and_send_to_address(10_000_000, test_wallet_address).append_variable_outputs(1).call().await.unwrap();

//     let result = contract_instance.methods()
//         .init(token_a_id.into(), token_b_id.into(), 500, price, 10).call().await.unwrap();

//     // Call will fail on previous unwrap if instatiation doesn't work
// }

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
    let tx_params = TxParameters::new(None, Some(1_000_000_000), None);

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

    let (test_contract_instance, _id) = get_test_contract_instance(wallet).await;

    let result = test_contract_instance.methods()
        .test_get_tick_at_price()
            .tx_params(tx_params)
            .call()
            .await
            .unwrap()
            .value;

    println!("tick index for price of 3.00:");                     
    println!("{}", result.underlying);
    
    // let result = contract_instance.methods()
    //     .test_most_sig_bit_idx()
    //         .tx_params(tx_params)
    //         .call()
    //         .await
    //         .unwrap()
    //         .value;

    
    // println!("{}", result);

    // let result = contract_instance.methods()
    //     .test_binary_log()
    //         .tx_params(tx_params)
    //         .call()
    //         .await
    //         .unwrap()
    //         .value;

    // println!("{}", result.value.upper);
    // println!("{}", result.value.lower);
    // let base: u128 = 2;
    // println!("{}", base.pow(64));

    // let result = contract_instance.methods()
    //     .test_abs_u128()
    //         .tx_params(tx_params)
    //         .call()
    //         .await
    //         .unwrap()
    //         .value;

    // println!("{}", result.upper);

    // let result = contract_instance.methods()
    // .test_get_tick_at_price()
    //     .tx_params(tx_params)
    //     .call()
    //     .await
    //     .unwrap()
    //     .value;
    // println!("log base 1.0001 of 9:");
    // println!("{}", result.underlying);

    assert!(result != result);
}

// async fn get_test_token_instance(
//     wallet: WalletUnlocked,
// ) -> (TestToken, Bech32ContractId) {
    
//     let id = Contract::deploy(
//         "./token/out/debug/token.bin",
//         &wallet,
//         TxParameters::default(),
//         StorageConfiguration::with_storage_path(Some(
//             "./token/out/debug/token-storage_slots.json"
//                 .to_string(),
//         )),
//     )
//     .await
//     .unwrap();

//     // let instance = TestToken::new(id.clone(), wallet);

//     (instance, id)
// }

async fn get_contract_instance(
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
