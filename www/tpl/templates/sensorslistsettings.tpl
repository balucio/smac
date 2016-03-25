<table class="table">
	<thead>
		<tr>
			<th class="col-xs-3 col-sm-2"><button class="btn btn-xs btn-success" title="Nuovo sensore"><i class="fa fa-plus-square"></i></button></th>
			<th class="col-xs-2 col-sm-2">Nome</th>
			<th class="hidden-xs">Descrizione</th>
			<th class="col-xs-1 col-sm-1">Driver</th>
			<th>Parametri</th>
			<th class="col-xs-2 col-sm-1">Stato</th>
		</tr>
	</thead>
	<tbody class="table-striped">
		{% for s in sensori %}
		<tr>

			<td>
				<div class="btn-toolbar" role="toolbar">
					<div class="btn-group" role="group" >
						<button class="btn btn-xs btn-info" data-id="{{ s.id }}" data-toggle="collapse" data-target="#sensore_{{ s.id }}" title="Informazioni estese">
							<i class="fa fa-eye"></i>
						</button>
						<button class="btn btn-xs btn-warning" title="Modifica sensore" data-id="{{ s.id }}"><i class="fa fa fa-pencil"></i></button>
						<button class="btn btn-xs btn-danger"  title="Elimina sensore" data-id="{{ s.id }}"><i class="fa fa-trash-o"></i></button>
					</div>
				</div>
			</td>

			<td>{{s.nome}}</td>
			<td class="hidden-xs">{{s.descrizione|length > 50 ? s.descrizione|slice(0, 50) ~ '...' : s.descrizione }}</td>
			<td>{{s.nome_driver}}</td>
			<td>{{s.parametri}}</td>
			<td>
				<div class="btn-toolbar" role="toolbar">
					<div class="btn-group" role="group" >
					{% if s.abilitato %}
						{% if s.incluso_in_media %}
							<button class="btn btn-xs btn-secondary sensor-in-average" data-toggle="tooltip" title="I dati rilevati da questo sensore contribuiscono al calcolo dei valori medi">
								<i class="fa fa-sign-in"></i>
							</button>
						{% else %}
							<button class="btn btn-xs btn-secondary sensor-not-in-average" data-toggle="tooltip" title="I dati di questo sensore non sono inclusi nel calcolo dei valori medi" >
								<i class="fa fa-sign-out"></i>
							</button>

						{% endif %}
							<button class="btn btn-xs btn-secondary sensor-enabled" data-toggle="tooltip" title="Sensore abilitato">
								<i class="fa fa-power-off"></i>
							</button>
					{% else %}
						<button class="btn btn-xs btn-secondary sensor-disabled" title="Sensore non abilitato" data-toggle="tooltip">
							<i class="fa fa-power-off"></i>
						</button>
					{% endif %}
					</div>
				</div>
			</td>
		</tr>
		<tr>
			<td>&nbsp;</td>
			<td colspan="11" class="hiddenRow">
				<div class="accordian-body collapse" id="sensore_{{ s.id }}">
					<p class="sensor-info">
					{% if s.abilitato %}
						<span>Questo sensore è abilitato alla raccolta dati</span>
						<br class="hidden-md hidden-lg"/>
						<span class="hidden-sm hidden-xs"> - </span>
						{% if s.incluso_in_media %}
							<span>i dati rilevati contribuiscono al calcolo dei valori medi.</span>
						{% else %}
							<span>i dati rilevati non sono inclusi nel calcolo dei valori medi</span>
						{% endif %}
					{% else %}
						<p>Il sensore non è attivo, i dati di questo sensore non sono inclusi nelle rilevazioni periodiche.</p>
					{% endif %}
					</p>
					<div class="clearfix"></div>
					<dl class="dl-horizontal">
						<dt>Descrizione:</dt>
						<dd>{{ s.descrizione }}</dd>
						<dt>Parametri sensore:</dt>
						<dd>{{ s.parametri|default('non definiti') }}</dd>

						<dt >Driver usato:</dt>
						<dd>{{ s.nome_driver }}</dd>

						<dt>Parametri del driver:</dt>
						<dd>{{ s.parametri_driver|default('non definiti')  }}</dd>
					</dl>
				</div>
			</td>
		</tr>
		{% endfor %}
	</tbody>
</table>