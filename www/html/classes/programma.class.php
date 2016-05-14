<?php

class DettaglioProgramma implements JsonSerializable {

	private

		$giorno,
		$ora,
		$intervallo,
		$t_rif_codice,
		$t_rif_valore
	;

	public function __construct($data) {

		$this->giorno = isset($data['giorno']) ? $data['giorno'] : null;
		$this->ora = isset($data['ora']) ? $data['ora'] : null;
		$this->intervallo = isset($data['intervallo']) ? $data['intervallo'] : null;
		$this->t_rif_codice = isset($data['t_rif_indice']) ? $data['t_rif_indice'] : null;
		$this->t_rif_valore = isset($data['t_rif_val']) ? $data['t_rif_val'] : null;
	}

	public function __toString() {

		return $this->ora . '|' . $this->t_rif_valore;
	}

	public function jsonSerialize(){
		return [
			'giorno' => $this->giorno,
			'ora' => $this->ora,
			'intervallo' => $this->intervallo,
			't_rif_codice' => $this->t_rif_codice,
			't_rif_valore' => $this->t_rif_valore
		];
	}

	public function __isset($key) { return property_exists($this, $key); }
	public function __get($key) { return $this->$key; }
}

class Programma implements JsonSerializable {

	private
		$id,
		$nome,
		$descrizione,
		$rif_temp_attuale = null,
		$antigelo = null,
		$id_sensore_rif,
		$nome_sensore_rif,
		$temperature = [],
		$dettaglio = []
	;

	public function __construct($data, $details) {

		$this->id = isset($data['id_programma']) ? $data['id_programma'] : null;
		$this->nome = isset($data['nome_programma']) ? $data['nome_programma'] : null;
		$this->descrizione = isset($data['descrizione_programma']) ? $data['descrizione_programma'] : null;
		$this->temperature = isset($data['json_t_rif']) ? $this->parseTemps($data['json_t_rif']) : [];
		$this->antigelo = isset($data['t_anticongelamento']) ? json_decode($data['t_anticongelamento']) : null;
		$this->id_sensore_rif = isset($data['sensore_rif']) ? $data['sensore_rif'] : null;
		$this->nome_sensore_rif = isset($data['nome_sensore_rif']) ? $data['nome_sensore_rif'] : null;

		$nd = date('N');
		$dt = time() - strtotime("today");

		$i = 0;

		foreach ($details as $row) {

			$dp = new DettaglioProgramma($row);

			if ( $dp->giorno != $i ) {
				$i = $dp->giorno;
				$this->dettaglio[$i] = [];
			}

			$this->dettaglio[$i][] = $dp;
			// Calcolo temperatura attuale.
			if ($nd == $dp->giorno && $dp->intervallo <= $dt) {
				$this->rif_temp_attuale = $dp->t_rif_valore;
			}
		}
	}

	public function jsonSerialize() {

		return [
			'id' => $this->id,
			'nome' => $this->nome,
			'descrizione' => $this->descrizione,
			'rif_temp_attuale' => $this->rif_temp_attuale,
			'antigelo' => $this->antigelo,
			'temperature' => $this->temperature,
			'dettaglio' => $this->dettaglio
		];
	}

	public function __isset($v) { return property_exists($this, $v); }

	public function __get($v) { return $this->$v; }

	private function parseTemps($t) {

		$ot = [];

		foreach (json_decode($t) as $k => $v)
			$v && $ot[] = (object)['id' => $k + 1, 'val' => $v];

		return $ot;
	}
}
