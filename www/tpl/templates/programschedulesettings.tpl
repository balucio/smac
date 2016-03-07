<div class="col-xs-12 col-sm-8 col-md-8">
	<div class="panel-group" id="menu-programmi">
		<div class="panel panel-default">
			<div class="panel-heading">
				<h4 class="panel-title">
					Programma <b>{{programma.nome}}</b>
				</h4>
			</div>
			<div class="panel-body">
			{% set day = date()|date('N') %}
			<div class="col-xs-4 col-sm-4 col-md-3">
				<!-- Nav tabs -->
				<ul id="programmazione-settimanale" class="nav nav-pills nav-stacked" role="tablist">
					{% for g in 1..7 %}
						{% set selected =  day == g ? 'active' : '' %}
						<li role="presentation" class="{{selected}}">
							<a aria-controls="{{g|ShortDay}}"
								role="tab" data-toggle="pill"
								href="#{{g|ShortDay}}">
								{{g|Day}}
							</a>
					</li>
					{% endfor %}
				</ul>
			</div>
			<!-- Tab panes -->
			<div id="programma-giornaliero" class="tab-content col-xs-8 col-sm-8 col-md-9">
				{% for k, details in programma.dettaglio %}
					{% set selected = k == day ? 'in active' : '' %}
					<div role="tabpanel" class="tab-pane fade {{selected}}" id="{{k|ShortDay}}">
						<table id="dettaglio-programma" class="table table-responsive table-striped">
							<thead>
								<tr>
									<th>
										<button title="Aggiungi programmazione oraria" class="btn btn-xs btn-link">
											<span class="glyphicon glyphicon-plus"></span>
										</button>
									</th>
									<th class="col-md-6">Ora</th>
									<th class="col-md-6">Temperatura</th>
									<th>
										<button title="Incolla programmazioni giornata" class="btn btn-xs btn-link">
											<span class="glyphicon glyphicon-paste"></span>
										</button>
										<button title="Copia programmazioni giornata" class="btn btn-xs btn-link">
											<span class="glyphicon glyphicon-copy"></span>
										</button>
									</th>
								</tr>
							</thead>
							<tbody>
							{% for shedule in details %}
								<tr>
									<td><a class="btn" title="Modifica"><span class="glyphicon glyphicon-edit"></span></a></td>
									<td>{{ shedule.ora|Time }}</td>
									<td>
										<div class="temperatura">
											<div class="wi wi-celsius fa-1x pull-right" aria-hidden="true"></div>
											<div class="pull-right">{{shedule.t_rif_valore|Temperature|raw}}</div>
										</div>
									</td>
									<td><a class="btn" title="Elimina"><span class="glyphicon glyphicon-trash"></span></a></td>
								</tr>
							{% endfor %}
							</tbody>
						</table>
					</div>
				{% endfor %}
			</div>
			<script>
				{{tabactivate}}
			</script>
		</div>
	</div>
</div>
