/** Some custom js functions */

$(function () {

	var MaxT = 4;
	var NumT = 0;
	var Temps = [];

	var showProgramModal = function(data) {

		var modal = $('#program-modal').modal();
		modal.show();

		var slist = $('#elenco-sensori');
		slist.find('option').remove();

		var pid = $('#id_programma');
		var pname = $('#id_programma');
		var pdescr = $('#descrizione_programma');
		var psid = 0;
		var ptrif = [{id : 0, val : 20}];

		if (data) {
			pid.val(data.hasOwnProperty("id_programma") ? data.id_programma : pid);
			pname.val(data.hasOwnProperty("nome_programma") ? data.nome_programma : pname);
			pdescr.val(data.hasOwnProperty("descrizione_programma") ? data.descrizione_programma : pdescr);
			psid = data.hasOwnProperty("id_sensore_riferimento") ? data.id_sensore_riferimento : psid;
			ptrif = data.hasOwnProperty("temperature_riferimento") ? data.temperature_riferimento : ptrif;
		}

		createSensorList(0, slist);
		createTemperature(ptrif);

		slist.val(0);
	}

	var createTemperature = function(t) {

		var mdiv = $('#programma-temperature');
		var model = $('#programma-temperature').children().first();
		mdiv.children().not(':first').remove();
		NumT = 0;
		Temps.splice(0,Temps.length);

		for ( var i = 0; i < MaxT; i++ )
			mdiv.append(addTempInput(model, t[i].val));
	}


	var addTempInput = function(model, v) {

		if (Temps.length >= MaxT)
			return null;

		var cnt = model.clone();
		cnt.removeClass('hidden');

		Temps.push(cnt);
		NumT++;

		// Setup input
		if (v)
			cnt.find('input').val(v);

		// Setup del pulsante aggiungi
		var addbtn = cnt.find('button.temperature-add');
		addbtn.click(function() {
			$('#programma-temperature').append(addTempInput(model, null));
		});

		// Setup del pulsante elimina
		var delbtn = cnt.find('button.temperature-del');
		delbtn.click(function() {
			if (NumT == 1)
				return;
			// Ricavo la posizione relativa dell'elemento considerando il div nascosto
			var id = $('#programma-temperature').children().index($(this).closest('div'));
			var j = NumT - ( id != NumT ? 1 : 2 );

			Temps[ j ].find('button.temperature-add').removeClass('hidden');

			// Se rimarrà un solo input temperature rimuovo possibilità di rimuoverlo
			if ( NumT == 2 )
				Temps[ j ].find('button.temperature-del').addClass('hidden');

			Temps.splice(id - 1, 1);

			NumT--;
			cnt.remove();
		});

		var tn = Temps.length;

		// Correggo visualizzazione pulsanti temperatura precedente
		if (tn > 1) {
			Temps[ tn  - 2 ].find('button.temperature-add').addClass('hidden');
			Temps[ tn  - 2 ].find('button.temperature-del').removeClass('hidden');
		}

		// Correggo visualizzazione pulsanti temperatura attuale
		if (tn < MaxT)
			addbtn.removeClass('hidden');

		delbtn.removeClass('hidden');

		return cnt;
	}

	var createSensorList = function(sid, select) {
		$.post('/program/getsensorlist',
			{sensor: sid},
			function(data) {
				if (data.sensorlist) {
					var s = data.sensorlist;
					for (var i = 0; i < s.length	; i++)
						select.append(
							$("<option></option>")
								.attr("value", s[i].id_sensore)
								.text(s[i].nome_sensore)
						);
				}
		});
	}

	$( document ).ready(function() {
		// Selezione del programma da elenco
		$('li.seleziona-programma').click(function(event){

			var progr = $(this);

			$.post(
				'/program/getschedule',
				{ program: progr.data('id'), day : 0 },
				function(data) {
					if (data.schedule) {
						$('#orari-programma').parent().html(data.schedule);
						var exProgram = $('li.seleziona-programma.active');
						exProgram.find('span.program-action').addClass('hidden');
						exProgram.removeClass('active');
						progr.addClass('active');
						progr.find('span.program-action').removeClass('hidden');
					}
				}
			);
		});
		// Nuovo programma
		$('#new-program').click(function(event) {
			event.preventDefault()
			showProgramModal(null);
		});
		// Modifica programma
		$('a.modifica-programma').click(function(event) {
			// Ottengo i dati del programma
			$.post(
				'/program/getdata',
				{ program : $(this).data('id') },
				function(data) {
					showProgramModal(data);
				}
			);
			// Visualizzo e popolo il modale

		});
		// Elimina programma
		$('a.elimina-programma').click(function(event) {

		});

	});
});


