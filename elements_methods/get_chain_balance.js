const asyncAuto = require('async/auto');
const {returnResult} = require('asyncjs-util');

/** Get Elements wallet balance

  {
    elements: <Elements RPC Client Object>
    [asset]: <Asset ID String> // Default: bitcoin (L-BTC)
  }

  @returns via cbk or Promise
  {
    balance: <Balance in Asset Units Number>
    confirmed_balance: <Confirmed Balance Number>
    unconfirmed_balance: <Unconfirmed Balance Number>
    asset: <Asset ID String>
  }
*/
module.exports = ({elements, asset}, cbk) => {
  return new Promise((resolve, reject) => {
    return asyncAuto({
      // Check arguments
      validate: cbk => {
        if (!elements) {
          return cbk([400, 'ExpectedElementsRpcClient']);
        }

        return cbk();
      },

      // Get balance
      getBalance: ['validate', ({}, cbk) => {
        const assetId = asset || 'bitcoin'; // Default to L-BTC

        // Use the Elements RPC client's getBalance method
        return elements.getBalance()
          .then(result => {
            // result is an object with multiple asset balances
            // Ex: { "bitcoin": 0.002, "asset123...": 0.001 }
            if (typeof result === 'object' && result !== null) {
              const balance = result[assetId] || 0;
              return cbk(null, balance);
            } else {
              // Se for um número direto (caso de asset específico)
              return cbk(null, result || 0);
            }
          })
          .catch(err => cbk([503, 'FailedToGetElementsBalance', {err}]));
      }],

      // Get wallet info for additional details
      getWalletInfo: ['validate', ({}, cbk) => {
        return elements.getWalletInfo()
          .then(result => cbk(null, result))
          .catch(err => cbk([503, 'FailedToGetElementsWalletInfo', {err}]));
      }],

      // Format result
      format: ['getBalance', 'getWalletInfo', ({getBalance, getWalletInfo}, cbk) => {
        return cbk(null, {
          balance: getBalance,
          confirmed_balance: getBalance, // Elements doesn't separate by default
          unconfirmed_balance: 0, // Would need separate call for unconfirmed
          asset: asset || 'bitcoin'
        });
      }]
    },
    returnResult({reject, resolve, of: 'format'}, cbk));
  });
};
