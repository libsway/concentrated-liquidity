use fuels::prelude::*;
use std::net::SocketAddr;
use std::net::IpAddr;
use std::net::Ipv4Addr;
use fuels::test_helpers::launch_custom_provider_and_get_wallets;
use fuel_chain_config::config::ChainConfig;
use fuels::fuel_node::Config;

abigen!(
    ExeguttorTests,
    "./amm_tests/out/debug/tests-abi.json"
);

#[tokio::test]
async fn sq63x64() {
    let socket = SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 4000);
    let wallet = launch_custom_provider_and_get_wallets(
        WalletsConfig::new(
            Some(1),             /* Single wallet */
            Some(1),             /* Single coin (UTXO) */
            Some(1_000_000_000), /* Amount per coin */
        ),
        Config::new(
            socket,
            false,
            false,
            false,
            false
        ),
        ChainConfig::new(
            "cl_libs_test",
            BlockProduction.ProofOfAuthority,
            0, // gas limit
            None,
            ConsensusParameters::DEFAULT.with_max_gas_per_tx(10000000000000).with_gas_per_byte(0),
        )
    ).await;

    let (contract_instance, _id) = get_test_contract_instance(wallet).await;

    let result = contract_instance.methods()
        .test_most_sig_bit_idx()
            .call()
            .await
            .unwrap()
            .value;

    println!("{}", result);

    let result = contract_instance.methods()
        .test_binary_log()
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

    let instance = ExeguttorTests::new(id.to_string(), wallet);

    (instance, id)
}
