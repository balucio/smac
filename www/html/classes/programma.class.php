<?php

class DettaglioProgramma implements JsonSerializable {
	private
		$giorno,
		$ora,
		$intervallo,
		$t_rif_codice,
		$t_rif_valore;

	public function __construct($data) {

		$this->giorno = isset($data['giorno']) ? $data['giorno'] : null;
		$this->ora = isset($data['ora']) ? $data['ora'] : null;
		$this->intervallo = isset($data['intervallo']) ? $data['intervallo'] : null;
		$this->t_rif_codice = isset($data['t_rif_indice']) ? $data['t_rif_indice'] : null;
		$this->t_rif_valore = isset($data['t_rif_val']) ? $data['t_rif_val'] : null;
	}

	public function jsonSerialize() {
		return [
			'giorno' => $this->giorno,
			'ora' => $this->ora,
			'intervallo' => $this->intervallo,
			't_rif_codice' => $this->t_rif_codice,
			't_rif_valore' => $this->t_rif_valore
		];
	}

	public function __get($key) { return $this->$key; }
}

class Programma implements JsonSerializable {
	private
		$id,
		$nome,
		$descrizione,
		$rif_temp_attuale = null,
		$antigelo = null,
		$temperature = [],
		$dettaglio = []
	;

	public function __construct($data, $details) {
d($data); d($details);
		$this->id = isset($data['id_programma']) ? $data['id_programma'] : null;
		$this->nome = isset($data['nome_programma']) ? $data['nome_programma'] : null;
		$this->descrizione = isset($data['descrizione_programma']) ? $data['descrizione_programma'] : null;
		$this->temperature = isset($data['json_t_rif']) ? $this->parseTemps($data['json_t_rif']) : [];
		$this->antigelo = isset($data['t_anticongelamento']) ? json_decode($data['t_anticongelamento']) : null;

		$cDay = date('N');
		$dTime = time() - strtotime("today");

		foreach ($details as $row) {

			$dp = new DettaglioProgramma($row);
			$this->dettaglio[$dp->giorno][] = $dp;

			if ($cDay == $dp->giorno && $dTime <= $dp->intervallo)
				$this->rif_temp_attuale = $dp->t_rif_valore;
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

	public function __get($data) { return $this->$data; }


	private function parseTemps($t) {

		$ot = [];

		foreach (json_decode($t) as $k => $v)
			$v && $ot[] = (object)['t_id' => $k, 't_val' => $v];

		return $ot;
	}
}
