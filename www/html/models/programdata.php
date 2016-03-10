<?php

class ProgramDataModel {

	const
		DAY_ALL=0,
		DAY_NOW=null
	;

	private
		$pid = null,
		$programma = null
	;

	public function __construct() { }

 	public function __isset($v) { return $this->programma->__isset($v); }
	public function __get($v) { return $this->programma->$v; }

	public function get() { return $this->programma; }

	public function getPid() { return $this->pid; }

	public function setPid($pid = null, $pday = null) {

		$this->pid = $pid;

		$this->programma = new Programma(
			$this->getData($pid),
			$this->getDetails($pid, $pday)
		);
	}

	public function exists($pid) {

		return Db::get()->getNthColumnOfRow(
			"SELECT esiste_programma(:pid::smallint)",
			[':pid' => $pid ]
		);
	}

	public function setDefault($pid) {

		Db::get()->saveSetting(Db::CURR_PROGRAM, $pid);
		$this->pid = $pid;
	}

	public function getDefault() {
		return $this->pid = Db::get()->readSetting(Db::CURR_PROGRAM, '-1');
	}

	private function getData($pid) {

		$query = "SELECT *, array_to_json(temperature_rif) as json_t_rif FROM dati_programma(:id)";
		return Db::get()->getFirstRow($query, [':id' => $pid]);
	}

	private function getDetails($pid, $day = self::DAY_NOW) {

		return Db::get()->getResultSet(
			"SELECT * FROM programmazioni(:id, :day)",
			[':id' => $pid, ':day' => $day ]
		);
	}
}