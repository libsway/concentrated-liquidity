use fuels::{prelude::*, tx::ContractId};

// Load abi from json
abigen!(PoolContract, "out/debug/amm-abi.json");

async fn get_contract_instance() -> (PoolContract, ContractId) {
    // Launch a local network and deploy the contract
    let mut wallets = launch_custom_provider_and_get_wallets(
        WalletsConfig::new(
            Some(1),             /* Single wallet */
            Some(1),             /* Single coin (UTXO) */
            Some(1_000_000_000), /* Amount per coin */
        ),
        None,
    )
    .await;
    let wallet = wallets.pop().unwrap();

    let id = Contract::deploy(
        "./out/debug/amm.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./out/debug/amm-storage_slots.json".to_string(),
        )),
    )
    .await
    .unwrap();

    let instance = PoolContractBuilder::new(id.to_string(), wallet).build();

    (instance, id.into())
}

#[tokio::test]
async fn can_get_contract_id() {
    let (contract_instance, _id) = get_contract_instance().await;
    // Now you have an instance of your contract you can use to test each function

    let result = contract_instance
        .initialize_storage(42)
        .call()
        .await
        .unwrap();

    assert_eq!(42, result.value);

    // Call `increment_counter()` method in our deployed contract.
    let result = contract_instance
        .set_price(10)
        .call()
        .await
        .unwrap();

    assert_eq!(10, result.value);
}