const asyncAuto = require('async/auto');
const {returnResult} = require('asyncjs-util');

/** List Elements assets

  {
    elements: <Elements RPC Client Object>
  }

  @returns via cbk or Promise
  {
    assets: [
      {
        asset_id: <Asset ID String>
        name: <Asset Name String>
        ticker: <Asset Ticker String>
        precision: <Asset Precision Number>
        entity: <Issuing Entity String>
        is_reissuable: <Is Reissuable Bool>
      }
    ]
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

      // Get assets list using dumpassetlabels (listassets doesn't exist in Elements)
      getAssets: ['validate', ({}, cbk) => {
        return elements.customCall('dumpassetlabels', [])
          .then(result => cbk(null, result))
          .catch(err => cbk([503, 'FailedToGetElementsAssets', {err}]));
      }],

      // Format result
      format: ['getAssets', ({getAssets}, cbk) => {
        // dumpassetlabels returns { "asset_name": "asset_id" }
        const assets = Object.keys(getAssets).map(assetName => {
          const assetId = getAssets[assetName];
          
          return {
            asset_id: assetId,
            name: assetName,
            ticker: assetName.toUpperCase(),
            precision: 8, // Default precision for Elements assets
            entity: '',
            is_reissuable: assetName !== 'bitcoin' // L-BTC is not reissuable
          };
        });

        return cbk(null, {assets});
      }]
    },
    returnResult({reject, resolve, of: 'format'}, cbk));
  });
};
