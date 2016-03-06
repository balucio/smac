<?php

class SensorDataModel {

	private
		$data = null
	;

	public function __construct($sid = null) {

		if ($sid !== null)
			$this->setSid($sid);
	}

	public function __get($v) {

		return $this->data[$v];
	}

	public function get() { return $this->data; }

	public function setSid($sid) {

		if (!$this->exists($sid))
			return false;

		$this->data = Db::get()->getFirstRow(
			"SELECT * FROM dati_sensore(:sid)",
			[':sid' => $sid ]
		);
		return true;
	}

	public function exists($sid) {

		return Db::get()->getNthColumnOfRow(
			"SELECT esiste_sensore(:sid::smallint)",
			[':sid' => $sid ]
		);
	}
}