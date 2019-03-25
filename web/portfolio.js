/**
 * Initial entry point - fetches config and initiates tx log reading
 * @param baseDir base directory for web logs
 */
function fetchConfig(baseDir) {
	var configUrl = baseDir + '/config.json';
	console.log('Fetching config: ' + configUrl);
	$.ajax(configUrl)
		.done(function(config) {
			$('#lastupdate').text(config['timestamp']);
			for (i in config['portfolio']) {
				var pair = config['portfolio'][i];
				readData(i, pair, baseDir + '/' + pair['file']);
			}
		})
		.fail(function() {
			console.log('Fetching config failed, retrying in 5 seconds');
			setTimeout(function() {
				fetchConfig(baseDir);
			}, 5000);
		});
}

/**
 * Reads additional data files
 * @param idx data index, for ordering
 * @param pair data for currency pair - {exchange: "Bitfinex", crypto: "BTC", fiat: "USD", crypto_percent: 50, file: "Bitfinex:BTC:USD.json"}
 * @param dataUrl location of tx log
 */
function readData(idx, pair, dataUrl) {
	$.ajax(dataUrl, {dataType: "text"})
		.done(function(result) {
			createPanel(idx, pair, result.split("\n").slice(0, -1).map(JSON.parse));
		})
		.fail(function() {
			console.log('Fetching data failed, retrying in 5 seconds');
			setTimeout(function() {
				fetchConfig(baseDir);
			}, 5000);
		});
}

/**
 * Creates a panel with data from exchange
 * @param idx data index, for ordering
 * @param pair data for currency pair - {exchange: "Bitfinex", crypto: "BTC", fiat: "USD", crypto_percent: 50, file: "Bitfinex:BTC:USD.json"}
 * @param txlog array of transactions 
 *				- {timestamp: "2019-03-25 11:00:03 +0000", type: "info", exchange_rate: 49.58, balance_crypto: 8.45520109, balance_fiat: 419.8472}
 * 				- {"timestamp":"2018-12-04 08:00:03 +0000","type":"sell"|"buy","amount":0.0026,"exchange_rate":4051.5,"balance_crypto":0.12291244,"balance_fiat":477.19499963}
 */
function createPanel(idx, pair, txlog) {
	// get current balance from last tx
	var balance = {total: "-", crypto: "-", rate: "-"};
	var i = txlog.length-1;
	while (i >= 0) {
		var last = txlog[i];
		if (last['balance_crypto'] == 0 && last['balance_fiat'] == 0) {
			i--;
			continue;
		}
		balance['total'] = (last['balance_fiat'] + last['balance_crypto']*last['exchange_rate']).toFixed(1);
		balance['crypto'] = last['balance_crypto'].toFixed(4);
		balance['rate'] = last['exchange_rate'].toFixed(2);
		break;
	}
	// last 5 transactions
	var i = txlog.length-1;
	var cnt = 5;
	var lasttx = [];
	while (i >= 0 && cnt > 0) {
		var tx = txlog[i];
		if (tx['type'] != 'info') {
			lasttx.push({
				buy: tx['type'] == 'buy',
				sell: tx['type'] == 'sell',
				time: tx['timestamp'].substring(0, 16),
				amount: tx['amount'].toFixed(4),
				rate: tx['exchange_rate'].toFixed(2)
			});
			cnt--;
		}
		i--;
	}
	// render item
	var chartid="chart"+idx;
	Object.assign(pair, {idx: idx, balance: balance, lasttx: lasttx, chartid: chartid});
	var template = $('#item_template').html();
	var rendered = Mustache.render(template, pair);
	var container = $('#item_container');
	container.append(rendered);
	// sort items in container by idx
	var items = container.children();
	if (items.length > 1) {
		items.sort(function(a,b) {
			var an = parseInt(a.getAttribute('data-idx'));
			var bn = parseInt(b.getAttribute('data-idx'));
			if (an > bn) return 1;
			else if (an < bn) return -1;
			else return 0;
		});
		items.detach().appendTo(container);
	}
	// collect data from info elements
	var fiatvalue = []
	var baseline = []
	var basecrypto = false
	var lastcrypto = 0
	for (var i = 0; i < txlog.length; i++) {
		var tx = txlog[i];
		if (tx['type'] == 'sell') {
			lastcrypto -= tx['amount'];
			continue;
		}
		if (tx['type'] == 'buy') {
			lastcrypto += tx['amount'];
			continue;
		}
		if (tx['balance_fiat'] == 0 && tx['balance_crypto'] == 0) continue;
		// check if crypto value has been changed - update basecrypto (eg. mining income, etc.)
		if (basecrypto == false) {
			basecrypto = tx['balance_crypto'] + tx['balance_fiat'] / tx['exchange_rate'];
			lastcrypto = tx['balance_crypto'];
		}
		else if (Math.abs(lastcrypto-tx['balance_crypto']) > 0.01) {
			var diff = tx['balance_crypto'] - lastcrypto;
			lastcrypto += diff;
			basecrypto += diff;
		}

		baseline.push((basecrypto * tx['exchange_rate']).toFixed(1));
		fiatvalue.push((tx['balance_fiat']+tx['balance_crypto']*tx['exchange_rate']).toFixed(1));
	}
	var data = {
		  series: [
		  	fiatvalue,
		  	baseline
		  ]
		};
	var options = {
		showPoint: false,
		showGridBackground: false,
		fullWidth: true,
		axisY: {
			showGrid: true
		},
		axisX: {
			showGrid: false
		}
	};
	new Chartist.Line('#'+chartid, data, options);
}