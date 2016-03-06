<div class="col-xs-12 col-md-6">
	<div class="panel panel-primary">
		<div class="panel-heading">Stato Sensori</div>
		<div class="panel-body">
			<select id="sensore" class="selectpicker" data-width="100%">
				{% set divider = (sensori|first).incluso_in_media %}
				{% for s in sensori %}
					{% if divider != s.incluso_in_media %}
						<option data-divider="true"></option>
						{% set divider = s.incluso_in_media %}
					{% endif %}
					<option value="{{s.id_sensore}}">{{s.nome_sensore}}</option>
				{% endfor %}
			</select>
			<h3 class="temperature">
				<div class="col-xs-6 col-md-3 text-right"><small>Temperatura :</small></div>
				<div class="col-xs-6 col-md-3">
					<span class="wi wi-thermometer" aria-hidden="true"></span>
					<span id="temperature-value">{{ sensore.temperatura|Temperature|raw }}</span>
					<span class="wi wi-celsius fa-1x" aria-hidden="true"></span>
				</div>
			</h3>
			<br class="clearfix visible-xs-block">
			<h3 class="humidity">
				<div class="col-xs-6 col-md-3 text-right"><small>Umidità :</small></div>
				<div class="col-xs-6 col-md-3">
					<span class="wi wi-humidity" aria-hidden="true"></span>
					<span id="humidity-value">{{ sensore.umidita|Umidity }}</span>
					<span class="fa fa-percent" aria-hidden="true"></span>
				</div>
			</h3>
			<div class="clearfix"></div>
			<hr class="col-xs-10 col-md-10" style="" />

			<div class="col-xs-12 col-md-12" id="andamento-temperatura" style="height:225px;"></div>
			<div class="col-xs-12 col-md-12" id="andamento-umidita" style="height:225px;"></div>

		</div>
		<div class="panel-footer text-center">
			<small class="text-muted">
				Ultimo aggiornamento <span id="last-update">{{sensore.ultimo_aggiornamento|DateTime}}</span>
			</small>
		</div>
	</div>
</div>