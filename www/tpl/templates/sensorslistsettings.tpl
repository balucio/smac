<table class="table">
	<thead>
		<tr>
			<th>&nbsp;</th>
			<th>Nome</th>
			<th>Descrizione</th>
			<th>Driver</th>
			<th>Parametri</th>
			<th>Stato</th>
		</tr>
	</thead>
	<tbody class="table-striped">
		{% for s in sensori %}
		<tr data-id="{{s.id}}">
			<td></td>
			<td>{{s.nome}}</td>
			<td>{{s.descrizione}}</td>
			<td>{{s.nome_driver}}</td>
			<td>{{s.parametri}}</td>
			<td>
				{% if s.abilitato %}
					{% if s.incluso_in_media %}
						<i title="I dati del sensore contribuiscono al calcolo dei valori medi" class="fa fa-sign-in sensor-in-average"></i>

					{% else %}
						<i title="I dati del sensore sono esclusi dal calcolo dei valori medi" class="fa fa-sign-iu sensor-not-in-average"></i>

					{% endif %}
					<i title="Sensore abilitato" class="fa fa-power-off sensor-enabled"></i>
				{% else %}
					<i title="Sensore non abilitato" class="fa fa-power-off sensor-disabled"></i>
				{% endif %}
			</td>
		</tr>
		{% endfor %}
	</tbody>
</table>