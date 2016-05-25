<table class="table table-striped">
	<thead>
		<tr>
			<th>Data</th>
			<th>Stato</th>
			<th>Durata</th>
		</tr>
	</thead>
	<tfoot class="table">
		<tr>
			<th rowspan="3">Totali</th>
			<td>Acceso</td>
			<td>{{commutazioni.totale.acceso}}</td>
		</tr>
		<tr>
			<td>Spento</td>
			<td>{{commutazioni.totale.spento}}</td>
		</tr>
		<tr>
			<td>Indeterminato</td>
			<td>{{commutazioni.totale.indeterminato}}</td>
		</tr>
	</tr>
  </tfoot>
	<tbody>
		{% for c in commutazioni.elenco %}
		<tr>
			<th>{{c.inizio|DateTime}}</th>
			<th>{{c.stato is null ? 'indeterminato' : ( c.stato ? 'Acceso' : 'Spento' ) }}</th>
			<th>{{c.durata}}</th>
		</tr>
		{% endfor %}
	</tbody>
</table>