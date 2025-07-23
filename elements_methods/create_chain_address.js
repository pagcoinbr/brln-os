const asyncAuto = require('async/auto');
const {returnResult} = require('asyncjs-util');

/** Create a new Elements address

  {
    elements: <Elements RPC Client Object>
    [format]: <Address Format String> // bech32, legacy, p2sh-segwit
    [label]: <Address Label String>
  }

  @returns via cbk or Promise
  {
    address: <New Address String>
    format: <Address Format String>
  }
*/
module.exports = ({elements, format, label}, cbk) => {
  return new Promise((resolve, reject) => {
    return asyncAuto({
      // Check arguments
      validate: cbk => {
        if (!elements) {
          return cbk([400, 'ExpectedElementsRpcClient']);
        }

        return cbk();
      },

      // Create new address
      createAddress: ['validate', ({}, cbk) => {
        const addressLabel = label || '';
        const addressType = format || 'bech32';

        return elements.getNewAddress(addressLabel, addressType)
          .then(result => cbk(null, result))
          .catch(err => cbk([503, 'FailedToCreateElementsAddress', {err}]));
      }],

      // Format result
      format: ['createAddress', ({createAddress}, cbk) => {
        return cbk(null, {
          address: createAddress,
          format: format || 'bech32'
        });
      }]
    },
    returnResult({reject, resolve, of: 'format'}, cbk));
  });
};
