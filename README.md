# Constant-proportion rebalanced portfolio bot

For trading in Bitfinex, BTC/USD, using 50-50% usd/btc balance (as suggested by Shannon).
Rebalancing is done on every run, so schedule it in cron.

API key is read from bitfinex-apikey.yaml, format:
```
api_key: '...'
secret: '...'
```

Transaction log is written to stdout (buy/sell orders)
With `-v` switch, balance summary is written even without transactions.

# Notice

Absolutely no warranty, you might lose money using this. Use only at your own risk.
**I mean it, this is risky.**
