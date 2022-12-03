use fuels::prelude::*;

abigen!(
    ExeguttorTests,
    "./amm_tests/out/debug/tests-abi.json"
);

#[tokio::test]
async fn sq63x64() {
    let wallet = launch_provider_and_get_wallet().await;

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
