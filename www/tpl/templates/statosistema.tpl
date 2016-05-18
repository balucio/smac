<div class="col-xs-12 col-md-6">
	<div class="panel panel-primary">
		<div class="panel-heading">
			<div class="btn-group pull-right">
				<a href="#" class="btn btn-sm" title="Aggiornamento dati..."
						data-toggle="tooltip" data-container="body" data-placement="left">
					<span id="boiler-status-icon" class="fa fa-refresh"></span>
				</a>
			</div>
			<span class="panel-title">Stato Sistema</span>
			<span class="hidden" id="title-status-on">Caldaia accesa</span>
			<span class="hidden" id="title-status-off">Caldaia spenta</span>
			<span class="hidden" id="title-status-unknow">Stato caldaia non disponibile</span>
		</div>
		<div class="panel-body">
			<div class="row">
				<div class="col-xs-6 col-md-10">
					<select id="programma" class="selectpicker form-control" disabled>

						{% set divider = constant('ProgramListModel::ID_ANTIFREEZE') %}

						{% for p in programmi %}

							{% if divider < p.id_programma %}

								<option data-divider="true"></option>
								{% set divider = constant('ProgramListModel::ID_MANUAL') %}

							{% endif %}

							<option title="{{p.nome_programma}}" value="{{p.id_programma}}" {{p.selected}}>
								{{p.nome_programma}}
							</option>

						{% endfor %}

					</select>
				</div>
				<div class="col-xs-6 col-md-2">
					<button id="modifica-programma" type="button" data-altlabel="Applica" class="btn btn-primary btn-block">Modifica</button>
				</div>
			</div>
			<div class="row">
				<h4 class="text-center"><span class="wi wi-thermometer" aria-hidden="true"> </span> Temperature di riferimento</h4>
				<div id="temperature-riferimento">
					{% include "tempriferimento.tpl" %}
				</div>
			</div>
			<div class="row">
				<hr class="col-xs-10 col-md-10" style="" />
				<div class="col-xs-12 col-md-12" id="programma-giornaliero" style="height:400px;"></div>
			</div>

		</div>
		<div class="panel-footer text-center">
			<small class="text-muted pull-right">
				<abbr title="Temperatura antigelo">T</abbr>
				<sub><span class="wi wi-snowflake-cold" aria-hidden="true"></span></sub>
				<span>{{antigelo|Temperature|raw}}</span>
				<span class="wi wi-celsius fa-1x" aria-hidden="true"></span>
			</small>
			<small class="text-muted pull-left">
				<abbr title="Temperatura di riferimento attuale">T</abbr>
				<sub>Rif</sub>
				<span id="temp_riferimento_attuale">{{rif_temp_attuale|Temperature|raw}}</span>
				<span class="wi wi-celsius fa-1x" aria-hidden="true"></span>
			</small>
			<small class="text-muted">
				<abbr title="Sensore di riferimento temperatura per il programma">S<sub>Rif</sub></abbr>
				<b>{{sensore_rif}}</b>
			</small>
			<div class="clearfix"></div>
		</div>
	</div>
</div>