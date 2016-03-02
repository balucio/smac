<?php

class SensorDataModel {

	private
		$data = null
	;

	public function __construct($sid = null) {

		if ($sid)
			$this->setSensorId($sid);
	}

	public function __isset($key) {

		return array_key_exists($key, $this->data);
	}

	public function __get($data) {

		return $this->data[$data];
	}

	public function setSensorId($sid) {

		if (!$this->sensorExists($sid))
			return false;

		$this->data = Db::get()->getFirstRow(
			"SELECT * FROM dati_sensore(:sid)",
			[':sid' => $sid ]
		);

		return true;
	}

	public function sensorExists($sid) {

		return Db::get()->getNthColumnOfRow(
			"SELECT esiste_sensore(:sid::smallint)",
			[':sid' => $sid ]
		);
	}
}