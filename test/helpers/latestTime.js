// this work good
export default async function latestTime () {
  const block = await web3.eth.getBlock('latest')
  return block.timestamp
}


// this NOT work good
// export default async function latestTime () {
//   return await web3.eth.getBlock('latest').timestamp
// }
