<?php

class StatisticheModel {

	public function __construct() { }


	/* Aggiorna i dati della giornata odierna */
	public function update_today_stats() {
		$query = "SELECT aggiorna_dati_giornalieri(id_sensore)" 
				 ." FROM sensori" 
				." WHERE abilitato = true";
		// Eseguo e scarto i dati
		Db::get()->query($query);
	}


}
