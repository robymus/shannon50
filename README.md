# Constant-proportion rebalanced portfolio bot

Minimal crypto bot, supporting Bitfinex and Kraken exchanges.

It simply does a constant proportion portfolio re-balancing, between a selected crypto currency and a selected fiat currency.

In its original verion it used 50-50% balance (this is still the default), as suggested by Shannon for stock markets, but now it can be overridden.

The script does the re-balancing on every run, so it should be run from cron.

# Configuration

Configuration is read from shannon50.yaml in the same directory as the script.

A sample configuration is located in the shannon50.yaml file, with some comments.

The script can write to several log destinations: standard output, log file and json files prepared for the web report module.

The API keys should be written to separate yaml files. 

## Bitfinex API key

The yaml file format for Bitfinex API keys is

```
api_key: 'key here'
secret: 'secret key here'
```

## Kraken API key

The yaml file format for Bitfinex API keys is

```
api_key: 'key here'
secret: 'private key here'
```

# Command line arguments

The single `-test` argument is supported, if this is present, no transactions are performed, but logs are written as if they were.

# Web report

Soon.

# Important notice

Absolutely no warranty, you might lose money using this. Use only at your own risk.
**I mean it, this is risky.**
