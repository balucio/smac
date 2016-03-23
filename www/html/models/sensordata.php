<?php

class SensorDataModel {

	private
		$sid = null,
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

		$this->sid = $sid;

		return true;
	}

	public function collectData() {

		$this->data = Db::get()->getFirstRow(
			"SELECT * FROM sensori WHERE :sid)",
			[':sid' => $this->sid ]
		);
	}

	public function collectEnviromentalData() {

		$this->data = Db::get()->getFirstRow(
			"SELECT * FROM dati_sensore(:sid)",
			[':sid' => $this->sid ]
		);
	}

	public function exists($sid) {

		return Db::get()->getNthColumnOfRow(
			"SELECT esiste_sensore(:sid::smallint)",
			[':sid' => $sid ]
		);
	}
}