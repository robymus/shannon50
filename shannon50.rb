require_relative 'exchange'
require_relative 'tx_logger'
require 'yaml'
require 'json'

# in test_mode (-test option) transactions are not executed
test_mode = ARGV.include? '-test'

# change to base directory
Dir.chdir(File.dirname(__FILE__))

# parse config
config = YAML.load_file('shannon50.yaml')

log = TxLogger.new(config['log'])
log.config(config)

# process all elements in portfolio
config['portfolio'].each do |ex|
  begin
    exchange = get_exchange(ex['exchange'], ex['key'])
    crypto = ex['crypto']
    fiat = ex['fiat']
    crypto_percent = (ex['crypto_percent'] || 50).to_f
    minimum_order_size = ex['minimum_order'] || exchange.get_minimum_order_size(crypto, fiat)

    exchange_rate = exchange.get_exchange_rate(crypto, fiat)
    balance_fiat = exchange.get_fiat_balance(fiat)
    balance_crypto = exchange.get_crypto_balance(crypto)

    minimum_order_size *= exchange_rate

    value_crypto = balance_crypto * exchange_rate
    portfolio = balance_fiat + value_crypto

    fiat_percentage = 100.0 * balance_fiat / portfolio
    crypto_percentage = 100.0 - fiat_percentage
    midway = portfolio * crypto_percent / 100.0

    # log current status
    log.info(ex, exchange_rate, balance_crypto, balance_fiat, value_crypto, crypto_percentage, fiat_percentage)

    # check if transaction is required and process transaction
    if value_crypto > midway + minimum_order_size
      # sell crypto
      amt = balance_crypto - midway / exchange_rate
      amt = amt.round(4)
      exchange.sell(crypto, fiat, amt) unless test_mode
      # log after successful execution
      log.transaction(ex, exchange_rate, balance_crypto, balance_fiat, value_crypto, crypto_percentage, fiat_percentage, 'sell', amt)
    elsif value_crypto < midway - minimum_order_size
      # buy crypto
      amt = midway / exchange_rate - balance_crypto
      amt = amt.round(4)
      exchange.buy(crypto, fiat, amt) unless test_mode
      # log after successful execution
      log.transaction(ex, exchange_rate, balance_crypto, balance_fiat, value_crypto, crypto_percentage, fiat_percentage, 'buy', amt)
    end

  rescue Exchange::Error => err
    log.error(ex, err.to_s)
  end
end
