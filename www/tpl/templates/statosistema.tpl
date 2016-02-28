<div class="col-xs-12 col-md-6">
	<div class="panel panel-primary">
		<div class="panel-heading">Stato Sistema</div>
		<div class="panel-body">
			<div class="col-xs-12 col-md-10">
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
			<div class="col-xs-12 col-md-2">
				<button id="modifica-programma" type="button" data-altlabel="Applica" class="btn btn-primary btn-block">Modifica</button>
			</div>
			<br/>
			<div class="clearfix"></div>
			<h4 class="text-center"><span class="wi wi-thermometer" aria-hidden="true"> </span> Temperature di riferimento</h4>
				<div id="temperature-riferimento">
					{% for t in temperature %}
						<div class="col-xs-4 col-md-2 text-right" id="t_name_{{t.id}}">
							<h5>T<sub>{{t.id}}</sub></h5>
						</div>
						<div class="col-xs-8 col-md-4">
							<h5>
								{{t.val|Temperature|raw}}
								<span class="wi wi-celsius fa-1x" aria-hidden="true"></span>
							</h5>
						</div>
					{% endfor %}
				</div>

			<div class="clearfix"></div>
      		<hr class="col-xs-10 col-md-10" style="" />
			<div class="col-xs-12 col-md-12" id="programma-giornaliero" style="height:400px;"></div>

		</div>
		<div class="panel-footer text-center">
			<small class="text-muted pull-right">
				<abbr title="Temperatura antigelo">T</abbr>
				<sub><span class="wi wi-snowflake-cold" aria-hidden="true"></span></sub>
				<span>{{antigelo|Temperature|raw}}</span>
				<span class="wi wi-celsius fa-1x" aria-hidden="true"></span>
			</small>
			<small class="text-muted pull-left">
				<abbr title="Temperatura di riferimento">T</abbr>
				<sub>Rif</sub>
				<span>{{rif_temp_attuale|Temperature|raw}}</span>
				<span class="wi wi-celsius fa-1x" aria-hidden="true"></span>
			</small>
			<div class="clearfix"></div>
		</div>
	</div>
</div>