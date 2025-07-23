const axios = require('axios');

/** Create Elements Core RPC Connection

  {
    host: <Elements Core RPC Host String>
    port: <Elements Core RPC Port Number>
    user: <Elements Core RPC Username String>
    password: <Elements Core RPC Password String>
    [timeout]: <Request Timeout in Milliseconds Number>
  }

  @throws
  <Error>

  @returns
  {
    elements: <Elements Core RPC Client Object>
  }
*/
module.exports = ({host, port, user, password, timeout}) => {
  if (!host) {
    throw new Error('ExpectedElementsRpcHost');
  }

  if (!port) {
    throw new Error('ExpectedElementsRpcPort');
  }

  if (!user) {
    throw new Error('ExpectedElementsRpcUser');
  }

  if (!password) {
    throw new Error('ExpectedElementsRpcPassword');
  }

  const baseURL = `http://${user}:${password}@${host}:${port}`;
  const requestTimeout = timeout || 30000;

  const client = axios.create({
    baseURL,
    timeout: requestTimeout,
    headers: {
      'Content-Type': 'application/json'
    }
  });

  // Method to make RPC calls
  const rpcCall = async (method, params = []) => {
    try {
      const response = await client.post('/', {
        jsonrpc: '2.0',
        method,
        params,
        id: Date.now()
      });

      if (response.data.error) {
        throw new Error(`Elements RPC Error: ${response.data.error.message}`);
      }

      return response.data.result;
    } catch (error) {
      if (error.response) {
        throw new Error(`Elements RPC HTTP Error: ${error.response.status} - ${error.response.statusText}`);
      }
      throw error;
    }
  };

  return {
    elements: {
      rpcCall,
      
      // Basic blockchain info
      getBlockchainInfo: () => rpcCall('getblockchaininfo'),
      getNetworkInfo: () => rpcCall('getnetworkinfo'),
      getWalletInfo: () => rpcCall('getwalletinfo'),
      
      // Block and transaction operations
      getBlock: (hash, verbosity = 1) => rpcCall('getblock', [hash, verbosity]),
      getBlockHash: (height) => rpcCall('getblockhash', [height]),
      getTransaction: (txid, includeWatchonly = false) => rpcCall('gettransaction', [txid, includeWatchonly]),
      getRawTransaction: (txid, verbose = false) => rpcCall('getrawtransaction', [txid, verbose]),
      
      // Wallet operations
      getBalance: (asset = 'bitcoin') => rpcCall('getbalance', ['*', 0, true]),
      getNewAddress: (label = '', addressType = 'bech32') => rpcCall('getnewaddress', [label, addressType]),
      listUnspent: (minconf = 1, maxconf = 9999999, addresses = []) => rpcCall('listunspent', [minconf, maxconf, addresses]),
      
      // Asset operations (Liquid specific)
      listAssets: () => rpcCall('listassets'),
      getAssetInfo: (asset) => rpcCall('getassetinfo', [asset]),
      issueAsset: (assetAmount, tokenAmount, blind = true) => rpcCall('issueasset', [assetAmount, tokenAmount, blind]),
      reissueAsset: (asset, assetAmount) => rpcCall('reissueasset', [asset, assetAmount]),
      
      // Confidential transactions (Liquid specific)
      blindRawTransaction: (rawTx, inputAmountBlinders = [], inputAssets = [], inputAssetBlinders = []) => 
        rpcCall('blindrawtransaction', [rawTx, inputAmountBlinders, inputAssets, inputAssetBlinders]),
      unblindRawTransaction: (rawTx) => rpcCall('unblindrawtransaction', [rawTx]),
      
      // Peg operations (Liquid specific)
      createRawPegin: (bitcoinTx, txoutProof, claimScript) => rpcCall('createrawpegin', [bitcoinTx, txoutProof, claimScript]),
      createRawPegout: (addr, amount, asset = 'bitcoin') => rpcCall('createrawpegout', [addr, amount, asset]),
      
      // Send operations
      sendToAddress: (address, amount, comment = '', commentTo = '', subtractFeeFromAmount = false, replaceable = false, confTarget = 6, estimateMode = 'CONSERVATIVE', asset = 'bitcoin') =>
        rpcCall('sendtoaddress', [address, amount, comment, commentTo, subtractFeeFromAmount, replaceable, confTarget, estimateMode, asset]),
      
      sendMany: (amounts, minconf = 1, comment = '', subtractFee = [], replaceable = false, confTarget = 6, estimateMode = 'CONSERVATIVE') =>
        rpcCall('sendmany', ['', amounts, minconf, comment, subtractFee, replaceable, confTarget, estimateMode]),
      
      // Fee estimation
      estimateSmartFee: (confTarget, estimateMode = 'CONSERVATIVE') => rpcCall('estimatesmartfee', [confTarget, estimateMode]),
      
      // Mempool operations  
      getMempoolInfo: () => rpcCall('getmempoolinfo'),
      getRawMempool: (verbose = false) => rpcCall('getrawmempool', [verbose]),
      
      // Network operations
      getPeerInfo: () => rpcCall('getpeerinfo'),
      getConnectionCount: () => rpcCall('getconnectioncount'),
      addNode: (node, command = 'add') => rpcCall('addnode', [node, command]),
      
      // Utility methods
      validateAddress: (address) => rpcCall('validateaddress', [address]),
      signRawTransactionWithWallet: (rawTx) => rpcCall('signrawtransactionwithwallet', [rawTx]),
      sendRawTransaction: (rawTx) => rpcCall('sendrawtransaction', [rawTx]),
      
      // Mining (for testing)
      generateToAddress: (nblocks, address) => rpcCall('generatetoaddress', [nblocks, address]),
      
      // Custom RPC call method for any unlisted commands
      customCall: (method, params = []) => rpcCall(method, params)
    }
  };
};
