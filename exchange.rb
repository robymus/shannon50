#
# Exchange interface definition
#
require 'bitfinex-rb'
require 'kraken_ruby'
require 'yaml'
require 'uri'
require 'net/http'
require 'json'


# interface definition for exchanges
class Exchange
  # Common exception thrown by exchange operations
  class Error < StandardError
  end

  # return balance of crypto asset
  def get_crypto_balance(crypto) end

  # return balance of fiat asset
  def get_fiat_balance(fiat) end

  # return exchange rate
  def get_exchange_rate(crypto, fiat) end

  # get minimum order size
  def get_minimum_order_size(crypto) end

  # buy crypto currency
  def buy(crypto, fiat, crypto_amount) end

  # sell crypto currency
  def sell(crypto, fiat, crypto_amount) end
end

# Bitfinex exchange implementation
class ExBitfinex < Exchange
  def initialize(key)
    @config = YAML.load_file(File.expand_path(key, File.dirname(__FILE__)))

    Bitfinex::Client.configure do |c|
      c.secret = @config['secret']
      c.api_key = @config['api_key']
    end

    @client = Bitfinex::Client.new
    @balances = @client.balances
  rescue
    raise Error, 'Retrieving balances failed'
  end

  # return balance of crypto asset
  def get_crypto_balance(crypto)
    @balances.select {|x| x['type'] == 'exchange' && x['currency'] == crypto.downcase}
             .map { |x| x['amount'].to_f}
             .first || 0
  end

  # return balance of fiat asset
  def get_fiat_balance(fiat)
    get_crypto_balance(fiat)
  end

  # return exchange rate
  def get_exchange_rate(crypto, fiat)
    pair = "#{crypto.downcase}#{fiat.downcase}"
    url = URI("https://api.bitfinex.com/v1/pubticker/#{pair}")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)

    response = http.request(request)
    data = JSON.parse(response.read_body)
    data['mid'].to_f
  rescue
    raise Error, "Getting exchange rate #{crypto}:#{fiat} failed"
  end

  # get minimum order size
  def get_minimum_order_size(crypto, fiat)
    pair = "#{crypto.downcase}#{fiat.downcase}"
    url = URI('https://api.bitfinex.com/v1/symbols_details')

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)

    response = http.request(request)
    data = JSON.parse(response.read_body)
    minimum_order_size = data.select {|x| x['pair'] == pair}
                             .collect {|x| x['minimum_order_size'].to_f}
                             .first
    raise Exception unless minimum_order_size
    minimum_order_size
  rescue
    raise Error, "Can't retrieve minimum order size for #{crypto}:#{fiat}"
  end

  # buy crypto currency
  def buy(crypto, fiat, crypto_amount)
    pair = "#{crypto.downcase}#{fiat.downcase}"
    @client.new_order(pair, crypto_amount, 'exchange market', 'buy')
  rescue
    raise Error, 'Buy order failed'
  end

  # sell crypto currency
  def sell(crypto, fiat, crypto_amount)
    pair = "#{crypto.downcase}#{fiat.downcase}"
    @client.new_order(pair, crypto_amount, 'exchange market', 'sell')
  rescue
    raise Error, 'Sell order failed'
  end

end


# creates an exchange for the given name with the specific key
def get_exchange(exchange_name, key)
  case exchange_name.downcase
  when 'bitfinex'
    ExBitfinex.new(key)
  else
    raise Exchange::Error, "Undefined exchange '#{exchange_name}'"
  end
end