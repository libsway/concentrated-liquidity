use fuels::prelude::*;
use fuels::signers::fuel_crypto::SecretKey;
use exeguttor_mod::Q64x64;
use std::str::FromStr;

abigen!(
    Exeguttor,
    "./amm/out/debug/amm-abi.json"
);

abigen!(
    TestToken,
    "./token/out/debug/token-abi.json"
);

#[tokio::test]
async fn test_initialize_pool() {
    let provider = Provider::connect("127.0.0.1:4000").await.unwrap();

    let secret =
        SecretKey::from_str("7f8a325504e7315eda997db7861c9447f5c3eff26333b20180475d94443a10c6")
            .unwrap();

    // Create the wallet
    let wallet = WalletUnlocked::new_from_private_key(secret, Some(provider));
    let test_wallet_address = wallet.address().clone().into();

    let (contract_instance, _id) = get_test_contract_instance(wallet.clone()).await;

    // Price assumes an implicit reserve of 100,000,000 A tokens and 10,000,000 B tokens
    // According the formula sqrt(reserve0 * reserve1) * 2**64
    let price = Q64x64{value : U128{upper : 3, lower : 0}};

    let (token_a, token_a_id) = get_test_token_instance(wallet.clone()).await;
    let (token_b, token_b_id) = get_test_token_instance(wallet).await;

    token_a.methods().mint_and_send_to_address(1, test_wallet_address).append_variable_outputs(1).call().await.unwrap();

    token_b.methods().mint_and_send_to_address(10_000_000, test_wallet_address).append_variable_outputs(1).call().await.unwrap();

    let result = contract_instance.methods()
        .init(token_a_id.into(), token_b_id.into(), 500, price, 10).call().await.unwrap();

    // Call will fail on previous unwrap if instatiation doesn't work
}

async fn get_test_token_instance(
    wallet: WalletUnlocked,
) -> (TestToken, Bech32ContractId) {
    
    let id = Contract::deploy(
        "./token/out/debug/token.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./token/out/debug/token-storage_slots.json"
                .to_string(),
        )),
    )
    .await
    .unwrap();

    let instance = TestToken::new(id.clone(), wallet);

    (instance, id)
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
