<?php

class SensorDataModel {

	private
		$dbh = null,
		$sData = null
	;

	public function __construct() { }

	public function __isset($key) {

		return array_key_exists($key, $this->sData);
	}

	public function __get($data) {

		return $this->sData[$data];
	}

	public function setSensorId($sensorId) {

		$this->sData = Db::get()->getFirstRow(
			"SELECT * FROM dati_sensore(:id)",
			[':id' => $sensorId ]
		);
	}
}