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
			'program/getProgramData',
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

	var colorGradient = function(temps) {

		// da -8 a +36 passo 2
		//     0 a 21  passo 2
		var ctable = [
			'#0A36AD',
			'#1514F4',
			'#1080F6',
			'#05BFF9',
			'#00FFFE',
			'#00F7CA',
			'#0BD794',
			'#00AA6C',
			'#26AA43',
			'#24C84B',
			'#00FF52',
			'#CBFE54',
			'#FEFE56',
			'#ECEC8E',
			'#E4CB75',
			'#DCAD5A',
			'#FF5324',
			'#FF001A',
			'#C80012',
			'#AD000E',
			'#93000A',
			'#780006'
		];

		var closestTo = function(v) {

			var t = Math.round(v);
			t = ( ( ( t % 2 == 0 ) ? t : ( t + 1 ) ) + 8 ) / 2;

			t = Math.max(0, t);
			t = Math.min(ctable.length - 1, t);

			return ctable[t];
		}


		var items = temps.length;

		if (items == 0)
			return ctable[0];

		if (items == 1)
			return [ closestTo(temps[0].val) ];

		var rainbow = new Rainbow();
		rainbow.setNumberRange(1, items);

		var mincol = closestTo(temps[0].val);
		var maxcol = closestTo(temps[items -1].val);

		rainbow.setSpectrum(mincol, maxcol);

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

		var colors = colorGradient(temps);

		for ( var t = 0; t < temps.length; t++ ) {

			// Creating t series object
			var tdata = {
				color : colors[t],
				lineWidth : 0,
				pointstart : todaySec,
				name : "T<sub>" + temps[t].id + "</sub>",
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

				lastValue = ( ( cS.t_rif_codice == temps[t].id ) ? parseFloat(cS.t_rif_valore) : 0 );

				points.push([
					millisec,
					( (cS.t_rif_codice == temps[t].id ) ? lastValue : 0 )
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

	var getBoilerStatus = function() {
		$.ajax({
			url: 'switcher/state',
			success: function(data) {
				if (data.hasOwnProperty("result")) {
					$('#boiler-status-icon').removeClass()
					$('#boiler-status-icon').addClass(data.classes)
				}
			},
			complete: function() {
			  // programmo prossima richiesta solo al completamento di questa
			  setTimeout(getBoilerStatus, 60000);
			}
  		});
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
				$.post(
					'program/savedefault',
					{ program : programma.val() },
					function(data) {
						if (!data.hasOwnProperty("program") || data.program == null)
							alert("Impossibile salvare il programma");
				});
			}
		});

		$('#programma').change(function() {
			requestProgramData($(this).val(), isoDay(), function(reqData) {
				$('#temperature-riferimento').html(reqData.temp_riferimento);
				$('#temp_riferimento_attuale').html(reqData.temp_rif_att)
				createChart(calculateNewChartSeries(reqData));
			});
		});

		// Requesting data
		requestProgramData(
			$('#programma').val(),
			isoDay(),
			function(reqData) {
				createChart(calculateNewChartSeries(reqData));
		});

		// Boiler status
		getBoilerStatus()
	});
});


