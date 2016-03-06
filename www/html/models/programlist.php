<?php

class ProgramListModel {

	const POWEROFF = 0b0001;
	const ANTIFREEZE = 0b0010;
	const MANUAL = 0b0100;
	const ALL = 0b1000;

	const ID_POWEROFF = -1;
	const ID_ANTIFREEZE = 0;
	const ID_MANUAL = 32767;

	private

		$list = null
	;

	public function __construct() { }

	public function get() {

		return $this->list;
	}

	public function enumerate($spid = null, $include_special = self::ALL) {

		$rawList = Db::get()->getResultSet("SELECT * FROM elenco_programmi()");

		if ($include_special & self::POWEROFF)
			unset($rawList[self::ID_POWEROFF]);

		if ($include_special & self::ANTIFREEZE)
			unset($rawList[self::ID_ANTIFREEZE]);

		if ($include_special & self::MANUAL)
			unset($rawList[self::ID_MANUAL]);

		$this->list = [];

		foreach ($rawList as $v) {
			$k = $v['id_programma'];
			$this->list[$k] = $v;
			$this->list[$k]['selected'] = $spid == $k ? 'selected' : '';
		}
	}
}