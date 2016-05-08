/** Some custom js functions */

$(function () {

	var sec_hours = 3600;	// one hour
	var req_interval = 60;	// seconds

	var sensorChanged = function() {
		var sid = $(this).val();
		// requesting new sensor data
		$.post(
			'sensor/setSensorId',
			{ sensor : sid },
			function(datisensore) {
				for (var oid in datisensore)
					if (datisensore.hasOwnProperty(oid))
        				$('#'+oid).html(datisensore[oid]);
			}
		);
		// Force update event on graph
		tchart.series[0].setData([]);
		getStats(tchart.series[0], sid, 'temperatura');
		hchart.series[0].setData([]);
		getStats(hchart.series[0], sid, 'umidita');


	}

	var sheduleDraw = function (series, sensor, type) {

		getStats(series, sensor, type );
		setTimeout( function(){ sheduleDraw(series, sensor, type); }, req_interval * 1000 );

	}

	var getStats = function(series, sensor, type) {

		// Get actual number of point
		var pntno = series.data.length;

		// no point request the last hour else request last minute
		var interval = pntno <= 0 ? (req_interval * 60) : null;

		var post_data = { sensor : sensor };

		if (!interval) {

			var lastPoint = series.data[pntno-1];
			post_data.date_start = (lastPoint.x / 1000) + 1

		} else {

			post_data.interval = interval;
		}

		$.post(
			'sensor/stats/' + type,
			post_data,

			function(data) {

				if (!data.hasOwnProperty("points"))
					return

				var points = data.points;

				// needs to redraw
				if (points.length != 0) {

					if (points.length > 2)
						series.setData(points, true);
					else
						series.addPoint(points, true, true);
				}

				// Aggiorno data e ora
				$('#last-update').text(data.updated)
			}
		);
	}

	function getChart(type) {

		if (!$('#andamento-' + type).length)
			return;

		var colors = {
			temperatura : '#ED561B',
			umidita : '#6AF9C4'
		};

		var label = type.charAt(0).toUpperCase() + type.slice(1);

		return new Highcharts.Chart({

			credits : { enabled : false },

			chart: {
				renderTo : 'andamento-' + type,
				type: 'line',
				events: {
					load : function () {
						var series = this.series[0];
						sheduleDraw(series, $('#sensore').val(), type );
					}
				}
			},

			title : {
				text: '',
				floating : true,
			},

			xAxis: {
				labels : { enabled : true, reserveSpace :true},
				title : { text : null },
				type: 'datetime'
			},

			yAxis: {
				title : { text : null },
				labels : { enabled : true, reserveSpace :true},

			},

			series: [{
				color : colors[type],
				lineWidth : 1,
				name: label,
				data: [ ],
				marker : { radius : 2 }
			}]
		});
	}

	var tchart = getChart('temperatura');
	var hchart = getChart('umidita');

	$( document ).ready(function() {
		if ($('#sensore').length)
			$('#sensore').change(sensorChanged);
	});
});


