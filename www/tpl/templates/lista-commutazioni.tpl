<table class="table table-striped">
	<thead>
		<tr>
			<th>Data</th>
			<th>Ora</th>
			<th>Stato</th>
			<th>Durata</th>
		</tr>
	</thead>
	<tfoot>
    	<tr>
      		<td rowspan="3" colspan="2">Totali</td>
      		<td>Acceso</td>
      		<td>{commutazioni.totale.acceso}</td>
      	</tr>
      	<tr>
      		<td>Spento</td>
      		<td>{commutazioni.totale.spento}</td>
      	</tr>
      	<tr>
      		<td>Indeterminato</td>
      		<td>{commutazioni.totale.indeterminato}</td>
      	</tr>
    </tr>
  </tfoot>
	<tbody>
		{% for c in commutazioni.elenco %}
		<tr>
			<th>{d.inizio}</th>
			<th>{d.inizio}</th>
			<th>{d.stato}</th>
			<th>{d.durata}</th>
		</tr>
		{% endfor %}
	</tbody>
</table>