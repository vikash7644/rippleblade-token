# Frontend for RIPPLEBLADE presale

This is a minimal React + Vite frontend to interact with the Presale contract.

Setup
1. cd frontend
2. npm install
3. Copy .env.example -> .env and fill VITE_PRESALE_ADDRESS and VITE_TOKEN_ADDRESS
4. npm run dev

Available actions:
- Connect wallet (MetaMask)
- Buy using USDT (approve -> buy)
- Claim purchased tokens after presale finalized
- Claim 10% bonus after LP is created and presale.setLPCreated() is called

Notes:
- This is a minimal starter. For production, add error handling, UX polish, and security checks.
