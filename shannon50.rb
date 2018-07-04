require 'bitfinex-rb'
require 'yaml'
require 'uri'
require 'net/http'
require 'json'
require 'date'

# get btc/usd price
begin
	url = URI("https://api.bitfinex.com/v1/pubticker/btcusd")

	http = Net::HTTP.new(url.host, url.port)
	http.use_ssl = true

	request = Net::HTTP::Get.new(url)

	response = http.request(request)
	data = JSON.parse(response.read_body)
rescue Exception => e
	puts "[#{DateTime.now}] Error retrieving BTC/USD price: #{e.message}"
	exit 1
end
btcusd = data['mid'].to_f

# get minimum order size
begin
	url = URI("https://api.bitfinex.com/v1/symbols_details")

	http = Net::HTTP.new(url.host, url.port)
	http.use_ssl = true

	request = Net::HTTP::Get.new(url)

	response = http.request(request)
	data = JSON.parse(response.read_body)
	minimum_order_size = data.select {|x| x['pair'] == 'btcusd'}.collect {|x| x['minimum_order_size'].to_f * btcusd}.first
	raise Exception unless minimum_order_size
rescue Exception => e
	# fall back to 25 usd order size in case of error
	minimum_order_size = 25.0
end

# connect to authenticated api
begin
	config = YAML.load_file( File.expand_path('bitfinex-apikey.yaml', File.dirname(__FILE__)) )

	Bitfinex::Client.configure do |c|
	  c.secret = config['secret']
	  c.api_key = config['api_key']
	end

	client = Bitfinex::Client.new

	balance = client.balances

rescue Exception => e
	puts "[#{DateTime.now}] Error retrieving current balances: #{e.message}"
	exit 2
end

usd = balance.select {|x| x['type'] == 'exchange' && x['currency'] == 'usd'}.map{ |x| x['amount'].to_f}.first || 0
btc = balance.select {|x| x['type'] == 'exchange' && x['currency'] == 'btc'}.map{ |x| x['amount'].to_f}.first || 0
btcval = btc*btcusd
portfolio = usd + btcval

usd_percentage = 100*usd/(usd+btcval)
btc_percentage = 100-usd_percentage
midway = portfolio/2

if btcval > midway+minimum_order_size then
	# sell btc
	amt = btc - midway/btcusd
	amt = amt.round(4)
	puts "[#{DateTime.now}] $#{btcusd.round(0)}/BTC - #{btc.round(4)} BTC ($#{btcval.round(0)}, #{btc_percentage.round(1)}%), $#{usd.round(0)} (#{usd_percentage.round(1)}%) => SELL #{amt} BTC | portfolio: $#{portfolio.round(0)}"
	begin
		client.new_order("btcusd", amt, "exchange market", "sell")
	rescue Exception => e
		puts "[#{DateTime.now}] Order execution failed: #{e.message}"
		exit 3
	end
elsif btcval < midway-minimum_order_size then
	# buy btc
	amt = midway/btcusd - btc
	amt = amt.round(4)
	puts "[#{DateTime.now}] $#{btcusd.round(0)}/BTC - #{btc.round(4)} BTC ($#{btcval.round(0)}, #{btc_percentage.round(1)}%), $#{usd.round(0)} (#{usd_percentage.round(1)}%) => BUY #{amt} BTC | portfolio: $#{portfolio.round(0)}"
	begin
		client.new_order("btcusd", amt, "exchange market", "buy")
	rescue Exception => e
		puts "[#{DateTime.now}] Order execution failed: #{e.message}"
		exit 4
	end
else # difference is less than minimum order size
	puts "[#{DateTime.now}] $#{btcusd.round(0)}/BTC - #{btc.round(4)} BTC ($#{btcval.round(0)}, #{btc_percentage.round(1)}%), $#{usd.round(0)} (#{usd_percentage.round(1)}%) => BALANCED | portfolio: $#{portfolio.round(0)}" if ARGV.include? '-v'
end
