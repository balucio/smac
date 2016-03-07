<?php

class ProgramListModel {

	const POWEROFF = 0b0001;
	const ANTIFREEZE = 0b0010;
	const MANUAL = 0b0100;
	const ALL = 0b1000;
	const NONE = 0b0000;

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

	public function enumerate($spid = null, $include = self::ALL) {

		$rawList = Db::get()->getResultSet("SELECT * FROM elenco_programmi()");

		if (!($include & self::POWEROFF))
			unset($rawList[0]);

		if (!($include & self::ANTIFREEZE))
			unset($rawList[1]);

		if (!($include & self::MANUAL)) {
			array_pop($rawList);
		}

		$this->list = [];

		$selected = null;

		foreach ($rawList as $v) {
			$k = $v['id_programma'];
			$this->list[$k] = $v;
			if ($selected === null && $spid == $k) {
				$this->list[$k]['selected'] = 'selected';
				$selected = $k;
			} else {
				$this->list[$k]['selected'] = '';
			}
		}

		if ($selected === null) {
			$selected = key($this->list);
			$this->list[$selected]['selected'] = 'selected';
		}

		return $selected;
	}
}