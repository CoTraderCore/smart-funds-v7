import { BN, toWei } from 'web3-utils';

export default function ether (n) {
  return new BN(toWei(String(n), 'ether'));
}
