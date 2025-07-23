const asyncAuto = require('async/auto');
const {returnResult} = require('asyncjs-util');

/** Get Elements blockchain information

  {
    elements: <Elements RPC Client Object>
  }

  @returns via cbk or Promise
  {
    best_block_hash: <Best Block Hash Hex String>
    blocks: <Block Count Number>
    chain: <Chain Name String>
    difficulty: <Difficulty Number>
    headers: <Header Count Number>
    initial_block_download: <Is Initial Block Download Bool>
    median_time: <Median Time Number>
    progress: <Sync Progress Number>
    pruned: <Is Pruned Bool>
    size_on_disk: <Size on Disk Number>
    verification_progress: <Verification Progress Number>
    warnings: <Warnings String>
  }
*/
module.exports = ({elements}, cbk) => {
  return new Promise((resolve, reject) => {
    return asyncAuto({
      // Check arguments
      validate: cbk => {
        if (!elements) {
          return cbk([400, 'ExpectedElementsRpcClient']);
        }

        return cbk();
      },

      // Get blockchain info
      getInfo: ['validate', ({}, cbk) => {
        return elements.getBlockchainInfo()
          .then(result => cbk(null, result))
          .catch(err => cbk([503, 'FailedToGetElementsBlockchainInfo', {err}]));
      }],

      // Format result
      format: ['getInfo', ({getInfo}, cbk) => {
        return cbk(null, {
          best_block_hash: getInfo.bestblockhash,
          blocks: getInfo.blocks,
          chain: getInfo.chain,
          difficulty: getInfo.difficulty,
          headers: getInfo.headers,
          initial_block_download: getInfo.initialblockdownload,
          median_time: getInfo.mediantime,
          progress: getInfo.verificationprogress,
          pruned: getInfo.pruned,
          size_on_disk: getInfo.size_on_disk,
          verification_progress: getInfo.verificationprogress,
          warnings: getInfo.warnings || ''
        });
      }]
    },
    returnResult({reject, resolve, of: 'format'}, cbk));
  });
};
