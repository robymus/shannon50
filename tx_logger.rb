require 'fileutils'
require 'date'

# Stdout/File/Web logger
class TxLogger
  LOG_LEVELS = %w[error info transaction none].freeze
  NONE = LOG_LEVELS.index('none')
  TRANSACTION = LOG_LEVELS.index('transaction')
  INFO = LOG_LEVELS.index('info')
  ERROR = LOG_LEVELS.index('error')

  def initialize(config)
    @level_stdout = LOG_LEVELS.index(config['stdout']['level']) || NONE
    @level_file = LOG_LEVELS.index(config['file']['level']) || NONE
    @level_web = LOG_LEVELS.index(config['web']['level']) || NONE
    # initialize file logging, if needed
    if @level_file > 0
      @log_file = config['file']['file']
      dir = File.dirname(@log_file)
      FileUtils.mkdir_p(dir) unless File.directory? dir
    end
    # initialize web logging, if needed
    if @level_web > 0
      @web_dir = config['web']['dir']
      FileUtils.mkdir_p(@web_dir) unless File.directory? @web_dir
    end
  end

  def config(conf)
    return if @level_web == NONE

    data = { 'timestamp' => Time.now.to_s, 'portfolio' => [] }
    conf['portfolio'].each do |ex|
      d = ex.reject{ |k, _| k == 'key' }
      d['file'] = "#{get_name(ex)}.json"
      data['portfolio'] << d
    end

    File.open("#{@web_dir}/config.json", 'w') do |f|
      f.puts(data.to_json)
    end
  end

  def error(ex, str)
    puts "[#{Time.now}] #{get_name(ex)} - #{str}" if @level_stdout <= ERROR
    append_log_file "[#{Time.now}] #{get_name(ex)} - #{str}" if @level_file <= ERROR
  end

  def info(ex, exchange_rate, balance_crypto, balance_fiat, value_crypto, crypto_percentage, fiat_percentage)
    text = "[#{Time.now}] #{ex['exchange']} #{exchange_rate} #{ex['fiat']}/#{ex['crypto']}" +
           " - #{balance_crypto.round(4)} #{ex['crypto']} (#{value_crypto.round(0)} #{ex['fiat']}, #{crypto_percentage.round(1)}%)" +
           ", #{balance_fiat.round(0)} #{ex['fiat']} (#{fiat_percentage.round(1)}%)" +
           " | portfolio: #{(balance_fiat+value_crypto).round(0)} #{ex['fiat']}"
    puts text if @level_stdout <= INFO
    append_log_file text if @level_file <= INFO
    if @level_web <= INFO
      txdata = {
        'timestamp' => Time.now.to_s,
        'type' => 'info',
        'exchange_rate' => exchange_rate,
        'balance_crypto' => balance_crypto,
        'balance_fiat' => balance_fiat
      }
      append_file(get_file(ex), txdata.to_json)
    end
  end

  # type should be 'sell' or 'buy'
  def transaction(ex, exchange_rate, balance_crypto, balance_fiat, value_crypto, crypto_percentage, fiat_percentage, type, amount)
    text = "[#{Time.now}] #{ex['exchange']} #{exchange_rate} #{ex['fiat']}/#{ex['crypto']}" +
        " - #{balance_crypto.round(4)} #{ex['crypto']} (#{value_crypto.round(0)} #{ex['fiat']}, #{crypto_percentage.round(1)}%)" +
        ", #{balance_fiat.round(0)} #{ex['fiat']} (#{fiat_percentage.round(1)}%)" +
        " => #{type.upcase} #{amount} #{ex['crypto']}" +
        " | portfolio: #{(balance_fiat+value_crypto).round(0)} #{ex['fiat']}"
    puts text if @level_stdout <= TRANSACTION
    append_log_file text if @level_file <= TRANSACTION
    if @level_web <= TRANSACTION
      txdata = {
        'timestamp' => Time.now.to_s,
        'type' => type,
        'amount' => amount,
        'exchange_rate' => exchange_rate,
        'balance_crypto' => balance_crypto,
        'balance_fiat' => balance_fiat
    }
      append_file(get_file(ex), txdata.to_json)
    end
  end

  private

  # gets name (string) from exchange config
  def get_name(ex)
    ex['id'] || "#{ex['exchange']}:#{ex['crypto']}:#{ex['fiat']}"
  end

  def get_file(ex)
    "#{@web_dir}/#{get_name(ex)}.json"
  end

  # append a line to the log file
  def append_log_file(str)
    append_file(@log_file, str)
  end

  # append a line to a file
  def append_file(fn, str)
    File.open(fn, 'a') do |f|
      f.puts str
    end
  end

end
