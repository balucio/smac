/** Some custom js functions */

$(function () {


	var MaxT = 4;
	var NumT = 0;
	var Temps = [];

	var Schedule = {

		data : [],
		size : 0,
		self : this,

		copy : function(tr) {

			self.data = [];
			self.size = 0;

			var t = [];

			tr.each(function(idx, elm) {

				var d = $(elm);
				var tid = d.data('tempid');

				if (t.indexOf(tid) == -1) {
					t.push(tid);
					self.size++;
				}

				self.data.push({
					time : d.data('time'),
					temp : tid
				});
			});
		},

		getSize : function() { return self.size; },

		getData : function() { return self.data; }

	};

	var setupValidation = function(form) {

		return form.parsley({

			successClass: "has-success",
			errorClass: "has-error",
			classHandler: function (el) {
				return el.$element.closest(".form-group");
			},
			errorsContainer: function (el) {
				return el.$element.closest(".form-group");
			},
			errorsWrapper: '<span class="help-block"></span>',
			errorTemplate: '<div class="col-sm-9 col-md-offset-3"></div>'
		});
	}

	var showProgramModal = function(data) {

		var form = $("#program-modal").find('form');

		var validation = setupValidation(form);

		var modal = $('#program-modal').modal();

		modal.on('hidden.bs.modal', function () {
			validation.destroy();
			$('#program-message').empty();
			$('#program-message').addClass('hidden');
			$(this).data('bs.modal', null);
		});

		$("#program-save").click(function(e){
			e.preventDefault();
			if (!validation.validate())
				return false;
			sendProgramData(form);
		});

		var slist = $('#elenco-sensori');
		slist.find('option').remove();

		var pid = $('#id_programma');
		var pname = $('#nome_programma');
		var pdescr = $('#descrizione_programma');
		var psid = 0;
		var ptrif = [{id : 0, val : 20}];

		if (data) {
			pid.val(data.hasOwnProperty("id_programma") ? data.id_programma : '');
			pname.val(data.hasOwnProperty("nome_programma") ? data.nome_programma : '');
			pdescr.val(data.hasOwnProperty("descrizione_programma") ? data.descrizione_programma : '');
			psid = data.hasOwnProperty("id_sensore_riferimento") ? data.id_sensore_riferimento : psid;
			ptrif = data.hasOwnProperty("temperature_riferimento") ? data.temperature_riferimento : ptrif;
		} else {
			pid.val('');
			pname.val('');
			pdescr.val('');
		}

		createSensorList(psid, slist);
		createTemperature(ptrif);
	}

	var createTemperature = function(t) {

		var mdiv = $('#programma-temperature');
		var model = $('#programma-temperature').children().first();

		mdiv.children().not(':first').remove();
		NumT = 0;
		Temps.splice(0,Temps.length);

		if (t.length > MaxT)
			t.length = MaxT;

		for ( var i = 0; i < t.length; i++ )
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
		var input = cnt.find('input');
		input.addClass('temperature');
		input.attr('name', 'temperature[]');
		input.attr("data-parsley-alldifferent", null);

		if (v)
			input.val(v);

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

		if ( tn > 1 )
			delbtn.removeClass('hidden');

		return cnt;
	}

	var addProgramListEvent = function() {

		// Selezione del programma da elenco
		$('li.seleziona-programma').click(function(event){

			var progr = $(this);
			// Provo a mantenere anche lo stesso giorno al momento selezionato
			var day = $('#programmazione-settimanale').find('li.active').data('day');

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
						addProgramScheduleEvent();

						if (day === parseInt(day,10))
							$('#programmazione-settimanale').find('li').eq(day -1 ).find('a').click();
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
		});

		// Elimina programma
		$('a.elimina-programma').click(function(e) {

			e.preventDefault();
			var pid = $(this).data('id');

			// Inizializzo il modale
			$('#confirm-delete').showDeleteConfirm(
				'confirm-delete-program-header',
				'confirm-delete-program-body',
				function() {
					$.post(
						"/program/delete",
						{ program : pid },
							function(data) {
								refreshProgramList(function() {
									$('#elenco-programmi').find('li.seleziona-programma').first().click();
								});
							}
					);
				}
			);
		});
	}

	var addProgramScheduleEvent = function() {

		// Aggiungi programmazione oraria
		$('button.schedule-add').click(function(e) {
			e.preventDefault();
			editSchedule($(this));
		});

		$('a.schedule-edit').click(function(e) {
			e.preventDefault();
			editSchedule($(this).closest('tr'));
		});

		// Elimina programmazione oraria
		$('a.schedule-delete').click(function(e) {
			e.preventDefault();
			deleteSchedule($(this).closest('tr'));
		});

		$('button.schedule-paste').click(function(event) {

			var btndata = $(this).closest('table').find('thead button.schedule-add');
			var msgBody = '';

			if ( !Schedule.getSize() )
				msgBody = 'confirm-noscheduledatatopaste-body';

			else if ( Schedule.getSize() > $('.valore_temperatura').length )
				msgBody = 'confirm-incompatibileschedule-body';

			if (msgBody.length != 0)
				$('#confirm-delete').showDeleteConfirm('confirm-pasteschedule-header', msgBody);
			else {
				sendScheduleData({
						program : btndata.data('program'),
						day : btndata.data('day'),
						schedule : Schedule.getData()
					},
					function(){
						$('#elenco-programmi')
							.find("li.seleziona-programma[data-id='"+ $('#schedule-program').val() + "']")
							.click();
					}
				);
			}
		});

		$('button.schedule-copy').click(function(event) {
			var tr = $(this).closest('table').find('tbody tr');
			Schedule.copy(tr);
			$(this).find('span.glyphicon').css('color', 'red');
		});
	}

	var refreshProgramList = function(callback) {

		var pid = $('#elenco-programmi').find('li.seleziona-programma.active').data('id');

		$.post('/program/getList',
			{ program: pid },

			function(data) {
				if (data.programlist) {
					var div = $('#elenco-programmi').parent();
					$('#elenco-programmi').remove();
					div.html(data.programlist);
					addProgramListEvent();
					typeof callback === 'function' && callback();
				}
		})
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
								.attr("value", s[i].id)
								.text(s[i].nome)
						);
				}
				select.val(sid);
				select.selectpicker('refresh');
		});
	}

	var editSchedule = function(node) {

		var validation = setupValidation($('#schedule-modal').find('form'));

		var modal = $('#schedule-modal').modal();

		modal.on('hidden.bs.modal', function () {
			validation.destroy();
			$('#schedule-message').empty();
			$('#schedule-message').addClass('hidden');
			$(this).data('bs.modal', null);
		});

		// Populating modal input
		$('#schedule-program').val(node.data('program'));
		$('#schedule-day').val(node.data('day'));

		// Creating temperature option
		select = $("#schedule-temp");
		select.find('option').remove();
		$('.valore_temperatura').each(
			function(n,v) {

				var tid = $(v).data('tempid');
				var tval = $(v).data('tempval');

				select.append(
					$("<option></option>")
						.attr("value", tid )
						.text(tval + '°')
				);
		});
		select.selectpicker('refresh');
		var tid = node.data('tempid');
		if (tid)
			select.val(tid);

		select.selectpicker('refresh');

		// Se non è c'è alcun tempo passato si tratta di una
		// nuova programmazione oraria quindi cerco la prima ora netta libera
		var stime = node.data('time');

		if (!stime) {

			var otime = $('#programma-giornaliero > div.tab-pane.active')
				.find('time').last().text().split(':');

			var stime = ('0'  + (( (+otime[0]) + 1 ) % 24)).slice(-2) + ':' + otime[1];

			$('#schedule-time').timepicker('setTime', stime);

		} else {
			// In caso di modifica impedisco di editare il campo orario
			$('#schedule-time').attr('readonly', true).val(stime);
		}

		// Salvataggio dei dati, solo una invocazione
		$('#schedule-save').one('click', function(e) {

			e.preventDefault();

			if (!validation.validate())
				return false;

			sendScheduleData(
				$('#schedule-modal').find('form').serialize(),
				function(){
					$('#elenco-programmi')
						.find("li.seleziona-programma[data-id='"+ $('#schedule-program').val() + "']")
						.click();
				}
			);
		});
	}

	var deleteSchedule = function(odata) {

		// Inizializzo il modale
		$('#confirm-delete').showDeleteConfirm(
			'confirm-delete-schedule-header',
			'confirm-delete-schedule-body',
			function() {
				$.post(
					"/program/deleteSchedule",
					{
						program : odata.data('program'),
						day : odata.data('day'),
						'schedule[][time]' : odata.data('time')
					}, function(data) {
						$('#elenco-programmi').find('li.seleziona-programma').first().click();
					}
				);
			}
		);
	}

	var sendScheduleData = function(data, callback) {

		var showMessage = function(msgid) {
			var msg = $('#schedule-message');
			msg.append($('#' + msgid).clone());
			msg.removeClass('hidden');
		}

		var removeMessage = function() {
			var msg = $('#schedule-message');
			msg.empty();
			msg.addClass('hidden');
		}

		removeMessage();

		$.ajax({

			type : "POST",
			url : "/program/createOrUpdateSchedule",
			data : data,

			success : function(data) {

				var msgid = 'message-err-comm';

				if (!data || !data.hasOwnProperty("status")) {
					showMessage(msgid);
					return;
				}

				if (data.status == true) {
					$('#schedule-modal').modal('hide');
					$('#elenco-programmi').find("li.seleziona-programma[data-id='"+ data.pid + "']").click();
					return;
				}

				if (data.hasOwnProperty("msgid") && $('#' + data.msgid).length)
					msgid = data.msgid;

				showMessage(msgid);
			},

			error: function() { showMessage('message-err-comm'); },

			complete : function() {typeof callback === 'function' && callback(); }

		});
	}

	var sendProgramData = function(form) {

		var showMessage = function(msgid) {
			var msg = $('#program-message');
			msg.append($('#' + msgid).clone());
			msg.removeClass('hidden');
		}

		var removeMessage = function() {
			var msg = $('#program-message');
			msg.empty();
			msg.addClass('hidden');
		}

		removeMessage();

		$.ajax({
			type: "POST",
			url: "/program/createOrUpdate",
			data: form.serialize(),
			success: function(data) {

				var msgid = 'message-err-comm';

				if (!data || !data.hasOwnProperty("status")) {
					showMessage(msgid);
					return;
				}

				if (data.status == true) {
					$('#program-modal').modal('hide');
					refreshProgramList(function(){
						$('#elenco-programmi').find("li.seleziona-programma[data-id='"+ data.pid + "']").click();
					});
					return;
				}

				if (data.hasOwnProperty("msgid") && $('#' + data.msgid).length)
					msgid = data.msgid;

				showMessage(msgid);
			},

			error: function() { showMessage('message-err-comm'); }

		});
	}

	$( document ).ready(function() {

		// Setup eventi lista programmi
		addProgramListEvent();
		// Setup eventi programmazione oraria
		addProgramScheduleEvent();

		/*
		 * Validatore differentNumbercustom per impedire che alcuni alcuni campi
		 * input numerici identificati da una particolare classe abbiano lo stesso
		 * valore. La validazione è di tipo numerica e la funzione di validazione
		 * stessa richiede due parametri value e requirements. Requirements è la classe
		 * dei campi input i cui valori verranno confrontanti. Value è il valore attuale
		 * del campo input. Tale valore viene ignorato, in quanto il controllo di
		 * validità viene eseguito in un campo nascosto della form.
		 *
		 */
		window.Parsley.addValidator('alldifferent', {

			validateString: function(value, requirements) {

				var values = [];
				var common = false;

				$( '.' + requirements ).each( function() {

					var v = $( this ).val();
					if (values.indexOf(v) != -1) {
						common = true;
						return false;
					}
					values.push(v);
				});

				return !common;
			},
			priority: 32,
			messages: {
				en : 'Values must be different',
				it : 'I valori devono essere diversi',
				es : 'Todo el valor debe ser diferente',
				fr: 'Tout valeur doit être différente',
				de : 'Alle Wert muss anders sein',
			}
		});
	});
});


