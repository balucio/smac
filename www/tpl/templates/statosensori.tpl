<div class="col-xs-12 col-md-6">
	<div class="panel panel-primary">
		<div class="panel-heading">
			<span class="panel-title">Stato Sensori</span>
		</div>
		<div class="panel-body">
			{% if sensori %}
			<select id="sensore" class="selectpicker" data-width="100%">
				{% set divider = (sensori|first).incluso_in_media|default(false) %}
				{% for s in sensori %}
					{% if divider != s.incluso_in_media %}
						<option data-divider="true"></option>
						{% set divider = s.incluso_in_media %}
					{% endif %}
					<option value="{{s.id}}">{{s.nome}}</option>
				{% endfor %}
			</select>
			<h3 class="temperature">
				<div class="col-xs-6 col-md-3 text-right"><small>Temperatura :</small></div>
				<div class="col-xs-6 col-md-3">
					<span class="wi wi-thermometer" aria-hidden="true"></span>
					<span id="temperature-value">{{ sensore.temperatura|default(null)|Temperature|raw }}</span>
					<span class="wi wi-celsius fa-1x" aria-hidden="true"></span>
				</div>
			</h3>
			<br class="clearfix visible-xs-block">
			<h3 class="humidity">
				<div class="col-xs-6 col-md-3 text-right"><small>Umidità :</small></div>
				<div class="col-xs-6 col-md-3">
					<span class="wi wi-humidity" aria-hidden="true"></span>
					<span id="humidity-value">{{ sensore.umidita|default(null)|Umidity }}</span>
					<span class="fa fa-percent" aria-hidden="true"></span>
				</div>
			</h3>
			<div class="clearfix"></div>
			<hr class="col-xs-10 col-md-10" style="" />

			<div class="col-xs-12 col-md-12" id="andamento-temperatura" style="height:225px;"></div>
			<div class="col-xs-12 col-md-12" id="andamento-umidita" style="height:225px;"></div>
			{% else %}
			<div class="alert alert-warning" role="alert">
				<h4>Nessun sensore definito.</h4>
				<p>Utilizzare il menu impostazioni per aggiungere i sensori necessari al funzionamento del sistema.</p>
			</div>

			{% endif %}
		</div>
		<div class="panel-footer text-center">
			<small class="text-muted">
				Ultimo aggiornamento <span id="last-update">{{sensore.ultimo_aggiornamento|default("now")|DateTime}}</span>
			</small>
		</div>
	</div>
</div>