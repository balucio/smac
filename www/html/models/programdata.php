<?php

class ProgramDataModel {

	private
		$programma = null
	;

	public function __construct() { }

	public function __get($name) { return $this->programma->$name; }

	public function initData($pid = null, $pday = null) {

		$this->setProgramId($pid, $pday);
	}

	public function setProgramId($pid = null, $pday = null) {

		$this->programma = new Programma(
			$this->getProgramData($pid),
			$this->getProgramDetails($pid, $pday)
		);
	}

	private function getProgramData($pid) {

		$query = "SELECT *, array_to_json(temperature_rif) as json_t_rif FROM dati_programma(:id)";

		return Db::get()->getFirstRow($query, [':id' => $pid]);

	}

	private function getProgramDetails($pid, $pday = null) {

		return Db::get()->getResultSet(
			"SELECT * FROM programmazioni(:id, :day)",
			[':id' => $pid, ':day' => $pday ]
		);
	}
}