<?php

class ProgramStatusModel {

	const SPECIAL_PROGRAM = 'special';
	const OTHER_PROGRAM = 'other';

	private
		$programStatus = null,
		$pList = null,
		$dbh = null
	;

	public function __construct() {

		$this->programStatus = new ProgramDataModel();
		$this->dbh = Db::get();
	}

	public function initData() {

		// Il programma predefinito è quello attivo al giorno attual
		$this->programStatus->setProgramId(null, null);
		$this->enumerate();

	}

	public function programdata() { return $this->programStatus->programdata(); }

	public function programlist($type) {

		return ($type == 'special')
			? array_slice($this->pList, 0, 2)
			: array_slice($this->pList, 2)
		;
	}

	public function enumerate() {

		// Current program
		$cp = $this->dbh->readSetting(Db::CURR_PROGRAM, '-1');

		$this->pList = Db::get()->getResultSet("SELECT * FROM elenco_programmi()");

		foreach ($this->pList as &$p)
			$p['selected'] = $cp == $p['id_programma'] ? 'selected' :'';

		return $this;

	}

}