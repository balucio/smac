<?php

class ProgrammaModel {

	private
		$dbh = null,
		$plist = null
	;

	public function __construct() {

		$this->dbh = Db::get();
 	}

	public function __isset($key) {

		return array_key_exists($key, $this->sData);
	}

	public function __get($data) { return $this->$data; }

	public function saveDefault($pid) {

		$dBpid = $pid;

		if ($pid > 0) {

			$dbr = $this->dbh->getFirstRow(
				"SELECT id_programma FROM programmi WHERE id_programma=:id",
				[':id' => $pid ]
			);

			$dBpid = isset($dbr['id_programma']) ? $dbr['id_programma'] : null;
		}

		if ($dBpid == $pid)
			$this->dbh->saveSetting(Db::CURR_PROGRAM, $pid);
		else
			throw new Exception("Id programma non esistente", 1);
	}

	public function programList($active = null) {

		$this->plist = $this->dbh->getResultSet("SELECT * FROM programmi");

		$active = $active ?: $this->dbh->readSetting(Db::CURR_PROGRAM, null);

		$found = false;

		foreach ($this->plist as &$v) {

			if ($active == $v['id_programma'] || is_null($active)) {

				$found = true;
				$v['attivo'] = 'active';
				break;
			}
		}

		if (!$found)
			$this->plist[0]['attivo'] = 'list-group-item-info';
	}
}