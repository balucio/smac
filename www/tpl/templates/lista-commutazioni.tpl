<table class="table table-striped">
	<thead>
		<tr>
			<th>Data</th>
			<th>Stato</th>
			<th>Durata</th>
		</tr>
	</thead>
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

<table class="table table-striped">
	<thead>
		<tr>
			<th colspan="3">Totali</th>
		</tr>
		<tr>
			<th>Acceso</th><th>Spento</th><th>Indeterminato</th>
		</tr>
	</thead>
	<tbody>
		<tr>
			<td>{{commutazioni.totale.acceso|Interval}}</td>
			<td>{{commutazioni.totale.spento|Interval}}</td>
			<td>{{commutazioni.totale.indeterminato|Interval}}</td>
		</tr>
	</tbody>
</table>