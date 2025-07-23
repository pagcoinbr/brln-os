const asyncAuto = require('async/auto');
const {returnResult} = require('asyncjs-util');

/** Send Elements transaction

  {
    elements: <Elements RPC Client Object>
    address: <Destination Address String>
    tokens: <Amount in Satoshis Number>
    [asset]: <Asset ID String> // Default: bitcoin (L-BTC)
    [fee_tokens_per_vbyte]: <Fee Rate Number>
    [description]: <Transaction Description String>
  }

  @returns via cbk or Promise
  {
    confirmation_height: <Confirmation Height Number>
    id: <Transaction ID String>
    is_confirmed: <Is Confirmed Bool>
    is_outgoing: <Is Outgoing Transaction Bool>
    tokens: <Total Tokens Number>
  }
*/
module.exports = ({elements, address, tokens, asset, fee_tokens_per_vbyte, description}, cbk) => {
  return new Promise((resolve, reject) => {
    return asyncAuto({
      // Check arguments
      validate: cbk => {
        if (!elements) {
          return cbk([400, 'ExpectedElementsRpcClient']);
        }

        if (!address) {
          return cbk([400, 'ExpectedDestinationAddress']);
        }

        if (!tokens) {
          return cbk([400, 'ExpectedTokensToSend']);
        }

        return cbk();
      },

      // Send transaction
      sendTransaction: ['validate', ({}, cbk) => {
        const assetId = asset || 'bitcoin';
        const amount = tokens / 100000000; // Convert satoshis to BTC units
        const comment = description || '';
        
        return elements.sendToAddress(address, amount, comment, '', false, false, 6, 'CONSERVATIVE', assetId)
          .then(result => cbk(null, result))
          .catch(err => cbk([503, 'FailedToSendElementsTransaction', {err}]));
      }],

      // Get transaction details
      getTransaction: ['sendTransaction', ({sendTransaction}, cbk) => {
        return elements.getTransaction(sendTransaction)
          .then(result => cbk(null, result))
          .catch(err => cbk([503, 'FailedToGetElementsTransaction', {err}]));
      }],

      // Format result
      format: ['getTransaction', ({sendTransaction, getTransaction}, cbk) => {
        return cbk(null, {
          confirmation_height: getTransaction.blockheight || null,
          id: sendTransaction,
          is_confirmed: getTransaction.confirmations > 0,
          is_outgoing: true,
          tokens: Math.abs(getTransaction.amount * 100000000) // Convert back to satoshis
        });
      }]
    },
    returnResult({reject, resolve, of: 'format'}, cbk));
  });
};
