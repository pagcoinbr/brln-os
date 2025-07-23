## Introduction to Liquid

## Exercise 1: Configuring and Running Liquid

1. Download and Install Elements, as appropriate for your Operating System https://github.com/ElementsProject/elements/releases/tag/elements-0.17.0

    - Linux: Download, Unzip the file contents, Copy the executables from the archive’s /bin/ directory into /usr/local/bin/
    - macOS: dmg installer will open a “Elements-Core” in your Finder sidebar. Drag “Elements Core” executable into Applications Folder. 
    - Windows: Installs to C:\Program Files\Bitcoin - Executables start with elements instead of liquid. 

1. Setup Liquid config file. Create liquid.conf (if not already present) in directory:
    - Linux: $HOME/.liquid/
    - macOS: $HOME/Library/Application Support/Liquid/
    - Windows: %APPDATA%\Liquid\

1. Add the following lines to liquid.conf:

    ```ini
    chain=elementsregtest
    
    validatepegin=0
    
    initialfreecoins=1000000000
    
    ```

1. Run the Liquid Node using the binaries installed above

    - Linux: `$ liquid-qt` from command line
    - macOS: Right click on “Elements Core” in Applications folder in finder and select Open. Then accept the “unidentified developer” warning.
    - Windows: Double click to run. When running executable, accept any prompts regarding networking access.

1. Within Elements Core window, navigate to the Help » Debug Window. Open the Console tab.

1. Get your balance:

    `$ getbalance`

    You should have 10 bitcoins because you used a configuration option of initialfreecoins=1000000000. If you changed this parameter you would get a different amount. These coins are available to spend without any signature.

1. Get current block height: 

    `$ getblockcount`

    This should be 0 the first time you run this test.

1. Generate a block: 

    `$ generate 1`

    Regtest will allow you to create blocks without making a signature.

1. See new block height:

    `$ getblockcount`

    You should see the height is now one more than before.

## Exercise 2: Using Liquid addresses

1. Generate a Liquid confidential address:

    `$ getnewaddress`

    You can see that it is confidential because it is much larger than a typical Bitcoin address. This is because it encodes a blinding key along with an non-confidential address.

1. Send to confidential address:

    `$ sendtoaddress <YOUR ADDRESS> 1`

    You will see a transaction id returned.

1. Transaction details (wallet perspective):

    `$ gettransaction <YOUR TXID>`

    Since this transaction is part of your wallet, you have more information than an outside observer would have.

1. Transaction details (public perspective): 

    `$ getrawtransaction <YOUR TXID> 1`

    You will see there are outputs here do not have a "value" field, like they would have in Bitcoin. Instead, they have a value-minimum, value-maximum, and valuecommitment fields. This shows you can hide the amount of the transaction, proving it is somewhere in this range, and the outputs add up to the inputs. Note that in Liquid, fees are explicitly set as outputs.

1. View “unconfidential” address field:

    `$ getaddressinfo <YOUR ADDRESS>`

    You can see the field "unconfidential_address" which reveals the address that is seen on the blockchain. This address will match the output's "scriptPubKey.addresses[0]" value.

1. Send coins to the non-confidential address:

    `$ sendtoaddress <YOUR UNCONFIDENTIAL ADDRESS> 2`

1. Transaction details (public perspective): 

    `$ getrawtransaction <YOUR TXID> 1`

    As you can see, the amount is now visible in the transaction because you did not blind the amounts.

## 3. Issued Assets

### Exercise 3a: Creating an Asset

1. Create 100 satoshis of new asset with 1 reissuance token: 

    `$ issueasset 0.00000100 0.00000001`

    The issueasset API and getbalance API display assets as divisible by 100 million, similar to Bitcoin. However, most assets will have a different default amount of decimals, depending on the use case. In this example, we assume that an asset is not divisible, so we issue at the "satoshi" level.

    You can see that an "asset" and a "token" hex id are created, which defines the asset.

1. See new issuance:

    `$ listissuances`

    This will list issuances that your wallet knows about.

1. See new assets and balances:

    `$ getbalance`

    You will notice you have a balance of both your asset that was issued as well as a reissuance token. Be sure to note the asset and token ids for the next steps.

1. Stop Elements Core by closing the Debug Window and then quitting the application.

1. Add the following lines to the liquid.conf file created previously:

    ```ini
    assetdir=<YOUR ASSET HEX>:demoasset
    
    assetdir=<YOUR TOKEN HEX>:demotoken
    ```

1. Start Elements Core, as applicable for your OS. Navigate to the Debug Window again.

1. See asset label applied:

    `$ dumpassetlabels`

    `$ getbalance`

### Exercise 3b: Reissuing an Asset

1. Reissue 99 satoshis of our asset:

    `$ reissueasset demoasset 0.00000099`

    We can reissue an asset using this API any time we have a reissuance token in our wallet for the asset. However, you could potentially send a reissuance token to a multi-signature wallet, and you could use the rawissueasset API to reissue an asset. 

1. View our reissuance:

    `$ listissuances`

1. View reissuance tx details (wallet perspective):

    `$ gettransaction <YOUR REISSUANCE TXID>`

1. Transaction details (public perspective):

    `$ getrawtransaction <YOUR REISSUANCE TXID> 1`

    Notice that the amount issued is not visible. Can you repeat this exercise to make the amount issued publicly known?

    Hint: issueasset and reissueasset have an extra parameter for making it confidential or not.

### Exercise 3c: Send an Asset

1. Send 3 of your asset:

    `$ sendtoaddress <YOUR ADDRESS> 0.00000003 "" "" false true 1 UNSET demoasset`

1. Transaction details (public perspective)

    `$ getrawtransaction <YOUR TXID> 1`

    Notice that the asset type is not known in this transaction. We can see two inputs (one is Bitcoin, one is the asset, and 3 outputs - Bitcoin change, the asset, and the transaction fee), and we don't know which is which).

### Exercise 4: Setup Chains

1. Create first address/key for block signing

    `$ getnewaddress`

    When signing blocks, we use an addresses pubkey/privkey.

1. Get address details and save the pubkey field

    `$ getaddressinfo <YOUR ADDRESS 1>`

    Save this address 1 pubkey for our block signing script.

1. Create second address/key for block signing

    `$ getnewaddress`

1. Get address details and save the pubkey field

    `$ getaddressinfo <YOUR ADDRESS 1>`

    Save this address 2 pubkey for our block signing script.

    Note that addresses can be in same wallet or different wallets. For this
    exercise, we are using block signing addresses from the same wallet.

1. Save your private keys

    `$ dumpprivkey <YOUR ADDRESS 1>`

    `$ dumpprivkey <YOUR ADDRESS 2>`

    We will re-import these addresses in our new, 2 of 2 signing chain's wallet.

1. Create a multisig address and save the redeemScript

    `$ createmultisig 2 "[\"<YOUR PUBKEY 1>\",\"<YOUR PUBKEY 2>\"]"`

    This multisig address is our 2 of 2 redeem script for signing blocks.

1. Add the following lines to the liquid.conf file created previously:

    ```ini
    signblockscript=<YOUR REDEEMSCRIPT>
    
    fedpegscript=<YOUR REDEEMSCRIPT>

    con_max_block_sig_size=150
    ```

    signblockscript is the redeemscript for signing blocks. New blocks must meet
    this redeemscipt challenge.

    fedpegscript is the script for the federated peg which handles peg in and
    peg outs.

    The con_max_block_sig_size represents the maximum allowed witness data for the signed block header.

1. Stop Elements Core by closing the Debug Window and then quitting the application.

1. Delete existing chain data, since we are starting a new 2 of 2 signing chain

    - Linux: $HOME/.liquid/elementsregtest
    - macOS: $HOME/Library/Application Support/Liquid/elementsregtest
    - Windows: %APPDATA%\Liquid\elementsregtest

1. Start Elements Core, as applicable for your OS. Navigate to the Debug Window again.

1. Attempt to generate a new block

    `$ generate 1`

    This will fail because we now requiring a 2 of 2 signature in order for
    valid blocks to be generated.

### Exercise 5: Sign a Block

1. Create a new proposed block

    `$ getnewblockhex`
    
    A hex-encoded serialized block ready to be signed and then added to the block chain. It will
    contain any transactions in your local node's mempool.

1. Try to submit the block
    
    `$ submitblock <YOUR BLOCK HEX>`

    Since we have not signed the block with our 2 addresses we cannot submit a
    block.
    
1. Import our multisig privkeys for block signing

    `$ importprivkey <YOUR PRIVKEY 1>`

    `$ importprivkey <YOUR PRIVKEY 2>`

1. Sign the block using both addresses
   
    `$ signblock <YOUR BLOCK HEX>`

    Note that both of our pubkeys are automatically used to sign the block.

1. Combine signatures and proposed block 

    `$ combineblocksigs <YOUR BLOCK HEX> '[{"pubkey":"<YOUR PUBKEY
    1>","sig":"<YOUR SIG 1>"},{"pubkey":"<YOUR PUBKEY 2>","sig":"<YOUR SIG
    2>"}]'`
    
1. "Broadcast" signed block

    `$ submitblock <YOUR SIGNED BLOCK HEX>`

    While we are the only node in our regtest network, submitting the block
    extends our chain with it.

1. See new block details

    `$ getblockcount`

    `$ getbestblockhash`

    `$ getblock <YOUR BLOCKHASH>`

    Note that the signblock_challenge matches our signblockscript redeemscript.

### Exercise 6: Peg-In and Claim

1. Stop Elements Core by closing the Debug Window and then quitting the application.

1. Install Bitcoin
	- Download the tar.gz file as appropriate for your setup https://bitcoin.org/en/download
	- Unzip the file contents 
	- Copy the executables from the archive’s /bin/ directory into 
		- Linux, macOS: /usr/local/bin/
		- Windows: ensure the binaries are executable and in the PATH

1. Setup Bitcoin config file. Create bitcoin.conf (if not already present) in directory:
    - Linux: $HOME/.bitcoin/
    - macOS: $HOME/Library/Application Support/Bitcoin/
    - Windows: %APPDATA%\Bitcoin\

1. Populate your bitcoin.conf file with:

    ```ini
    regtest=1
    daemon=1
    txindex=1

    regtest.rpcport=18888
    regtest.port=18889

    rpcuser=user3
    rpcpassword=password3
    ```

1. Start Bitcoin Core (bitcoin-qt), as applicable for your OS. Navigate to the Debug Window.

1. Add the following lines to the liquid.conf file created previously:

    ```ini
    mainchainrpcport=18888

    mainchainrpcuser=user3

    mainchainrpcpassword=password3
    ```

1. UPDATE the liquid.conf file to validate peg-ins:

    ```ini
    validatepegin=1
    ```

1. Start Elements Core, as applicable for your OS. Navigate to the Debug Window again.

1. Generate a peg-in address (Elements Core)

    `$ getpeginaddress`

    We now have an address we can send regtest bitcoin (RT-BTC) to which will be
    credited, by our 2 of 2 federation, on the sidechain as Liquid regtest
    bitcoin (LRT-BTC).

1. Get RT-BTC to peg-in (Bitcoin Core)

    `$ generate 101`

    Generate 101 Bitcoin regtest blocks. Since we are in regtest, we get the
    mining rewards for each block mined. Since mined blocks can only be spent
    after 100 blocks, we need to generate 101 in order to get 50 RT-BTC
    available in our wallet.

1. Verify we have 50 RT-BTC to spend (Bitcoin Core)

    `$ getbalance`

1. Send 1 RT-BTC to our peg-in address (Bitcoin Core)

    `$ sendtoaddress <YOUR PEG-IN ADDRESS> 1`

1. Give our peg-in transaction sufficient confirmations (Bitcoin Core)

    `$ generate 10`

    NOTE: The ‘peginconfirmationdepth’ parameter can be used to override the
    default confirmation depth, which is 10 blocks.
    
1. Prove our peg-in transaction was included in a block (Bitcoin Core)

    `$ gettxoutproof '["<YOUR PEG-IN TXID>"]'`

1. Get the peg-in's raw transaction hex (Bitcoin Core)

    `$ getrawtransaction <YOUR PEG-IN TXID>`

    The peg-in's raw transaction hex will be used when claiming our funds on the sidechain.

1. Claim peg-in funds on the sidechain (Elements Core)

    `$ claimpegin <YOUR RAW TX HEX> <YOUR TXOUT PROOF HEX>`

    claimpegin creates a transaction in the sidechain which makes the peg-in
    funds available on the sidechain.

1. View peg-in transaction details (Elements Core)

    `$ getrawtransaction <YOUR CLAIM TXID> 1`

    Note that is_pegin is set to true.

1. See peg-in transaction in the mempool (Elements Core)

    `$ getrawmempool`

1. Check your pre-peg-in LRT-BTC (Elements Core)

    `$ getbalance`

1. Generate a block including our peg-in transaction (Elements Core)

    `$ getnewblockhex`
    `$ signblock <YOUR BLOCK HEX>`
    `$ combineblocksigs <YOUR BLOCK HEX> '[{"pubkey":"<YOUR PUBKEY
    1>","sig":"<YOUR SIG 1>"},{"pubkey":"<YOUR PUBKEY 2>","sig":"<YOUR SIG
    2>"}]'`
    `$ submitblock <YOUR SIGNED BLOCK HEX>`

1. Check your post-peg-in LRT-BTC (Elements Core)

    `$ getbalance`

## Useful Links

- https://github.com/Blockstream/liquid
- https://elementsproject.org/elements-code-tutorial/overview
- https://github.com/ElementsProject/elementsbp-api-reference/blob/master/api.md