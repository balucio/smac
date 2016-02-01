/** Some custom js functions */

$(function () {

	var chartOptions = {

		credits : { enabled : false },

		chart: {
			renderTo : 'programma-giornaliero',
			type: 'area',
		},

		title : {
			text: '',
			floating : true,
		},

		xAxis: {
			startOnTick : false,
			endOnTick : false,
			labels : { enabled : true, reserveSpace :true},
			title : { text : null },
			type: 'datetime',
            dateTimeLabelFormats: {
                hour: '%H:%M',
                day :'%H:%M'
            }
		},

		yAxis: {
			title : { text : null },
			min : 0,
			minRange : 25,
			labels : { enabled : true, reserveSpace :true},

		},

		series: []
	}


	var requestProgramData = function(pid, day, process) {
		$.post(
			'programmazione',
			{
				program : pid,
				day : day
			},
			function(program) {
				process(program);
			}
		);
	}

	var isoDay = function() {

		var today = new Date();
		var day = today.getDay();

		// in javascript 0 = domenica
		if (!day)
			day = 7;

		return  day;
	}

	var colorGradient = function(items) {

		if (items <= 1)
			return [ '#FFFF00' ];

		var rainbow = new Rainbow();
		rainbow.setNumberRange(1, items);
		rainbow.setSpectrum('yellow', 'red');

		var colors = [];

		for (var i = 1; i <= items; i++)
    		colors.push('#' + rainbow.colourAt(i));

    	return colors;

	}

	var calculateNewChartSeries = function(data) {

		var today = new Date();
		var day = isoDay();

		if (!data.dettaglio || ! day in data.dettaglio)
			return;

		var schedule = data.dettaglio[day];
		var temps = data.temperature;

		// today and tomorrow
		today.setHours(0,0,0,0);
		var todaySec = today.getTime();
		today.setHours(24,0,0,0);
		var tomorrow = today.getTime();


		var seriesdata = [];

		var colors = colorGradient(temps.length);

		for ( var t = 0; t < temps.length; t++ ) {

			// Creating t series object
			var tdata = {
				color : colors[t],
				lineWidth : 0,
				pointstart : todaySec,
				name : "T<sub>" + temps[t].t_id + "</sub>",
				data : []
			};

			var points = tdata.data;
			var lastValue = 0;

			// parse shedule timing object
			for (var h = 0; h < schedule.length; h++) {

				var cS = schedule[h];

				var millisec = todaySec + cS.intervallo * 1000;

				points.push([
					millisec - 1000,
					lastValue
				]);

				lastValue = ( (cS.t_rif_codice == t) ? parseFloat(cS.t_rif_valore) : 0 );

				points.push([
					millisec,
					( (cS.t_rif_codice == t) ? lastValue : 0 )
				]);
			}

			// add last point to complete day
			if (tomorrow - millisec > 0)
				points.push([ tomorrow, lastValue ]);

			seriesdata.push(tdata);
		}

		return seriesdata;
	}

	var createChart = function(series) {

		var chartDiv = $('#programma-giornaliero');

		if (chartDiv.highcharts())
			chartDiv.highcharts().destroy();

		chartOptions.series = series;
		return new Highcharts.Chart(chartOptions);
	}

	// var pchart = getChart('temperatura');

	$( document ).ready(function() {

		$('#modifica-programma').click(function(){

			var obj = $(this);

			var lab = obj.data('altlabel');
			obj.data('altlabel', obj.text());
			obj.text(lab);

			obj.toggleClass('btn-primary');
			obj.toggleClass('btn-warning');

			var programma = $('#programma');

			programma.prop('disabled', obj.hasClass('btn-primary'));
			programma.selectpicker('refresh');

			// Saving actual program
			if (programma.is(':disabled')) {
				$.post('programma/salvaattuale', { program : programma.val() });
			}
		});

		$('#programma').change(function() {
			requestProgramData($(this).val(), isoDay(), function(reqData) {
				$('#temperature-riferimento').html(reqData.html);
				createChart(calculateNewChartSeries(reqData.jdata));
			});
		});

		// Requesting data
		requestProgramData(
			$('#programma').val(),
			isoDay(),
			function(reqData) {
				createChart(calculateNewChartSeries(reqData.jdata));
		});
	});
});


