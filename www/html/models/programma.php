<?php

class ProgrammaModel {

	private
		$dbh = null,
		$plist = null,
		$pdata = null
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

	public function programData($pid, $day) {

		$this->programma = new Programma(
			$this->getProgramData($pid),
			$this->getProgramDetails($pid, $day)
		);
	}

	public function programList() {

		$this->plist = $this->dbh->getResultSet("SELECT * FROM programmi");
	}

	private function getProgramData($pid) {

		$query = "SELECT *, array_to_json(temperature_rif) as json_t_rif FROM dati_programma(:id)";

		return $this->dbh->getFirstRow($query, [':id' => $pid]);

	}

	private function getProgramDetails($pid, $day = null) {

		return $this->dbh->getResultSet(
			"SELECT * FROM programmazioni(:id, :day)",
			[':id' => $pid, ':day' => $day ]
		);
	}
}