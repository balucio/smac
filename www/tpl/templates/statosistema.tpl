<div class="col-xs-12 col-md-6">
	<div class="panel panel-primary">
		<div class="panel-heading">Stato Sistema</div>
		<div class="panel-body">
			<div class="col-xs-12 col-md-10">
				<select id="programma" class="selectpicker form-control" disabled>
					{{#special_program}}
					<option title="{{nome_programma}}" value="{{id_programma}}" {{selected}} >{{descrizione_programma}}</option>
					{{/special_program}}
					<option data-divider="true"></option>
					{{#other_program}}
					<option title="{{nome_programma}}" value="{{id_programma}}" {{selected}} >{{descrizione_programma}}</option>
					{{/other_program}}
				</select>
			</div>
			<div class="col-xs-12 col-md-2">
				<button id="modifica-programma" type="button" data-altlabel="Applica" class="btn btn-primary btn-block">Modifica</button>
			</div>
			<br/>
			<div class="clearfix"></div>
			<h4 class="text-center"><span class="wi wi-thermometer" aria-hidden="true"> </span> Temperature di riferimento</h4>
				<div id="temperature-riferimento">
					<!-- PARTIAL -->
					{{>temperature_riferimento}}
				</div>

			<div class="clearfix"></div>
      		<hr class="col-xs-10 col-md-10" style="" />
			<div class="col-xs-12 col-md-12" id="programma-giornaliero" style="height:400px;"></div>

		</div>
		<div class="panel-footer text-center">
			<small class="text-muted">Riferimento attuale: <span class="wi wi-thermometer" aria-hidden="true"></span>
				<span>{{#decorateTemperature}}{{rif_temp_attuale}}{{/decorateTemperature}}</span>
				<span class="wi wi-celsius fa-1x" aria-hidden="true"></span></span>
			</small>
		</div>
	</div>
</div>