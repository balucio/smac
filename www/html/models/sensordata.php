<?php

class SensorDataModel {

	private
		$data = null
	;

	public function __construct() {

	}

	public function __get($v) {

		return $this->data[$v];
	}

	public function get() { return $this->data; }

	public function collectData($sid) {

		$this->data = Db::get()->getFirstRow(
			"SELECT * FROM dettagli_Sensore(:sid::smallint)",
			[':sid' => $sid ]
		);
	}

	public function collectEnviromentalData($sid) {

		$this->data = Db::get()->getFirstRow(
			"SELECT * FROM dati_sensore(:sid)",
			[':sid' => $sid ]
		);
	}

	public function exists($sid) {

		return Db::get()->getNthColumnOfRow(
			"SELECT esiste_sensore(:sid::smallint)",
			[':sid' => $sid ]
		);
	}
}