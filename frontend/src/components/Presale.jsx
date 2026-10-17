import React, { useEffect, useState } from 'react'
import { ethers } from 'ethers'

const PRESALE_ABI = [
  'function buy(uint256) external',
  'function claimPurchased() external',
  'function claimBonus() external',
  'function finalized() view returns (bool)',
  'function lpCreated() view returns (bool)',
  'function purchasedTokens(address) view returns (uint256)',
  'function tokensPerUSDT() view returns (uint256)'
]

const ERC20_ABI = [
  'function approve(address spender, uint256 amount) public returns (bool)',
  'function allowance(address owner, address spender) public view returns (uint256)',
  'function balanceOf(address) view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)'
]

// Environment variables (set these in .env or replace directly)
const PRESALE_ADDRESS = import.meta.env.VITE_PRESALE_ADDRESS || 'REPLACE_PRESALE_ADDRESS'
const TOKEN_ADDRESS = import.meta.env.VITE_TOKEN_ADDRESS || 'REPLACE_TOKEN_ADDRESS'
const USDT_ADDRESS = import.meta.env.VITE_USDT_ADDRESS || '0xc2132D05D31c914a87C6611C10748AEb04B58e8F'

export default function Presale(){
  const [provider, setProvider] = useState(null)
  const [signer, setSigner] = useState(null)
  const [account, setAccount] = useState(null)
  const [usdtBal, setUsdtBal] = useState('0')
  const [tokenBal, setTokenBal] = useState('0')
  const [buyAmount, setBuyAmount] = useState('10')
  const [status, setStatus] = useState({finalized:false, lpCreated:false})
  const [tokensPerUSDT, setTokensPerUSDT] = useState('0')

  useEffect(()=>{
    if(window.ethereum) initProvider()
  },[])

  async function initProvider(){
    const prov = new ethers.providers.Web3Provider(window.ethereum)
    setProvider(prov)
    const accounts = await prov.listAccounts().catch(()=>[])
    if(accounts.length) onConnect(prov)
  }

  async function onConnect(prov=null){
    const p = prov || new ethers.providers.Web3Provider(window.ethereum)
    await p.send('eth_requestAccounts', [])
    const s = p.getSigner()
    const addr = await s.getAddress()
    setProvider(p)
    setSigner(s)
    setAccount(addr)
    refreshBalances(p, addr)
    loadPresaleInfo(p)
  }

  async function refreshBalances(p, addr){
    try{
      const usdt = new ethers.Contract(USDT_ADDRESS, ERC20_ABI, p)
      const token = new ethers.Contract(TOKEN_ADDRESS, ERC20_ABI, p)
      const [uBal, tBal, uDec, tDec, tSym] = await Promise.all([
        usdt.balanceOf(addr),
        token.balanceOf(addr),
        usdt.decimals().catch(()=>6),
        token.decimals().catch(()=>18),
        token.symbol().catch(()=>'RBLD')
      ])
      setUsdtBal(ethers.utils.formatUnits(uBal, uDec))
      setTokenBal(ethers.utils.formatUnits(tBal, tDec))
    }catch(e){ console.error(e) }
  }

  async function loadPresaleInfo(p){
    try{
      const presale = new ethers.Contract(PRESALE_ADDRESS, PRESALE_ABI, p)
      const [fin, lp, tPer] = await Promise.all([
        presale.finalized(),
        presale.lpCreated(),
        presale.tokensPerUSDT()
      ])
      setStatus({finalized:fin, lpCreated:lp})
      setTokensPerUSDT(ethers.utils.formatUnits(tPer, 18))
    }catch(e){ console.error('loadPresaleInfo', e) }
  }

  async function buy(){
    if(!signer) return alert('Connect wallet')
    const usdt = new ethers.Contract(USDT_ADDRESS, ERC20_ABI, signer)
    const presale = new ethers.Contract(PRESALE_ADDRESS, PRESALE_ABI, signer)
    const amount = buyAmount
    if(!amount || Number(amount) <= 0) return alert('Invalid amount')
    // USDT has 6 decimals
    const usdtUnits = ethers.utils.parseUnits(amount, 6)

    // Check allowance
    const allowance = await usdt.allowance(account, PRESALE_ADDRESS)
    if(allowance.lt(usdtUnits)){
      const tx = await usdt.approve(PRESALE_ADDRESS, usdtUnits)
      await tx.wait()
    }

    const tx = await presale.buy(usdtUnits)
    await tx.wait()
    alert('Purchase successful')
    refreshBalances(provider, account)
  }

  async function claim(){
    if(!signer) return alert('Connect wallet')
    const presale = new ethers.Contract(PRESALE_ADDRESS, PRESALE_ABI, signer)
    const tx = await presale.claimPurchased()
    await tx.wait()
    alert('Purchased tokens claimed')
    refreshBalances(provider, account)
  }

  async function claimBonus(){
    if(!signer) return alert('Connect wallet')
    const presale = new ethers.Contract(PRESALE_ADDRESS, PRESALE_ABI, signer)
    const tx = await presale.claimBonus()
    await tx.wait()
    alert('Bonus claimed')
    refreshBalances(provider, account)
  }

  return (
    <div>
      <div className="card">
        <div className="row">
          {account ? (
            <div>
              <div className="small">Connected: {account}</div>
              <div className="small">USDT: {usdtBal} • RBLD: {tokenBal}</div>
            </div>
          ) : (
            <button className="button" onClick={() => onConnect()}>Connect Wallet</button>
          )}
        </div>
      </div>

      <div className="card">
        <h3>Presale</h3>
        <div className="small">Tokens per USDT: {tokensPerUSDT}</div>
        <div className="small">Finalized: {String(status.finalized)}</div>
        <div className="small">LP Created: {String(status.lpCreated)}</div>

        <div style={{marginTop:12}}>
          <input className="input" value={buyAmount} onChange={e=>setBuyAmount(e.target.value)} />
          <div style={{height:8}} />
          <button className="button" onClick={buy}>Buy with USDT</button>
        </div>

        <hr />
        <div className="row">
          <button className="button" onClick={claim}>Claim Purchased</button>
          <button className="button" onClick={claimBonus}>Claim Bonus (after LP)</button>
        </div>
      </div>

      <div className="card small">
        <p>Note: Make sure presale contract and token addresses are set in environment variables: VITE_PRESALE_ADDRESS and VITE_TOKEN_ADDRESS. USDT defaults to Polygon USDT.</p>
      </div>
    </div>
  )
}
